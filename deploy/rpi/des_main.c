/* des_main.c  Driver Engagement Supervisor 실행 프로그램 (RPi5)
 *
 * 10 ms마다 생성된 Supervisor 모델을 1 스텝 실행한다. 같은 입력으로 M0(R171 기준선)과
 * 선택 모델을 나란히 돌리고 터미널 대시보드 / 로그 / (선택) GPIO LED·부저로 출력한다.
 *
 * 입력
 *   --csv FILE   DMS CSV 재생. 열 이름으로 찾음: timestamp,valid,yaw,pitch[,driver_action][,reset]
 *                (DMS 모듈 출력 그대로도 됨: valid 대신 face_detected, True/False, 빈 각도 칸)
 *   --udp PORT   DMS 실시간 수신. 패킷 1개 = 한 줄 "timestamp,valid,yaw,pitch[,driver_action]"
 *                (timestamp는 무시하고 수신 시각을 쓴다. 두 기기의 시계가 다르기 때문)
 * 옵션
 *   --fast           CSV를 실시간 대기 없이 최대 속도로 처리 (back-to-back 검증용)
 *   --log FILE       매 스텝 입력·출력 CSV 기록
 *   --yaw0 D --pitch0 D   보정: 각도에서 뺄 0점 [deg]
 *   --calib SEC      보정 자동: 처음 SEC초 동안의 valid 프레임 평균을 0점으로 (전방을 보고 있을 것)
 *   --duration SEC   SEC초 후 종료
 *   --quiet          대시보드 끔
 *   --gpio [CHIP]    LED/부저 출력 (make GPIO=1로 빌드 필요). 기본 /dev/gpiochip0
 *   --rt             SCHED_FIFO 실시간 우선순위 (sudo 필요)
 *   --solo           선택 모델만 표시 (대시보드, GUI, LED). M0는 내부에서 계속 계산하지만 보이지 않는다.
 *                    계산 경로와 로그는 그대로이므로 back-to-back 결과에 영향이 없다.
 *   --ui [PORT]      화면(GUI) 연동. 상태를 127.0.0.1:PORT(기본 5006)로 20 Hz 전송하고,
 *                    PORT+1에서 터치 명령(action, reset)을 받는다. GUI는 tools/des_gui.py
 * 키보드 (터미널에서 실행 시)
 *   space: 운전자 응답(driver_action, 0.5초 유지)   r: 리셋   q: 종료
 *
 * 로그 시간 규약은 MATLAB과 같다: 스텝 k는 구간 [(k-1)dt, k dt), t = k dt.
 */
#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#else
#define _GNU_SOURCE
#endif

#include <math.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "des_app.h"
#include "des_config.h"

#ifndef _WIN32
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
#endif
#ifdef USE_GPIOD
#include <gpiod.h>
#endif

#define DT_NS        10000000L                   /* 10 ms */
#define ACTION_HOLD  50                           /* space 키 -> 0.5 s 동안 driver_action */

/* ------------------------------------------------------------------ 옵션 */
static struct {
    const char *csv, *log, *gpio_chip;
    int udp_port, ui_port;
    bool fast, quiet, gpio, rt, solo;
    double yaw0, pitch0, calib, duration;
} opt = {0};

static volatile sig_atomic_t g_stop = 0;
static void on_signal(int s) { (void)s; g_stop = 1; }

static void usage(void)
{
    fprintf(stderr,
        "사용법: des_main (--csv FILE | --udp PORT) [--fast] [--log FILE]\n"
        "        [--yaw0 D --pitch0 D | --calib SEC] [--duration SEC] [--quiet]\n"
        "        [--gpio [CHIP]] [--rt] [--ui [PORT]] [--solo]\n");
    exit(2);
}

