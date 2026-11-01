#!/usr/bin/env bash
# terrain-probe.sh <x0> <x1> <y0> <y1> <шаг> [выход.txt] — высоты рельефа сеткой лучей сверху вниз через пульт KrinikAgentRemote,
# без полёта: строка на каждый y, столбцы — x от x0 к x1, значения — метры (Z/100), «?» — луч не попал.
# Зачем (KUMM EXP-0332): высоты точек облёта — по замеру, а не на глаз; 2026-10-25 вечером сетка 21×17 у водопада за секунду
# показала нижнее русло (−139), края каньона (−88…−100) и плато (−57), которых разведка облётом не видела.
# Луч — канал видимости: кроны пальм и трава его не останавливают. Игра — в мире (enter-world-remote.sh). До ≈ 1000 лучей за раз.
# [NOT-TESTED]
set -u
X0=$1; X1=$2; Y0=$3; Y1=$4; STEP=$5; OUT="${6:-}"
GAME="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")"
R="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
XS=$STEP; [ "$X1" -lt "$X0" ] && XS=$((-STEP))
YS=$STEP; [ "$Y1" -lt "$Y0" ] && YS=$((-STEP))
LUA="local k=StaticFindObject(\"/Script/Engine.Default__KismetSystemLibrary\") local p=FindFirstOf(\"PlayerController\") local H={} local I={} local N={R=0,G=0,B=0,A=0} local o={\"x: $X0..$X1 step $XS\"} for y=$Y0,$Y1,$YS do local r={} for x=$X0,$X1,$XS do local h=k:LineTraceSingle(p,{X=x,Y=y,Z=30000},{X=x,Y=y,Z=-40000},0,false,I,0,H,true,N,N,0.0) r[#r+1]=h and string.format(\"%d\",math.floor(H.ImpactPoint.Z/100)) or \"?\" end o[#o+1]=y..\" \"..table.concat(r,\" \") end return table.concat(o,\"\\n\")"
BEFORE=$(stat -c %Y "$R/result.txt" 2>/dev/null || echo 0)
echo "lua $LUA" > "$R/cmd.txt"
for i in $(seq 1 60); do
  NOW=$(stat -c %Y "$R/result.txt" 2>/dev/null || echo 0)
  [ ! -f "$R/cmd.txt" ] && [ "$NOW" != "$BEFORE" ] && break
  sleep 0.5
done
[ -f "$R/cmd.txt" ] && { echo "пульт не взял команду за 30 с (игра в мире?)"; rm -f "$R/cmd.txt"; exit 3; }
if [ -n "$OUT" ]; then cp "$R/result.txt" "$OUT"; fi
cat "$R/result.txt"
