#!/usr/bin/env python3
"""DMS 대신 UDP로 시선 프레임을 보내는 테스트 송신기 (노트북 -> RPi5 des_main --udp)

  python3 udp_send.py PI_IP --csv dms.csv          # DMS CSV를 실제 시간대로 재생
  python3 udp_send.py PI_IP --synth evasion        # 4.8 s 이탈 / 0.3 s 주시 반복 (30 fps)
  python3 udp_send.py PI_IP --synth normal|continuous|photo

패킷 1개 = 한 줄 "timestamp,valid,yaw,pitch\n" (DMS 팀 송신 형식과 같음)
"""
import argparse
import csv
import math
import random
import socket
import time


def _flag(s):
    s = (s or "").strip().lower()
    return s in ("1", "true") or (s not in ("", "0", "false") and float(s) > 0.5)


def _angle(s):
    try:
        v = float(s)
    except (TypeError, ValueError):          # 빈 칸, None
        return None
    return v if math.isfinite(v) else None


def frames_from_csv(path):
    """timestamp,valid,yaw,pitch 또는 DMS 모듈 출력(timestamp,face_detected,yaw,pitch)"""
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            v = row.get("valid", row.get("face_detected"))
            yaw, pitch = _angle(row["yaw"]), _angle(row["pitch"])
            ok = _flag(v) and yaw is not None and pitch is not None
            yield float(row["timestamp"]), int(ok), yaw or 0.0, pitch or 0.0


def frames_synth(kind, fps=30.0, duration=120.0):
    rnd = random.Random(0)
    n = int(duration * fps)
    for i in range(n):
        t = i / fps
        if kind == "photo":                      # 거의 안 움직이는 정면 얼굴
            yield t, 1, 0.05 * math.sin(t), 0.05 * math.cos(t)
            continue
        if kind == "evasion":
            off = t > 2 and (t - 2) % 5.1 < 4.8
        elif kind == "continuous":
            off = t > 2
        else:                                    # normal: 가끔 1초 미러 확인
            off = t % 8.0 > 7.0
        if off:
            yield t, 1, 40 + rnd.gauss(0, 5), -20 + rnd.gauss(0, 3)
        else:
            yield t, 1, rnd.gauss(0, 3), rnd.gauss(0, 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("host")
    ap.add_argument("--port", type=int, default=5005)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--csv")
    g.add_argument("--synth", choices=["evasion", "normal", "continuous", "photo"])
    ap.add_argument("--loop", action="store_true", help="끝나면 처음부터 반복")
    a = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    while True:
        frames = frames_from_csv(a.csv) if a.csv else frames_synth(a.synth)
        t0 = time.monotonic()
        sent = 0
        for ts, valid, yaw, pitch in frames:
            delay = t0 + ts - time.monotonic()
            if delay > 0:
                time.sleep(delay)
            yaw_s = f"{yaw:.2f}" if valid else "nan"
            pitch_s = f"{pitch:.2f}" if valid else "nan"
            sock.sendto(f"{ts:.3f},{valid},{yaw_s},{pitch_s}\n".encode(), (a.host, a.port))
            sent += 1
            if sent % 30 == 0:
                print(f"\r t={ts:7.2f}s  {sent} frames", end="", flush=True)
        print()
        if not a.loop:
            break


if __name__ == "__main__":
    main()