static void parse_args(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
#define NEXT() (i + 1 < argc ? argv[++i] : (usage(), (char *)0))
        if      (!strcmp(a, "--csv"))      opt.csv = NEXT();
        else if (!strcmp(a, "--udp"))      opt.udp_port = atoi(NEXT());
        else if (!strcmp(a, "--log"))      opt.log = NEXT();
        else if (!strcmp(a, "--fast"))     opt.fast = true;
        else if (!strcmp(a, "--quiet"))    opt.quiet = true;
        else if (!strcmp(a, "--rt"))       opt.rt = true;
        else if (!strcmp(a, "--solo"))     opt.solo = true;
        else if (!strcmp(a, "--yaw0"))     opt.yaw0 = atof(NEXT());
        else if (!strcmp(a, "--pitch0"))   opt.pitch0 = atof(NEXT());
        else if (!strcmp(a, "--calib"))    opt.calib = atof(NEXT());
        else if (!strcmp(a, "--duration")) opt.duration = atof(NEXT());
        else if (!strcmp(a, "--gpio")) {
            opt.gpio = true;
            opt.gpio_chip = (i + 1 < argc && argv[i + 1][0] != '-') ? argv[++i] : "/dev/gpiochip0";
        } else if (!strcmp(a, "--ui")) {
            opt.ui_port = (i + 1 < argc && argv[i + 1][0] != '-') ? atoi(argv[++i]) : 5006;
        } else usage();
#undef NEXT
    }
    if (!opt.csv == !opt.udp_port) usage();      /* 둘 중 정확히 하나 */
}

/* ------------------------------------------------------------------ 필드 해석 */
/* valid 칸: 1/0 또는 True/False (DMS 모듈은 face_detected=True/False로 저장) */
static bool parse_flag(const char *s)
{
    while (*s == ' ') s++;
    if (*s == 'T' || *s == 't') return true;
    if (*s == 'F' || *s == 'f') return false;
    return strtod(s, NULL) > 0.5;
}

/* 각도 칸: 빈 칸, nan, None이면 false */
static bool parse_angle(const char *s, double *out)
{
    char *end;
    while (*s == ' ') s++;
    double v = strtod(s, &end);
    if (end == s || !isfinite(v)) return false;
    *out = v;
    return true;
}

/* 한 프레임: 얼굴이 검출됐어도 각도가 없으면 미검출(valid=0)로 본다 */
static void parse_gaze(des_frame_t *fr, const char *fv, const char *fy, const char *fp,
                       double y0, double p0)
{
    double y = 0.0, p = 0.0;
    fr->valid = parse_flag(fv) && parse_angle(fy, &y) && parse_angle(fp, &p);
    fr->yaw   = fr->valid ? y - y0 : 0.0;
    fr->pitch = fr->valid ? p - p0 : 0.0;
}

/* ------------------------------------------------------------------ CSV */
static des_frame_t *g_frames = NULL;
static long g_nframes = 0;

static int split(char *line, char **f, int max)
{
    int n = 0;
    char *p = line;
    while (n < max) {
        f[n++] = p;
        p = strchr(p, ',');
        if (!p) break;
        *p++ = '\0';
    }
    return n;
}

static bool load_csv(const char *path)
{
    FILE *fp = fopen(path, "r");
    if (!fp) { perror(path); return false; }
    char line[1024], *f[32];
    int c_ts = -1, c_valid = -1, c_yaw = -1, c_pitch = -1, c_act = -1, c_rst = -1;
    long cap = 0;
    bool header = true;
    while (fgets(line, sizeof line, fp)) {
        line[strcspn(line, "\r\n")] = '\0';
        if (!line[0]) continue;
        int n = split(line, f, 32);
        if (header) {
            for (int i = 0; i < n; i++) {
                if      (!strcmp(f[i], "timestamp"))     c_ts = i;
                else if (!strcmp(f[i], "valid") ||
                         !strcmp(f[i], "face_detected")) c_valid = i;
                else if (!strcmp(f[i], "yaw"))           c_yaw = i;
                else if (!strcmp(f[i], "pitch"))         c_pitch = i;
                else if (!strcmp(f[i], "driver_action")) c_act = i;
                else if (!strcmp(f[i], "reset"))         c_rst = i;
            }
            if (c_ts < 0 || c_valid < 0 || c_yaw < 0 || c_pitch < 0) {
                fprintf(stderr, "%s: 헤더에 timestamp,valid(또는 face_detected),yaw,pitch 열이 필요합니다\n", path);
                fclose(fp); return false;
            }
            header = false;
            continue;
        }
        if (g_nframes == cap) {
            cap = cap ? 2 * cap : 4096;
            g_frames = realloc(g_frames, (size_t)cap * sizeof *g_frames);
        }
        des_frame_t *fr = &g_frames[g_nframes++];
        int need = c_ts > c_valid ? c_ts : c_valid;
        if (c_yaw > need) need = c_yaw;
        if (c_pitch > need) need = c_pitch;
        if (n <= need) { g_nframes--; continue; }          /* 잘린 줄은 건너뜀 */
        fr->ts     = strtod(f[c_ts], NULL);
        parse_gaze(fr, f[c_valid], f[c_yaw], f[c_pitch], opt.yaw0, opt.pitch0);
        fr->action = c_act >= 0 && c_act < n && strtod(f[c_act], NULL) > 0.5;
        fr->reset  = c_rst >= 0 && c_rst < n && strtod(f[c_rst], NULL) > 0.5;
    }
    fclose(fp);
    if (g_nframes == 0) { fprintf(stderr, "%s: 데이터가 없습니다\n", path); return false; }
    return true;
}

