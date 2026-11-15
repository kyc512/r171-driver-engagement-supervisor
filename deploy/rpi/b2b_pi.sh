#!/bin/sh
# RPi5에서 back-to-back 로그 생성: ./b2b_pi.sh <in_*.csv가 있는 폴더>
# 결과 out_*.csv를 노트북의 supervisor/build/b2b/pi/ 로 가져와 MATLAB에서 run_b2b_c('pi')
set -e
dir="${1:?사용법: ./b2b_pi.sh <in_*.csv 폴더>}"
cd "$(dirname "$0")"
make -s
for f in "$dir"/in_*.csv; do
    out="$dir/out_${f##*/in_}"
    ./des_main --csv "$f" --fast --log "$out" 2>/dev/null
    echo "$f -> $out"
done
