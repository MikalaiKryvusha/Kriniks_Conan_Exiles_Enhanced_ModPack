#!/usr/bin/env bash
# bow-socket-offset.sh — куда уйдёт стрела относительно прицела (KUMM план 36 п. 32). Игра пускает стрелу из гнезда лука Socket_Projectile
# ПАРАЛЛЕЛЬНО взгляду камеры (+ подъём 0.0675), без сведения в прицел (байткод GetProjectileDirection кита) — значит, промах на любой
# дистанции равен сдвигу гнезда от луча прицела. Прибор берёт вид камеры (PlayerCameraManager) и мировое место Socket_Projectile лука героя,
# печатает сдвиг вправо (+) / вверх (+) в см и режим камеры. Читать, пока игрок держит натянутый лук. Только чтение.
# [NOT-TESTED]
cd "$(dirname "$0")"
N="${1:-1}"
for i in $(seq 1 "$N"); do
bash pult.sh "lua local p=FindFirstOf('BasePlayerChar_C'); local h=p:K2_GetActorLocation(); local pc=FindFirstOf('FunCombat_PlayerController_C'); local cm=pc.PlayerCameraManager; local c=cm:GetCameraLocation(); local r=cm:GetCameraRotation(); local cp,sp=math.cos(math.rad(r.Pitch)),math.sin(math.rad(r.Pitch)); local cy,sy=math.cos(math.rad(r.Yaw)),math.sin(math.rad(r.Yaw)); local f={X=cp*cy,Y=cp*sy,Z=sp}; local rt={X=-sy,Y=cy,Z=0}; local up={X=f.Y*rt.Z-f.Z*rt.Y, Y=f.Z*rt.X-f.X*rt.Z, Z=f.X*rt.Y-f.Y*rt.X}; if up.Z<0 then up={X=-up.X,Y=-up.Y,Z=-up.Z} end; local bow; for _,a in ipairs(FindAllOf('Actor') or {}) do if a:IsValid() and a:GetClass():GetFName():ToString():lower():find('bow') then local q=a:K2_GetActorLocation(); if math.sqrt((q.X-h.X)^2+(q.Y-h.Y)^2+(q.Z-h.Z)^2)<300 then bow=a end end end; if not bow then return 'no bow' end; local m=bow:GetComponentByClass(StaticFindObject('/Script/Engine.SkeletalMeshComponent')); local s=m:GetSocketLocation(FName('Socket_Projectile')); local d={X=s.X-c.X,Y=s.Y-c.Y,Z=s.Z-c.Z}; local t=d.X*f.X+d.Y*f.Y+d.Z*f.Z; local x=d.X*rt.X+d.Y*rt.Y+d.Z*rt.Z; local y=d.X*up.X+d.Y*up.Y+d.Z*up.Z; return string.format('mode=%s fov=%.0f | socket: ahead=%.0f right=%+.0f up=%+.0f cm | cam pitch=%.1f arm=%.0f', tostring(p.CurrentCameraMode), cm:GetFOVAngle(), t, x, y, r.Pitch, p.ThirdPersonSpringArm.TargetArmLength)" 2>&1 | tail -1
if [ "$i" -lt "$N" ]; then sleep 1; fi
done
exit 0