/* --calib (CSV): 처음 SEC초 valid 프레임 평균을 0점으로 */
static void calib_csv(void)
{
    double sy = 0, sp = 0; long n = 0;
    for (long i = 0; i < g_nframes && g_frames[i].ts < opt.calib; i++)
        if (g_frames[i].valid) { sy += g_frames[i].yaw; sp += g_frames[i].pitch; n++; }
    if (!n) { fprintf(stderr, "보정 실패: 처음 %.1f초에 valid 프레임이 없습니다\n", opt.calib); return; }
    for (long i = 0; i < g_nframes; i++)
        if (g_frames[i].valid) { g_frames[i].yaw -= sy / n; g_frames[i].pitch -= sp / n; }
    fprintf(stderr, "보정: yaw0 %+.2f, pitch0 %+.2f deg (%ld 프레임)\n", sy / n, sp / n, n);
}

/* ------------------------------------------------------------------ 로그 */
static FILE *g_log = NULL;

static void log_open(void)
{
    if (!opt.log) return;
    g_log = fopen(opt.log, "w");
    if (!g_log) { perror(opt.log); exit(1); }
    fprintf(g_log, "step,t,valid,yaw,pitch,action,reset,gaze_on,frozen,"
                   "esc_m0,dis_m0,metric_m0,esc_sel,dis_sel,metric_sel\n");
}

static void log_step(long k, const des_input_t *in, const des_output_t *o)
{
    if (!g_log) return;
    fprintf(g_log, "%ld,%.2f,%d,%.17g,%.17g,%d,%d,%d,%d,%d,%d,%.17g,%d,%d,%.17g\n",
            k, k * DES_DT, in->valid, in->yaw, in->pitch, in->action, in->reset,
            o->gaze_on, o->frozen, o->esc[0], o->dis[0], o->metric[0],
            o->esc[1], o->dis[1], o->metric[1]);
}

/* ------------------------------------------------------------------ 요약 통계 */
static struct {
    double first_eor[DES_N_CH];
    uint8_t max_esc[DES_N_CH];
    long steps;
} g_sum;

static void summary_update(long k, const des_output_t *o)
{
    g_sum.steps = k;
    for (int c = 0; c < DES_N_CH; c++) {
        if (o->esc[c] >= 1 && g_sum.first_eor[c] < 0) g_sum.first_eor[c] = k * DES_DT;
        if (o->esc[c] > g_sum.max_esc[c]) g_sum.max_esc[c] = o->esc[c];
    }
}

static const char *ch_label(int c)
{
    static char buf[32];
    if (c == 0) return "M0 (R171 타이머)";
    snprintf(buf, sizeof buf, "M%d (선택 모델)", DES_SEL_MODEL);
    return buf;
}

static void summary_print(void)
{
    fprintf(stderr, "\n== 요약: %ld 스텝 (%.2f s)\n", g_sum.steps, g_sum.steps * DES_DT);
    for (int c = opt.solo ? 1 : 0; c < DES_N_CH; c++) {
        if (g_sum.first_eor[c] >= 0)
            fprintf(stderr, "  %-16s 첫 EOR %7.2f s, 최고 단계 %s\n", ch_label(c),
                    g_sum.first_eor[c], des_state_name[g_sum.max_esc[c]]);
        else
            fprintf(stderr, "  %-16s 경고 없음\n", ch_label(c));
    }
}

