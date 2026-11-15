#!/bin/sh
# 데모 CSV(../demo/*.csv)를 빠르게 돌려 로그를 만든다: ./demo_check.sh [로그 폴더]
# 로그를 노트북의 supervisor/build/demo_c/ 로 가져와 MATLAB에서
#   run_dms_results('deploy/demo', 5, 'build/demo_c')
# 를 실행하면 기준 코드와 매 스텝 비교한다.
set -e
cd "$(dirname "$0")"
out="${1:-../demo_log}"
mkdir -p "$out"
make -s
for f in ../demo/*.csv; do
    echo "== $f"
    ./des_main --csv "$f" --fast --quiet --calib 5 --log "$out/${f##*/}"
done
