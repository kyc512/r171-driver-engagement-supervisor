# RPi5 배포: Driver Engagement Supervisor 실행 프로그램

이 폴더(`deploy/`)만 Pi로 복사하면 된다. MATLAB은 Pi에 필요 없다.

```
deploy/
  codegen/   생성된 C 코드 (MATLAB에서 build_system.m 실행 결과. 손으로 고치지 말 것)
  rpi/       실행 프로그램 des_main.c, Makefile, b2b_pi.sh, demo_check.sh, demo_ui.sh
  demo/      데모용 DMS CSV 4개
  tools/     des_gui.py: 5인치 터치스크린 화면 / udp_send.py: DMS 대신 UDP 프레임을 보내는 테스트 송신기
```

## 1. 복사와 빌드

노트북에서 실행:
```bash
scp -r deploy 사용자명@<Pi IP>:~/des
```

Pi에서 실행:
```bash
sudo apt install -y build-essential          # 최초 1회
chmod -R u+w ~/des && chmod +x ~/des/rpi/*.sh   # Windows(OneDrive)에서 복사하면 읽기 전용이 되므로 매번
cd ~/des/rpi && make                         # 터미널 출력만
# LED/부저를 쓸 때:
sudo apt install -y libgpiod-dev && make clean && make GPIO=1
```

## 2. 실행

| 용도 | 명령 |
|---|---|
| DMS CSV 재생 (실시간 속도, **데모 방식**) | `./des_main --csv dms.csv --calib 5` |
| (사용 안 함) DMS 실시간 수신 (UDP) | `./des_main --udp 5005 --calib 5` |
| 테스트 송신 (노트북 또는 Pi) | `python3 ../tools/udp_send.py <Pi IP> --synth evasion` |
| 로그 저장 | `--log run.csv` 추가 |
| LED/부저 | `--gpio` 추가 (`make GPIO=1` 빌드 필요) |
| 실시간 우선순위 | `sudo ./des_main ... --rt` |
| 화면(GUI) 연동 | `--ui` 추가 (아래 "화면" 참고, 보통은 `./demo_ui.sh`로 실행) |
| M3 단독 표시 | `--solo` 추가. 대시보드, 화면, LED에 M3만 나온다 (M0 LED는 꺼둠). 계산과 로그는 그대로 |

- **키보드:** `space` = 운전자 응답(DCA 해제용, 0.5초 유지), `r` = 리셋, `q` = 종료
- **종료 시 출력:** 모델별 첫 EOR 시각과 최고 단계, 10ms 주기 타이밍(깨어남 지연, 스텝 실행 시간). 타이밍 값은 보고서의 실시간 근거로 쓸 수 있다.
- `--calib 5`: 시작 후 5초 동안 받은 시선 각도의 평균을 0점으로 잡는다. 운전자는 이 동안 전방을 봐야 한다.
- `--synth`: `evasion` 4.8초 이탈 / 0.3초 주시, `normal` 가끔 1초 미러 확인, `continuous` 연속 이탈, `photo` 고정된 얼굴

### 데모 순서 (`demo/`)

실촬영 DMS CSV 3개와 DMS 팀이 만든 4.8/0.3 합성 CSV 1개다. 모두 `--calib 5`로 실행한다.

| 파일 | 원본 | 내용 | M0 (R171 타이머) | M3 (선택 모델) |
|---|---|---|---|---|
| `1_normal.csv` | s1_2_1 | 정상 주행 중 내비 확인 | 경고 없음 | 경고 없음 |
| `2_continuous.csv` | s2_1 | 스마트폰 연속 이탈 | 11.11초 EOR | 11.11초 EOR (같은 시각) |
| `3_evasion.csv` | s2_2 (11/23 재촬영, 25.0초까지) | 약 4.5초 이탈 / 0.5초 주시 반복 | **경고 없음** | 11.15초 EOR → 운전불가 |
| `4_model.csv` | s3_1 | 머리 모형을 거치대에 고정 | 경고 없음 | 15.12초 EOR (고정 탐지) |