#ifndef _WIN32
/* ------------------------------------------------------------------ 시간 */
static double mono_s(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

static void ts_add_ns(struct timespec *t, long ns)
{
    t->tv_nsec += ns;
    while (t->tv_nsec >= 1000000000L) { t->tv_nsec -= 1000000000L; t->tv_sec++; }
}

static struct { double lat_max, lat_sum, exec_max, exec_sum; long n, over1ms; } g_tm;

static void timing_print(void)
{
    if (!g_tm.n) return;
    fprintf(stderr, "== 주기 타이밍 (%ld 스텝): 깨어남 지연 평균 %.3f ms / 최대 %.3f ms, "
            "1 ms 초과 %ld회 | 스텝 실행 평균 %.3f ms / 최대 %.3f ms\n",
            g_tm.n, 1e3 * g_tm.lat_sum / g_tm.n, 1e3 * g_tm.lat_max, g_tm.over1ms,
            1e3 * g_tm.exec_sum / g_tm.n, 1e3 * g_tm.exec_max);
}

/* ------------------------------------------------------------------ 키보드 */
static struct termios g_tio_old;
static bool g_tty = false;

static void kbd_restore(void) { if (g_tty) tcsetattr(STDIN_FILENO, TCSANOW, &g_tio_old); }

static void kbd_init(void)
{
    if (!isatty(STDIN_FILENO)) return;
    struct termios t;
    tcgetattr(STDIN_FILENO, &g_tio_old);
    t = g_tio_old;
    t.c_lflag &= ~(ICANON | ECHO);
    t.c_cc[VMIN] = 0; t.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &t);
    g_tty = true;
    atexit(kbd_restore);
}

static int g_action_left = 0;
static bool g_reset_req = false;

static void kbd_poll(void)
{
    char ch;
    if (!g_tty) return;
    while (read(STDIN_FILENO, &ch, 1) == 1) {
        if (ch == ' ') g_action_left = ACTION_HOLD;
        else if (ch == 'r' || ch == 'R') g_reset_req = true;
        else if (ch == 'q' || ch == 'Q') g_stop = 1;
    }
}

/* 키보드 입력을 스텝 입력에 OR */
static void kbd_apply(des_input_t *in)
{
    if (g_action_left > 0) { in->action = true; g_action_left--; }
    if (g_reset_req) { in->reset = true; g_reset_req = false; }
}

/* ------------------------------------------------------------------ 화면(GUI) 연동 */
/* 계산에는 관여하지 않는다. 상태를 보내고, 터치 명령은 키보드 입력과 같은 경로로 넣는다. */
static int g_ui_sock = -1;
static struct sockaddr_in g_ui_addr;
static long g_ui_resets = 0;

static void ui_open(int port)
{
    g_ui_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (g_ui_sock < 0) { perror("socket(ui)"); exit(1); }
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    a.sin_port = htons((unsigned short)(port + 1));
    if (bind(g_ui_sock, (struct sockaddr *)&a, sizeof a) < 0) { perror("bind(ui)"); exit(1); }
    fcntl(g_ui_sock, F_SETFL, O_NONBLOCK);
    g_ui_addr = a;
    g_ui_addr.sin_port = htons((unsigned short)port);
}

static void ui_poll(void)
{
    char buf[64];
    if (g_ui_sock < 0) return;
    for (;;) {
        ssize_t r = recv(g_ui_sock, buf, sizeof buf - 1, 0);
        if (r <= 0) break;
        buf[r] = '\0';
        if (!strncmp(buf, "action", 6)) g_action_left = ACTION_HOLD;
        else if (!strncmp(buf, "reset", 5)) g_reset_req = true;
    }
}

/* S,t,valid,yaw,pitch,gaze_on,frozen,esc_m0,metric_m0,esc_sel,metric_sel,action,sel_model,ended,resets,solo,source */
static void ui_send(long k, const des_input_t *in, const des_output_t *o, bool ended)
{
    if (g_ui_sock < 0) return;
    const char *src = opt.csv ? strrchr(opt.csv, '/') : NULL;
    src = opt.csv ? (src ? src + 1 : opt.csv) : "UDP";
    char buf[256];
    int n = snprintf(buf, sizeof buf, "S,%.2f,%d,%.2f,%.2f,%d,%d,%d,%.3f,%d,%.3f,%d,%d,%d,%ld,%d,%s\n",
                     k * DES_DT, in->valid, in->yaw, in->pitch, o->gaze_on, o->frozen,
                     o->esc[0], o->metric[0], o->esc[1], o->metric[1], in->action,
                     DES_SEL_MODEL, ended, g_ui_resets, opt.solo, src);
    sendto(g_ui_sock, buf, (size_t)n, 0, (struct sockaddr *)&g_ui_addr, sizeof g_ui_addr);
}

