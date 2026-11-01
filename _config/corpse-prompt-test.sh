#!/usr/bin/env bash
# corpse-prompt-test.sh <A|B> <метка> — опыт «подсказка трупа от третьего лица» (KUMM баг 64 п. 11, трупы), без рук владельца.
# A: сдвиг камеры назад в SocketOffset.X (как в сборке): штанга 125 + offset_x −125. B: тот же сдвиг в штанге: штанга 250 + offset_x 0.
# Камера в обоих — в 250 см от точки штанги. Герой ставится в 150 см от ближайшего трупа, прицел (поворот управления) наводится на тело
# так, чтобы луч из камеры шёл в центр тела; затем кадр окна в фоне (окно вперёд не выводится) и чтение, что подсвечено.
# Мод камеры держит штангу в [zoom_min, zoom_max] — для опыта обе границы ставятся равными; после опыта вернуть: corpse-prompt-test.sh restore.
# [NOT-TESTED]
L="${1:-A}"; TAG="${2:-t}"
cd "$(dirname "$0")"
G="${GAME:-D:/Games/Conan Exiles 3.0.1}/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikConanCamera"
OUT='D:/Temp/claude/d--work-ai-sandbox-KUMM/56181c6a-37ed-4e8b-a357-72e655c0662c/scratchpad/corpse'
mkdir -p "$OUT"
case "$L" in
  A) printf 'offset_x = -125\nzoom_min = 125\nzoom_max = 125\n' > "$G/agent-cmd.txt" ;;
  B) printf 'offset_x = 0\nzoom_min = 250\nzoom_max = 250\n' > "$G/agent-cmd.txt" ;;
  restore) printf 'offset_x = -125\nzoom_min = 60\nzoom_max = 2000\n' > "$G/agent-cmd.txt"; echo restored; exit 0 ;;
esac
sleep 2
FIND="local p=FindFirstOf('BasePlayerChar_C'); local pc=FindFirstOf('FunCombat_PlayerController_C'); local hl=p:K2_GetActorLocation(); local C,cd; for _,x in ipairs(FindAllOf('DismemberedBodySkeletalMesh_C') or {}) do if x:IsValid() then local c=x:K2_GetComponentLocation(); local d=math.sqrt((c.X-hl.X)^2+(c.Y-hl.Y)^2); if not cd or d<cd then C,cd=c,d end end end"
# герой — в 150 см от тела по оси X мира, на своей высоте
bash pult.sh "lua $FIND; local t={X=C.X+150.0,Y=C.Y,Z=hl.Z}; p:K2_SetActorLocation(t,false,{},true); return string.format('moved to %.0f,%.0f,%.0f (corpse %.0f,%.0f,%.0f)', t.X,t.Y,t.Z, C.X,C.Y,C.Z)" | tail -1
sleep 1
# три прохода наведения: поворот из камеры в центр тела (камера сама двигается с поворотом)
for i in 1 2 3; do
  bash pult.sh "lua $FIND; local cam=p.CameraThirdPerson:K2_GetComponentLocation(); local dx,dy,dz=C.X-cam.X,C.Y-cam.Y,C.Z-cam.Z; local yaw=math.deg(math.atan(dy,dx)); local pitch=math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy))); pc:SetControlRotation({Pitch=pitch,Yaw=yaw,Roll=0.0}); return string.format('aim %d pitch=%.1f yaw=%.1f cam->corpse=%.0f', $i, pitch, yaw, math.sqrt(dx*dx+dy*dy+dz*dz))" | tail -1
  sleep 0.5
done
bash pult.sh "lua FindFirstOf('BasePlayerChar_C'):OnUserInactiveChanged(false); return 'awake'" > /dev/null
sleep 1.5
powershell -NoProfile -ExecutionPolicy Bypass -File capture-window.ps1 -Out "$OUT/${TAG}_$L.jpg" -Width 1280 | tail -1
bash pult.sh "lua $FIND; local s=p.ThirdPersonSpringArm; local sel=pc:GetInteractionManager().SelectedComponent; return string.format('layout=$L arm=%.0f socketX=%.0f bonus=%.0f ID=%.0f sel=%s', s.TargetArmLength, s.SocketOffset.X, pc.InteractionDistanceThirdPersonBonus, pc.InteractionDistance, sel and sel:IsValid() and sel:GetFName():ToString() or 'nil')" | tail -1
