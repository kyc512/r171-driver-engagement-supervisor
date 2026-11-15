/* des_app.h  생성된 Supervisor 모델(des_supervisor) 감싸기 + DMS 프레임 -> 100 Hz 입력(ZOH)
 *
 * 플랫폼 독립 (RPi5 / Windows 호스트 back-to-back 빌드 공용). 타이밍·소켓·GPIO는 des_main.c.
 */
#ifndef DES_APP_H
#define DES_APP_H

#include <stdbool.h>
#include <stdint.h>

#define DES_N_CH 2           /* 채널 0 = M0(R171 기준선), 1 = 선택 모델 */

/* DMS 프레임 1개 (CSV 한 줄 또는 UDP 패킷 1개) */
typedef struct {
    double ts;               /* [s] CSV: 파일의 timestamp / UDP: 수신 시각 */
    bool   valid;
    double yaw, pitch;       /* [deg], 보정 적용 후 */
    bool   action, reset;
} des_frame_t;

/* 100 Hz 스텝 입력 (모델 inport와 1:1) */
typedef struct {
    bool   valid;
    double yaw, pitch;
    bool   action, reset;
} des_input_t;

typedef struct {
    uint8_t esc[DES_N_CH];   /* 0 ENGAGED, 1 EOR, 2 EOR_ENH, 3 DCA, 4 UNAVAILABLE */
    bool    dis[DES_N_CH];
    double  metric[DES_N_CH];
    bool    gaze_on, frozen;
} des_output_t;

void des_app_init(void);
void des_app_step(const des_input_t *in, des_output_t *out);
void des_app_term(void);

/* ZOH: 스텝 구간 시작 시각 t_s 이전의 가장 최근 프레임(last)으로 입력을 만든다.
 * 프레임이 없거나 DES_IN_STALE보다 오래됐으면 valid = 0 (src/des_resample.m과 같은 규칙). */
void des_zoh(const des_frame_t *last, double t_s, des_input_t *in);

#define DES_TOL 1e-9
extern const char *const des_state_name[5];

#endif
