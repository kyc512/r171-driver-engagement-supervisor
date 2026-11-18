#!/bin/sh
# 화면(GUI)과 함께 데모 실행. SSH에서 실행해도 Pi에 연결된 5인치 화면에 띄운다.
#   ./demo_ui.sh ../demo/3_evasion.csv              # 화면만
#   ./demo_ui.sh ../demo/3_evasion.csv --gpio       # 화면 + LED/부저
#   ./demo_ui.sh ../demo/3_evasion.csv --gpio --rt  # + 실시간 우선순위 (des_main만 sudo)
#   ./demo_ui.sh ../demo/3_evasion.csv --solo       # M3 단독 화면 (M0는 숨김)
# GUI는 한 번 띄우면 계속 남아 있으므로 다음 데모는 같은 명령으로 CSV만 바꾸면 된다.
# GUI 종료: pkill -f des_gui.py
cd "$(dirname "$0")"
csv="${1:?사용법: ./demo_ui.sh <csv> [des_main 옵션...]}"
shift
[ -x des_main ] || make -s

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DISPLAY="${DISPLAY:-:0}"
[ -n "$WAYLAND_DISPLAY" ] || [ ! -S "$XDG_RUNTIME_DIR/wayland-0" ] || export WAYLAND_DISPLAY=wayland-0

if ! pgrep -f des_gui.py >/dev/null; then
    python3 ../tools/des_gui.py >/tmp/des_gui.log 2>&1 &
    sleep 2
    pgrep -f des_gui.py >/dev/null || { echo "GUI 실행 실패: /tmp/des_gui.log 확인"; cat /tmp/des_gui.log; }
fi

SUDO=
case " $* " in *" --rt "*) SUDO=sudo ;; esac
$SUDO ./des_main --csv "$csv" --calib 5 --ui "$@"
