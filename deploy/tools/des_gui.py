#!/usr/bin/env python3
"""des_gui.py  Driver Engagement Supervisor 화면 (5인치 800x480 HDMI 터치스크린용)

des_main을 --ui 로 실행하면 상태를 127.0.0.1:5006 으로 20 Hz 보낸다. 이 프로그램은 그걸
받아 그리기만 한다. 경고 판단은 전부 des_main(생성 C 코드)이 하고, 화면이 느려져도
10 ms 루프와 LED/부저에는 영향이 없다. 터치 버튼(운전자 응답, 리셋)은 5007로 보낸다.

    python3 des_gui.py                 # Pi: 전체화면
    python3 des_gui.py --window        # 창 모드 (노트북에서 확인)
    python3 des_gui.py --mock          # des_main 없이 가짜 데이터로 화면 확인
    키: q / Esc 종료,  f 전체화면 전환

필요: sudo apt install python3-pygame fonts-noto-cjk
"""
import argparse
import math
import os
import socket
import sys
import time
from collections import deque

import pygame

W, H = 800, 480
STAGES = ["정상", "EOR", "강화 EOR", "DCA", "운전불가"]
STAGE_SUB = ["", "전방을 보세요", "경고 강화 (소리)", "운전자 응답 요청", "운전 불가 대응"]
C = {
    "bg": (16, 20, 24), "panel": (28, 34, 40), "line": (52, 61, 69), "fg": (232, 236, 239),
    "muted": (140, 152, 161), "accent": (92, 195, 196),
    "s": [(46, 160, 96), (232, 186, 20), (240, 128, 32), (226, 66, 50), (150, 28, 38)],
    "on": (70, 200, 120), "off": (235, 90, 75), "invalid": (120, 128, 136),
}
AOI_YAW, AOI_PITCH = 11.0, 13.0          # src/des_params.m 과 같은 값 (표시용)
METRIC_MAX = 5.0                          # M0 이탈 타이머 / M3 버퍼 상한 [s]
HIST_S = 30.0


def find_font():
    names = ["notosanscjkkr", "notosanscjk", "notosanskr", "nanumgothic", "malgungothic", "applesdgothicneo"]
    for n in names:
        p = pygame.font.match_font(n)
        if p:
            return p
    for p in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
              "/usr/share/fonts/truetype/nanum/NanumGothic.ttf", "C:/Windows/Fonts/malgun.ttf"]:
        if os.path.exists(p):
            return p
    print("한글 폰트를 찾지 못했습니다: sudo apt install fonts-noto-cjk", file=sys.stderr)
    return None


def find_bold(regular):
    if not regular:
        return None
    for cand in [regular.replace("Regular", "Bold"), regular.replace("malgun.ttf", "malgunbd.ttf"),
                 pygame.font.match_font("notosanscjkkr", bold=True) or ""]:
        if cand and cand != regular and os.path.exists(cand):
            return cand
    return regular


class State:
    def __init__(self):
        self.t = 0.0
        self.valid = self.gaze_on = self.frozen = self.action = self.ended = False
        self.yaw = self.pitch = 0.0
        self.esc = [0, 0]
        self.metric = [0.0, METRIC_MAX]
        self.sel = 3
        self.resets = 0
        self.solo = False
        self.src = ""
        self.first_eor = [None, None]
        self.hist = deque()                      # (t, esc0, esc1)
        self.last_rx = 0.0

    def update(self, f):
        t = float(f[1])
        resets = int(f[14])
        if t < self.t - 0.5 or resets != self.resets:      # 새 실행 또는 리셋
            self.first_eor = [None, None]
            self.hist.clear()
        self.t = t
        self.valid, self.yaw, self.pitch = f[2] == "1", float(f[3]), float(f[4])
        self.gaze_on, self.frozen = f[5] == "1", f[6] == "1"
        self.esc = [int(f[7]), int(f[9])]
        self.metric = [float(f[8]), float(f[10])]
        self.action, self.sel, self.ended = f[11] == "1", int(f[12]), f[13] == "1"
        self.resets, self.solo, self.src = resets, f[15] == "1", f[16].strip()
        for c in range(2):
            if self.esc[c] >= 1 and self.first_eor[c] is None:
                self.first_eor[c] = t
        self.hist.append((t, self.esc[0], self.esc[1]))
        while self.hist and self.hist[0][0] < t - HIST_S:
            self.hist.popleft()
        self.last_rx = time.monotonic()