/* ------------------------------------------------------------------ 대시보드 */
static const char *state_color[5] = {"\033[1;32m", "\033[1;33m", "\033[1;35m", "\033[1;31m", "\033[1;37;41m"};
static const char *metric_label[4] = {"이탈 타이머", "이탈 타이머", "누적 이탈  ", "주의 버퍼  "};
static double g_dms_rate = 0;   /* UDP 수신 프레임/s */

static void dash_init(void) { if (!opt.quiet) printf("\033[2J"); }

static void dash_draw(long k, const des_input_t *in, const des_output_t *o)
{
    if (opt.quiet) return;
    printf("\033[H\033[1m Driver Engagement Supervisor\033[0m   t = %8.2f s\033[K\n\n", k * DES_DT);
    printf(" 입력  valid=%d  yaw=%+6.1f  pitch=%+6.1f  주시=%d  고정의심=%d", in->valid, in->yaw,
           in->pitch, o->gaze_on, o->frozen);
    if (opt.udp_port) printf("   DMS %.0f fps", g_dms_rate);
    printf("\033[K\n\n");
    for (int c = opt.solo ? 1 : 0; c < DES_N_CH; c++) {
        int m = c == 0 ? 0 : DES_SEL_MODEL;
        printf(" %-18s %s %-11s \033[0m  %s %5.2f s\033[K\n", ch_label(c), state_color[o->esc[c]],
               des_state_name[o->esc[c]], metric_label[m], o->metric[c]);
    }
    printf("\n");
    if (g_tm.n)
        printf(" 주기: 지연 평균 %.3f ms / 최대 %.3f ms, 1 ms 초과 %ld회\033[K\n",
               1e3 * g_tm.lat_sum / g_tm.n, 1e3 * g_tm.lat_max, g_tm.over1ms);
    printf(" [space] 운전자 응답  [r] 리셋  [q] 종료%s\033[K\n",
           g_action_left > 0 ? "   (응답 입력 중)" : "");
    fflush(stdout);
}
#endif /* !_WIN32 */

/* ------------------------------------------------------------------ GPIO */
#ifdef USE_GPIOD
/* LED: 채널마다 4개, 단계 k(1~4) 이상이면 k번째 LED 켬. 부저: 선택 모델 강화 EOR 이상 */
static const unsigned int g_pins[9] = {5, 6, 13, 19,    /* M0: EOR, 강화, DCA, 운전불가 */
                                       12, 16, 20, 21,  /* 선택 모델 */
                                       26};             /* 부저 */
static struct gpiod_line_request *g_req = NULL;
static enum gpiod_line_value g_val[9];

static void gpio_open(const char *path)
{
    struct gpiod_chip *chip = gpiod_chip_open(path);
    if (!chip) { perror(path); exit(1); }
    struct gpiod_line_settings *s = gpiod_line_settings_new();
    gpiod_line_settings_set_direction(s, GPIOD_LINE_DIRECTION_OUTPUT);
    gpiod_line_settings_set_output_value(s, GPIOD_LINE_VALUE_INACTIVE);
    struct gpiod_line_config *lc = gpiod_line_config_new();
    gpiod_line_config_add_line_settings(lc, g_pins, 9, s);
    struct gpiod_request_config *rc = gpiod_request_config_new();
    gpiod_request_config_set_consumer(rc, "des_supervisor");
    g_req = gpiod_chip_request_lines(chip, rc, lc);
    gpiod_request_config_free(rc);
    gpiod_line_config_free(lc);
    gpiod_line_settings_free(s);
    gpiod_chip_close(chip);
    if (!g_req) { perror("gpiod_chip_request_lines"); exit(1); }
    for (int i = 0; i < 9; i++) g_val[i] = GPIOD_LINE_VALUE_INACTIVE;
}

