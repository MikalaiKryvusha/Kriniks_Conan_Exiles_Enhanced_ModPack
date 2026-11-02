#!/usr/bin/env bash
# tp_ground.sh — put the hero ON THE GROUND at a world point (X Y), never into the void.
#   bash tp_ground.sh <X> <Y> [hover_s]
# Why: `K2_SetActorLocation` onto a point whose terrain is not streamed yet drops the hero through the world (2026-11-01 10:2x: z −20068 at the
# beach, −21306 in the north-west; `[OWNER]` «ты б героя поставил в какую-то нормальную локацию… он в текстурах провалился и внизу экрана всё
# черное!» · «как-то ты безответственно тестируешь и отвратительно относишься к созданию тестовых условий» · 2026-11-01 10:47).
# Steps: (1) the hero switches to FLYING (no gravity) and is moved high above the point; (2) waits hover_s (default 12) for the area to stream;
# (3) a line trace straight down (Visibility) finds the surface; (4) the hero is set 120 above the hit and switched back to WALKING.
# No hit → exit 3, the hero stays hovering (never dropped); the trace's hit point is printed. Exit 0 — standing; 2 — the remote failed.
# [TESTED: 2026-11-01 · beach GROUND -20167, volcano GROUND 45640, the hero standing on both frames · KUMM TC_conan_hud_temperature_thresholds_2026-11-01 R3]
X="$1"; Y="$2"; HOVER="${3:-12}"
[ -z "$X" ] || [ -z "$Y" ] && { echo "usage: tp_ground.sh X Y [hover_s]"; exit 2; }
cd "$(dirname "$0")" || exit 2
RES="/d/Games/Conan Exiles 3.0.1/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"
TOP=60000
bash pult.sh "lua local p=FindFirstOf('PlayerController').Pawn p.CharacterMovement:SetMovementMode(5, 0) p:K2_SetActorLocation({X=$X,Y=$Y,Z=$TOP}, false, {}, true) return 'hover'" > /dev/null 2>&1 || exit 2
sleep "$HOVER"
bash pult.sh "lua local p=FindFirstOf('PlayerController').Pawn local ksl=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary') local hit={} local ok=ksl:LineTraceSingle(p, {X=$X,Y=$Y,Z=$TOP-200}, {X=$X,Y=$Y,Z=-80000}, 0, true, {p}, 0, hit, true, {R=1,G=0,B=0,A=1}, {R=0,G=1,B=0,A=1}, 0) if not ok then return 'NOHIT' end local z=hit.ImpactPoint.Z p:K2_SetActorLocation({X=$X,Y=$Y,Z=z+120}, false, {}, true) p.CharacterMovement:SetMovementMode(1, 0) return string.format('GROUND %.0f', z)" > /dev/null 2>&1 || exit 2
r=$(cat "$RES")
echo "$r"
case "$r" in GROUND*) exit 0 ;; *) exit 3 ;; esac