class Mock:
    """des_main 없이 화면을 확인하는 가짜 데이터: 4.8 s 이탈 / 0.3 s 주시 반복, M3 단계는 대략값."""
    def __init__(self, solo=False):
        self.t0 = time.monotonic()
        self.solo = solo

    def frame(self, t=None):
        t = time.monotonic() - self.t0 if t is None else t
        t = t % 40.0
        ph = (t - 2.0) % 5.1 if t > 2.0 else -1
        on = t <= 2.0 or ph >= 4.8
        e1 = 0 if t < 7.5 else 1 if t < 10.5 else 2 if t < 15.5 else 3 if t < 20.5 else 4
        buf = max(0.0, 5.0 - max(0.0, t - 2.0) * 0.9) if e1 == 0 else 0.0
        yaw = 2.0 * math.sin(t * 3) if on else 28.0 + 2 * math.sin(t * 5)
        pitch = 1.5 * math.cos(t * 2) if on else -31.0
        f = ["S", f"{t:.2f}", "1", f"{yaw:.2f}", f"{pitch:.2f}", "1" if on else "0", "0",
             "0", f"{(0 if on else ph):.3f}", str(e1), f"{buf:.3f}", "0", "3", "0", "0", "1" if self.solo else "0", "3_evasion.csv"]
        return f