```bash
cd ~/des/rpi
./des_main --csv ../demo/3_evasion.csv --calib 5          # --gpio 를 붙이면 LED/부저
./demo_check.sh                                           # 4개를 빠르게 돌려 위 표와 같은지 확인 (로그: ../demo_log)
```

위 표의 값은 WSL gcc 빌드로 확인했고, MATLAB 기준 코드와 매 스텝 일치한다
(`run_dms_results('deploy/demo', 5, 'build/demo_c')`). RPi5에서도 4개 모두 같은 값이 나왔다(11/23).

### RPi5 확인 결과 (2026-11-23, `fz_range` 10° 반영 후)

| 항목 | 결과 |
|---|---|
| 빌드 (`make GPIO=1`, gcc, Raspberry Pi OS Trixie) | 경고 없이 성공 |
| `demo_check.sh` | 데모 4개 모두 위 표와 같음 |
| back-to-back (`run_b2b_c('pi')`) | 34개 시나리오, 415,233 스텝 모두 MATLAB 기준 코드와 일치 |
| 10 ms 주기 (11/18, 3_evasion 이전 합성본, 2500 스텝) | 깨어남 지연 평균 0.057 ms / 최대 0.091 ms, 1 ms 초과 0회. 스텝 실행 평균 0.004 ms / 최대 0.013 ms |
| 5인치 화면 | 비교 모드와 `--solo` 모두 정상 표시, 터치 버튼 동작 |

스텝 실행 시간 최대 0.013 ms는 10 ms 주기의 0.13%다. 데모는 화면만 쓴다(`--gpio` 없이 실행). 화면이 핀 헤더를 쓰기 때문에 LED/부저는 연결하지 않았고, GPIO 출력 코드는 그대로 남아 있다.

### 화면 (5인치 800x480 HDMI 터치스크린)

M0와 M3의 경고 단계를 나란히 크게 보여주고, 시선 위치, 최근 30초 단계 변화, 터치 버튼(운전자 응답, 리셋)을 둔다.

```bash
sudo apt install -y python3-pygame fonts-noto-cjk     # 최초 1회
./demo_ui.sh ../demo/3_evasion.csv                    # M0와 M3 비교
./demo_ui.sh ../demo/3_evasion.csv --solo             # M3 단독 (제품처럼 보여줄 때)
./demo_ui.sh ../demo/4_model.csv                      # 머리 모형 (고정 탐지)
```

**터치 켜기 (최초 1회):** 이 화면의 터치는 핀 헤더의 SPI(XPT2046)로 들어온다. Raspberry Pi OS 기본 설정에는 꺼져 있다.

