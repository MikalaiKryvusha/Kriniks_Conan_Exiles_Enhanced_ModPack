#!/usr/bin/env bash
# loot-aim.sh — the crosshair onto the stand's corpse BY THE GAME'S ANSWER (KUMM bug 75), after loot-stand.sh left _G.__ls_body.
# Steps, each paid for on 2026-11-03: a real Shift tap (wakes the idle camera — game map); the view set from the HERO toward the body, pitch −40 (the camera
# stands behind the hero); the game brought to the front FIRST and held there (the strip shows only with the focus); then aim-sweep.lua steps pitch ±20 ×
# yaw ±15 around the start until the game shows the corpse strip. The view stays where the game said «yes»; the next trip to the front
# (loot-take-clip.sh) reopens the window there.
# Why not the camera-to-body aim: it converges to a view nearly straight down (pitch −78), where a yaw step barely moves the screen point — a body 13° off
# the centre needed ≈ 60° of yaw; two sweeps missed (21:20–21:23), the hero-toward-body start hit at step 8 (21:24).
# Why the front first: a sweep started while the game was behind read a stale strip at its step 0 as «hit» (21:29, 21:46 — no window on the clips).
# Exit: 0 hit (prints the sweep line) · 1 miss · 2 the remote silent / no body. [TESTED: 2026-11-03 21:24 · the same calls one by one: «hit pitch -56.0 yaw -109.5
#  (step 8 of 70)» — KUMM bugs/75; this file as a whole: NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 2
P() { bash pult.sh "lua $1" | tail -1; }
case "$(P "return _G.__ls_body and 'body' or 'none'")" in *body*) ;; *) echo "no _G.__ls_body — run loot-stand.sh first"; exit 2;; esac
powershell -NoProfile -File mouse-seq.ps1 -Seq "kdown:0x10,wait:80,kup:0x10,wait:300" > /dev/null 2>&1
P "local h=FindFirstOf('BasePlayerChar_C'):K2_GetActorLocation(); local b=_G.__ls_body; FindFirstOf('FunCombat_PlayerController_C'):SetControlRotation({Pitch=-40.0,Yaw=math.deg(math.atan(b.Y-h.Y,b.X-h.X)),Roll=0.0}); return 'start view'" > /dev/null
powershell -NoProfile -File mouse-seq.ps1 -Seq "wait:23000" > /dev/null 2>&1 &
HOLD=$!
sleep 1.5
P "_G.__as_pitch={0,-4,4,-8,8,-12,12,-16,16,-20}; _G.__as_yaw={0,-5,5,-10,10,-15,15}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/aim-sweep.lua')" > /dev/null
wait $HOLD
r=$(P "return tostring(_G.__aim_sweep)")
echo "$r"
case "$r" in hit*) exit 0;; *) exit 1;; esac