class App:
    def __init__(self, args):
        self.args = args
        pygame.init()
        flags = 0 if args.window else pygame.FULLSCREEN
        self.screen = pygame.display.set_mode((W, H), flags)
        pygame.display.set_caption("Driver Engagement Supervisor")
        if not args.window:
            pygame.mouse.set_visible(False)
        reg = find_font()
        bold = find_bold(reg)
        F = lambda p, s: pygame.font.Font(p, s)
        self.f_title, self.f_small, self.f_body = F(bold, 18), F(reg, 14), F(reg, 17)
        self.f_stage, self.f_num, self.f_btn = F(bold, 52), F(bold, 20), F(bold, 22)
        self.f_stage_big = F(bold, 68)
        self.st = State()
        self.mock = Mock(args.solo) if args.mock else None
        self.sock = None
        if not args.mock:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.bind(("127.0.0.1", args.port))
            self.sock.setblocking(False)
        self.btn_action = pygame.Rect(604, 300, 188, 84)
        self.btn_reset = pygame.Rect(604, 392, 188, 80)
        self.flash_until = {"action": 0.0, "reset": 0.0}

    # ---------------------------------------------------------------- 입출력
    def poll(self):
        if self.mock:
            self.st.update(self.mock.frame())
            return
        while True:
            try:
                data = self.sock.recv(512)
            except (BlockingIOError, OSError):
                break
            f = data.decode("utf-8", "replace").strip().split(",")
            if len(f) >= 17 and f[0] == "S":
                try:
                    self.st.update(f)
                except ValueError:
                    pass

    def send(self, cmd):
        self.flash_until[cmd] = time.monotonic() + 0.4
        if self.sock:
            self.sock.sendto(cmd.encode(), ("127.0.0.1", self.args.port + 1))

    # ---------------------------------------------------------------- 그리기
    def text(self, font, s, color, pos, anchor="topleft"):
        img = font.render(s, True, color)
        r = img.get_rect(**{anchor: pos})
        self.screen.blit(img, r)
        return r

    def draw_header(self):
        st = self.st
        self.text(self.f_title, "Driver Engagement Supervisor", C["fg"], (12, 10))
        src = st.src if st.src else ""
        self.text(self.f_small, src, C["muted"], (12, 32))
        self.text(self.f_num, f"t {st.t:6.2f} s", C["fg"], (W - 12, 12), "topright")
        x = W - 140
        chips = []
        if not st.valid:
            chips.append(("얼굴 미검출", C["off"]))
        elif st.frozen:
            chips.append(("고정 의심", C["s"][2]))
        else:
            chips.append(("정면 주시" if st.gaze_on else "이탈", C["on"] if st.gaze_on else C["off"]))
        if st.ended:
            chips.append(("재생 끝", C["muted"]))
        for label, col in chips:
            img = self.f_small.render(label, True, C["bg"])
            r = pygame.Rect(0, 0, img.get_width() + 16, 22)
            r.topright = (x, 13)
            pygame.draw.rect(self.screen, col, r, border_radius=11)
            self.screen.blit(img, img.get_rect(center=r.center))
            x = r.left - 8

    def draw_panel(self, c, rect):
        st = self.st
        e = st.esc[c]
        now = time.monotonic()
        blink = e >= 3 and int(now * 4) % 2 == 0
        if e == 0:
            pygame.draw.rect(self.screen, C["panel"], rect, border_radius=12)
            pygame.draw.rect(self.screen, C["s"][0], rect, width=3, border_radius=12)
            fg, sub = C["s"][0], C["muted"]
        else:
            col = C["s"][e]
            if blink:
                col = tuple(int(v * 0.72) for v in col)
            pygame.draw.rect(self.screen, col, rect, border_radius=12)
            fg = (20, 20, 20) if e == 1 else (255, 255, 255)
            sub = fg
        name = "M0  R171 타이머 기준선" if c == 0 else f"M{st.sel}  주의 버퍼 (최종 모델)"
        self.text(self.f_body, name, sub if e else C["fg"], (rect.x + 16, rect.y + 12))
        self.text(self.f_stage_big if rect.w > 600 else self.f_stage, STAGES[e], fg,
                  (rect.centerx, rect.y + 90), "center")
        self.text(self.f_body, STAGE_SUB[e], sub, (rect.centerx, rect.y + (146 if rect.w > 600 else 138)), "center")
        fe = st.first_eor[c]
        self.text(self.f_body, f"첫 EOR  {fe:.2f} s" if fe is not None else "경고 없음", sub,
                  (rect.x + 16, rect.y + 160))
        # 지표 막대
        m = max(0.0, min(METRIC_MAX, st.metric[c]))
        label = "이탈 타이머" if c == 0 else "주의 버퍼"
        bar = pygame.Rect(rect.x + 16, rect.bottom - 34, rect.w - 32, 14)
        self.text(self.f_small, f"{label}  {st.metric[c]:.2f} / {METRIC_MAX:.0f} s", sub,
                  (rect.x + 16, rect.bottom - 56))
        pygame.draw.rect(self.screen, C["bg"], bar, border_radius=7)
        fill = bar.copy()
        fill.w = int(bar.w * m / METRIC_MAX)
        if c == 0:
            fcol = C["s"][3] if m > 4.0 else C["s"][1] if m > 2.0 else C["accent"]
        else:
            fcol = C["s"][0] if m > 2.5 else C["s"][1] if m > 1.0 else C["s"][3]
        if fill.w > 0:
            pygame.draw.rect(self.screen, fcol, fill, border_radius=7)

    def draw_gaze(self, rect):
        st = self.st
        pygame.draw.rect(self.screen, C["panel"], rect, border_radius=10)
        self.text(self.f_small, "시선 (보정 후)", C["muted"], (rect.x + 10, rect.y + 6))
        plot = pygame.Rect(rect.x + 10, rect.y + 28, rect.w - 20, rect.h - 38)
        yr, pr = 45.0, 40.0
        sx = lambda yaw: plot.centerx + yaw / yr * plot.w / 2
        sy = lambda pitch: plot.centery - pitch / pr * plot.h / 2
        aoi = pygame.Rect(0, 0, int(AOI_YAW / yr * plot.w), int(AOI_PITCH / pr * plot.h))
        aoi.center = plot.center
        pygame.draw.rect(self.screen, C["line"], plot, width=1)
        pygame.draw.rect(self.screen, (40, 70, 55), aoi)
        pygame.draw.rect(self.screen, C["s"][0], aoi, width=1)
        if st.valid:
            x = max(plot.left, min(plot.right, sx(st.yaw)))
            y = max(plot.top, min(plot.bottom, sy(st.pitch)))
            col = C["s"][2] if st.frozen else C["on"] if st.gaze_on else C["off"]
            pygame.draw.circle(self.screen, col, (int(x), int(y)), 7)
        else:
            self.text(self.f_small, "얼굴 미검출", C["off"], plot.center, "center")

    def draw_timeline(self, rect):
        st = self.st
        pygame.draw.rect(self.screen, C["panel"], rect, border_radius=10)
        self.text(self.f_small, f"최근 {HIST_S:.0f}초 경고 단계", C["muted"], (rect.x + 10, rect.y + 6))
        left, right = rect.x + 44, rect.right - 12
        if st.solo:                               # (라벨, 채널, y, 높이)
            rows = [(f"M{st.sel}", 1, rect.y + 34, 88)]
        else:
            rows = [("M0", 0, rect.y + 34, 38), (f"M{st.sel}", 1, rect.y + 84, 38)]
        t_now = st.t
        for lab, ch, y, rh in rows:
            self.text(self.f_body, lab, C["fg"], (rect.x + 10, y + rh // 2 - 11))
            base = pygame.Rect(left, y, right - left, rh)
            pygame.draw.rect(self.screen, C["bg"], base)
            h = list(st.hist)
            for j in range(1, len(h)):
                t0, t1 = h[j - 1][0], h[j][0]
                e = h[j][1 + ch]
                x0 = right - (t_now - t0) / HIST_S * (right - left)
                x1 = right - (t_now - t1) / HIST_S * (right - left)
                if x1 <= left:
                    continue
                x0 = max(left, x0)
                hh = rh * (0.2 + 0.2 * e)
                r = pygame.Rect(int(x0), int(y + rh - hh), max(1, int(math.ceil(x1 - x0))), int(hh))
                pygame.draw.rect(self.screen, C["s"][e], r)
        ty = rect.bottom - 22
        for k, lab in [(0, f"-{HIST_S:.0f} s"), (0.5, f"-{HIST_S / 2:.0f} s"), (1, "지금")]:
            x = left + k * (right - left)
            anchor = "topleft" if k == 0 else "topright" if k == 1 else "midtop"
            self.text(self.f_small, lab, C["muted"], (x, ty), anchor)

    def draw_buttons(self):
        now = time.monotonic()
        for rect, cmd, label, base in [(self.btn_action, "action", "운전자 응답", C["accent"]),
                                       (self.btn_reset, "reset", "리셋", C["line"])]:
            active = now < self.flash_until[cmd] or (cmd == "action" and self.st.action)
            col = tuple(min(255, int(v * 1.35)) for v in base) if active else base
            pygame.draw.rect(self.screen, col, rect, border_radius=12)
            fg = C["bg"] if cmd == "action" else C["fg"]
            self.text(self.f_btn, label, fg, rect.center, "center")

    def draw_wait(self):
        overlay = pygame.Surface((W, H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 170))
        self.screen.blit(overlay, (0, 0))
        self.text(self.f_title, "des_main 연결 대기 중", C["fg"], (W // 2, H // 2 - 16), "center")
        self.text(self.f_small, f"./des_main --csv ... --calib 5 --ui {self.args.port}", C["muted"],
                  (W // 2, H // 2 + 14), "center")

    def draw(self):
        self.screen.fill(C["bg"])
        self.draw_header()
        if self.st.solo:
            self.draw_panel(1, pygame.Rect(8, 54, 784, 238))
        else:
            self.draw_panel(0, pygame.Rect(8, 54, 388, 238))
            self.draw_panel(1, pygame.Rect(404, 54, 388, 238))
        self.draw_gaze(pygame.Rect(8, 300, 170, 172))
        self.draw_timeline(pygame.Rect(186, 300, 410, 172))
        self.draw_buttons()
        if not self.mock and (self.st.last_rx == 0 or
                              (not self.st.ended and time.monotonic() - self.st.last_rx > 1.0)):
            self.draw_wait()

    # ---------------------------------------------------------------- 루프
    def run(self):
        clock = pygame.time.Clock()
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    return
                if ev.type == pygame.KEYDOWN:
                    if ev.key in (pygame.K_q, pygame.K_ESCAPE):
                        return
                    if ev.key == pygame.K_f:
                        pygame.display.toggle_fullscreen()
                    if ev.key == pygame.K_SPACE:
                        self.send("action")
                    if ev.key == pygame.K_r:
                        self.send("reset")
                pos = None
                if ev.type == pygame.MOUSEBUTTONDOWN:
                    pos = ev.pos
                elif ev.type == pygame.FINGERDOWN:
                    pos = (int(ev.x * W), int(ev.y * H))
                if pos:
                    if self.btn_action.collidepoint(pos):
                        self.send("action")
                    elif self.btn_reset.collidepoint(pos):
                        self.send("reset")
            self.poll()
            self.draw()
            pygame.display.flip()
            clock.tick(30)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=5006)
    ap.add_argument("--window", action="store_true", help="창 모드")
    ap.add_argument("--mock", action="store_true", help="가짜 데이터로 화면 확인")
    ap.add_argument("--solo", action="store_true", help="--mock에서 M3 단독 화면 확인 (실제 실행에서는 des_main --solo가 정함)")
    ap.add_argument("--shot", nargs=2, metavar=("T", "PNG"), help="mock 시각 T초 화면을 PNG로 저장하고 종료")
    args = ap.parse_args()
    if args.shot:
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        args.mock, args.window = True, True
        app = App(args)
        t = float(args.shot[0])
        for k in range(1, int(t * 20) + 1):          # 20 Hz로 기록을 쌓는다
            app.st.update(app.mock.frame(k / 20))
        app.draw()
        pygame.image.save(app.screen, args.shot[1])
        return
    App(args).run()


if __name__ == "__main__":
    main()
