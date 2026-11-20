#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# rmb-case.sh <метка> <мс замера> "<последовательность mouse-seq.ps1>" — один кейс матрицы камеры лука (KUMM testcases/
# TC_conan_bow_camera_rmb_matrix_2026-10-27.md): замер пультом (fov-sampler.lua, уже загружен dofile) + настоящие нажатия (mouse-seq.ps1),
# затем сводка: время ввода и ряд «мс:обзор/ПКМ/сдвиг первого лица». Пишет только fov-<метка>.tsv в папке пульта. [NOT-TESTED]
TAG="$1"; MS="$2"; SEQ="$3"
cd "$(dirname "$0")"
R="$GAME_FWD/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
rm -f "$R/fov-$TAG.tsv"
bash pult.sh "lua return _G.fov_sample($MS, '$TAG')" > /dev/null 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File mouse-seq.ps1 -Seq "$SEQ" | tr '\n' ' '; echo
for i in $(seq 1 40); do [ -f "$R/fov-$TAG.tsv" ] && break; sleep 0.5; done
# r/u — камера вправо и вверх от героя в его осях, см (fov-sampler.lua с 2026-10-28)
awk -F'\t' 'NR>1 { printf "%s:%s/%s/%s r%s u%s  ", $1, $2, ($3=="true"?"R":"-"), ($4=="0,0,0"?"0":$4), $7, $8 } END { print "" }' "$R/fov-$TAG.tsv"