static void gpio_update(long k, const des_output_t *o)
{
    enum gpiod_line_value v[9];
    for (int c = 0; c < 2; c++)
        for (int j = 0; j < 4; j++)
            v[4 * c + j] = (o->esc[c] >= j + 1 && !(c == 0 && opt.solo))
                         ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE;
    bool buzz = o->esc[1] >= 3 || (o->esc[1] == 2 && (k / 25) % 2 == 0);   /* 강화 EOR: 2 Hz 단속 */
    v[8] = buzz ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE;
    if (memcmp(v, g_val, sizeof v)) {
        memcpy(g_val, v, sizeof v);
        gpiod_line_request_set_values(g_req, g_val);
    }
}

static void gpio_close(void)
{
    if (!g_req) return;
    for (int i = 0; i < 9; i++) g_val[i] = GPIOD_LINE_VALUE_INACTIVE;
    gpiod_line_request_set_values(g_req, g_val);
    gpiod_line_request_release(g_req);
    g_req = NULL;
}
#else
static void gpio_open(const char *p) { (void)p; fprintf(stderr, "GPIO 미지원 빌드입니다 (make GPIO=1)\n"); exit(1); }
static void gpio_update(long k, const des_output_t *o) { (void)k; (void)o; }
static void gpio_close(void) {}
#endif

/* ------------------------------------------------------------------ 1 스텝 */
static void run_step(long k, const des_input_t *in, des_output_t *o)
{
    des_app_step(in, o);
    log_step(k, in, o);
    summary_update(k, o);
    if (opt.gpio) gpio_update(k, o);
}

/* CSV: 스텝 k의 입력 = 시각 (k-1)dt 이전 최근 프레임 (src/des_resample.m과 같은 규칙) */
static long g_fi = -1;
static void csv_input(long k, des_input_t *in)
{
    double t_s = (double)(k - 1) * DES_DT;
    while (g_fi + 1 < g_nframes && g_frames[g_fi + 1].ts <= t_s + DES_TOL) g_fi++;
    des_zoh(g_fi >= 0 ? &g_frames[g_fi] : NULL, t_s, in);
}

static long csv_nsteps(void)
{
    return (long)floor(g_frames[g_nframes - 1].ts / DES_DT + DES_TOL) + 1;
}

static void run_csv_fast(void)
{
    long n = csv_nsteps();
    if (opt.duration > 0 && opt.duration / DES_DT < n) n = (long)(opt.duration / DES_DT);
    des_input_t in; des_output_t o;
    for (long k = 1; k <= n && !g_stop; k++) {
        csv_input(k, &in);
        run_step(k, &in, &o);
    }
}

#ifndef _WIN32
/* ------------------------------------------------------------------ UDP */
static int g_sock = -1;

static void udp_open(int port)
{
    g_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (g_sock < 0) { perror("socket"); exit(1); }
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_ANY);
    a.sin_port = htons((unsigned short)port);
    if (bind(g_sock, (struct sockaddr *)&a, sizeof a) < 0) { perror("bind"); exit(1); }
    fcntl(g_sock, F_SETFL, O_NONBLOCK);
}

/* 대기 중인 패킷을 모두 읽고 가장 최근 것을 last에. 받은 개수 반환 */
static int udp_poll(des_frame_t *last, double t_now, bool apply_calib)
{
    char buf[512], *f[8];
    int got = 0;
    for (;;) {
        ssize_t r = recv(g_sock, buf, sizeof buf - 1, 0);
        if (r <= 0) break;
        buf[r] = '\0';
        buf[strcspn(buf, "\r\n")] = '\0';
        int n = split(buf, f, 8);
        if (n < 4) continue;
        last->ts     = t_now;
        parse_gaze(last, f[1], f[2], f[3], apply_calib ? opt.yaw0 : 0, apply_calib ? opt.pitch0 : 0);
        last->action = n >= 5 && parse_flag(f[4]);
        last->reset  = false;
        got++;
    }
    return got;
}

/* --calib (UDP): 시작 전에 SEC초 동안 받은 valid 프레임 평균을 0점으로 */
static void calib_udp(void)
{
    fprintf(stderr, "보정: %.1f초 동안 전방을 보세요...\n", opt.calib);
    double t0 = mono_s(), sy = 0, sp = 0;
    long n = 0;
    des_frame_t fr;
    while (mono_s() - t0 < opt.calib && !g_stop) {
        if (udp_poll(&fr, mono_s() - t0, false) && fr.valid) { sy += fr.yaw; sp += fr.pitch; n++; }
        usleep(5000);
    }
    if (!n) { fprintf(stderr, "보정 실패: valid 프레임을 받지 못했습니다. 0점 보정 없이 진행\n"); return; }
    opt.yaw0 = sy / n; opt.pitch0 = sp / n;
    fprintf(stderr, "보정: yaw0 %+.2f, pitch0 %+.2f deg (%ld 프레임)\n", opt.yaw0, opt.pitch0, n);
}