```bash
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak
sudo sed -i 's/^#dtparam=spi=on/dtparam=spi=on/' /boot/firmware/config.txt
echo 'dtoverlay=ads7846,cs=1,penirq=25,penirq_pull=2,speed=50000,keep_vref_on=0,swapxy=0,pmax=255,xohms=150,xmin=200,xmax=3900,ymin=200,ymax=3900' | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

- 구조: `des_main --ui`가 상태를 Pi 안(127.0.0.1:5006)으로 20 Hz 보내고, `tools/des_gui.py`는 그걸 그리기만 한다. 경고 판단은 전부 des_main이 한다. 화면이 느려져도 10 ms 루프와 LED/부저에는 영향이 없고, 계산 결과(로그)도 `--ui` 유무와 관계없이 같다.
- 터치 버튼은 127.0.0.1:5007로 가서 키보드 `space`, `r`과 같은 경로로 들어간다.
- Pi 데스크톱이 화면에 로그인된 상태여야 한다. SSH에서 GUI가 안 뜨면 Pi 화면의 터미널에서 `python3 ~/des/tools/des_gui.py`를 먼저 띄우고, SSH에서 `./des_main --csv ... --calib 5 --ui`를 실행한다.
- 노트북에서 화면만 확인: `python des_gui.py --window --mock`

## 3. DMS 입력 형식

**CSV:** 열 이름으로 찾는다. 다른 열이 더 있어도 된다.
```
timestamp,valid,yaw,pitch
0.000,1,-2.31,4.10
0.067,0,nan,nan
```
DMS 모듈(`demo_video.py`)의 출력도 그대로 읽는다: `timestamp,face_detected,yaw,pitch`, 값은 `True`/`False`, 각도가 없으면 빈 칸. 얼굴이 검출됐어도 각도가 비어 있으면 미검출로 처리한다.

**0점 보정:** 실촬영 영상은 카메라가 옆에 있어서 정면을 볼 때 yaw가 약 -20°로 나온다. 촬영 프로토콜의 "처음 5초 정면 주시"를 이용해 `--calib 5`로 실행한다.
```bash
./des_main --csv IMG_3513.csv --calib 5
```

**UDP (팀 결정으로 쓰지 않음, 11/12. 코드만 남아 있음):** 프레임마다 패킷 1개, 내용은 CSV 한 줄과 같다. 포트 5005.
```python
sock.sendto(f"{t:.3f},{int(valid)},{yaw:.2f},{pitch:.2f}\n".encode(), (PI_IP, 5005))
```
- 단위는 초와 도(deg)
- `valid=0`이면 yaw와 pitch는 `nan`
- 실시간 모드에서는 패킷의 timestamp 대신 **Pi가 받은 시각**을 쓴다
- 0.2초 넘게 프레임이 없으면 이탈(`valid=0`)로 처리한다

## 4. GPIO 배선 (`--gpio`, BCM 번호)

| 핀 | M0 (R171 타이머) | 핀 | 선택 모델 |
|---|---|---|---|
| 5 | EOR 이상 | 12 | EOR 이상 |
| 6 | 강화 EOR 이상 | 16 | 강화 EOR 이상 |
| 13 | DCA 이상 | 20 | DCA 이상 |
| 19 | 운전불가 | 21 | 운전불가 |

- **부저: GPIO 26.** 선택 모델이 강화 EOR이면 2Hz로 끊어서 울리고, DCA 이상이면 계속 울린다. 능동 부저를 쓰고, 5V 부저라면 트랜지스터를 거쳐 연결한다.
- **LED 연결:** `GPIO → 330Ω → LED(+)`, `LED(−) → GND`
- 칩 이름이 다르면 `gpiodetect`로 확인해서 `--gpio /dev/gpiochip4`처럼 지정한다.

## 5. Pi에서 back-to-back 검증

생성된 C 코드가 Pi에서 MATLAB 기준 모델과 매 스텝 같은지 확인한다.

1. 노트북 MATLAB에서 `run_b2b_c`를 실행한다. `build/b2b/in_*.csv`가 생성된다.
2. 입력을 Pi로 복사한다: `scp build/b2b/in_*.csv 사용자명@<Pi IP>:~/des/b2b/`
3. Pi에서 실행한다: `~/des/rpi/b2b_pi.sh ~/des/b2b`
4. 결과를 가져온다: `scp '사용자명@<Pi IP>:~/des/b2b/out_*.csv' build/b2b/pi/`
5. 노트북 MATLAB에서 `run_b2b_c('pi')`를 실행한다.

## 모델이나 파라미터를 바꿨을 때

노트북 MATLAB에서 `build_system(3)`을 실행한다(선택 모델 번호). `deploy/codegen/`이 다시 생성되면 Pi로 복사하고 `make`를 다시 한다.

주시 영역 각도(`aoi_*`, 확정: yaw ±11°, pitch ±13°)와 고정 탐지 기준(`fz_*`, 11/23 확정: 10초 동안 10° 미만)은 `src/des_params.m`에서 바꾼다.