/* ------------------------------------------------------------------ 실시간 루프 (CSV / UDP 공용) */
static void run_realtime(void)
{
    if (opt.rt) {
        struct sched_param sp = {.sched_priority = 80};
        if (sched_setscheduler(0, SCHED_FIFO, &sp) < 0) perror("SCHED_FIFO (sudo 필요)");
        mlockall(MCL_CURRENT | MCL_FUTURE);
    }
    long n_csv = opt.csv ? csv_nsteps() : 0;
    long n_max = opt.duration > 0 ? (long)(opt.duration / DES_DT) : 0;

    des_frame_t last = {0};
    bool have = false;
    long pkt_count = 0;
    double rate_t0 = 0;

    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);
    double t0 = next.tv_sec + next.tv_nsec * 1e-9;
    des_input_t in = {0}; des_output_t o = {0};
    long last_k = 0;
    dash_init();

    for (long k = 1; !g_stop; k++) {
        if (opt.csv && k > n_csv) break;
        if (n_max && k > n_max) break;
        if (k > 1) {                               /* 스텝 k는 t0 + (k-1)dt 에 실행 */
            ts_add_ns(&next, DT_NS);
            clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
        }
        double target = next.tv_sec + next.tv_nsec * 1e-9;
        double t_wake = mono_s();
        double lat = t_wake - target;

        kbd_poll();
        if (opt.csv) {
            csv_input(k, &in);
        } else {
            int got = udp_poll(&last, (double)(k - 1) * DES_DT, true);
            if (got) have = true;
            pkt_count += got;
            if (t_wake - t0 - rate_t0 >= 1.0) {
                g_dms_rate = pkt_count / (t_wake - t0 - rate_t0);
                pkt_count = 0; rate_t0 = t_wake - t0;
            }
            des_zoh(have ? &last : NULL, (double)(k - 1) * DES_DT, &in);
        }
        ui_poll();
        kbd_apply(&in);
        if (in.reset) g_ui_resets++;

        run_step(k, &in, &o);
        double exec = mono_s() - t_wake;

        if (k > 1) {                               /* 첫 스텝은 기준점이라 제외 */
            g_tm.n++;
            g_tm.lat_sum += lat; g_tm.exec_sum += exec;
            if (lat > g_tm.lat_max) g_tm.lat_max = lat;
            if (exec > g_tm.exec_max) g_tm.exec_max = exec;
            if (lat > 1e-3) g_tm.over1ms++;
        }
        if (k % 10 == 0) dash_draw(k, &in, &o);   /* 대시보드는 10 Hz */
        if (k % 5 == 0) ui_send(k, &in, &o, false);   /* GUI는 20 Hz */
        last_k = k;
    }
    if (last_k) ui_send(last_k, &in, &o, true);
}
#endif /* !_WIN32 */

/* ------------------------------------------------------------------ main */
int main(int argc, char **argv)
{
    parse_args(argc, argv);
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    for (int c = 0; c < DES_N_CH; c++) g_sum.first_eor[c] = -1;

    if (opt.csv) {
        if (!load_csv(opt.csv)) return 1;
        if (opt.calib > 0) calib_csv();
    }
    log_open();
    if (opt.gpio) gpio_open(opt.gpio_chip);
    des_app_init();

    if (opt.csv && opt.fast) {
        run_csv_fast();
    } else {
#ifdef _WIN32
        fprintf(stderr, "Windows 빌드는 --csv FILE --fast 만 지원합니다 (back-to-back 검증용)\n");
        return 2;
#else
        if (opt.udp_port) {
            udp_open(opt.udp_port);
            if (opt.calib > 0) calib_udp();
        }
        if (opt.ui_port) ui_open(opt.ui_port);
        kbd_init();
        run_realtime();
        timing_print();
#endif
    }

    des_app_term();
    if (opt.gpio) gpio_close();
    if (g_log) fclose(g_log);
    summary_print();
    return 0;
}
