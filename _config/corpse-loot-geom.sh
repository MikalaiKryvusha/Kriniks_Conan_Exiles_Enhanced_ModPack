#!/usr/bin/env bash
# corpse-loot-geom.sh <метка> [noaim] — плашка трупа против окна быстрого лута (KUMM баг 64 п. 32), без рук владельца.
# Наводит прицел из камеры на ближайший труп (как corpse-prompt-test.sh; «noaim» — оставить прицел как есть), снимает окно игры в фоне
# (4K, окно вперёд не выводится) и читает пультом экранные края живых виджетов модуля ContainerInfo (WBP_ContainerInfo_C):
# плашки Border_Underlay и W_QuickLootPanel — левый и правый край в пикселях окна, видимость. Зазор gap = левый край окна лута − правый
# край плашки: меньше нуля — наложение.
# [NOT-TESTED]
TAG="${1:-g}"; MODE="${2:-aim}"
cd "$(dirname "$0")"
OUT="${OUT:-D:/work/ai_sandbox/ConanExiles/_scratch/corpse-loot}"
mkdir -p "$OUT"
FIND="local p=FindFirstOf('BasePlayerChar_C'); local pc=FindFirstOf('FunCombat_PlayerController_C'); local hl=p:K2_GetActorLocation(); local C,cd; for _,x in ipairs(FindAllOf('DismemberedBodySkeletalMesh_C') or {}) do if x:IsValid() then local c=x:K2_GetComponentLocation(); local d=math.sqrt((c.X-hl.X)^2+(c.Y-hl.Y)^2); if not cd or d<cd then C,cd=c,d end end end"
if [ "$MODE" != noaim ]; then
  for i in 1 2 3; do
    bash pult.sh "lua $FIND; local cam=pc.PlayerCameraManager:GetCameraLocation(); local dx,dy,dz=C.X-cam.X,C.Y-cam.Y,C.Z+${AIMZ:-40}-cam.Z; pc:SetControlRotation({Pitch=math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy))),Yaw=math.deg(math.atan(dy,dx)),Roll=0.0}); return string.format('aim %d cam->corpse=%.0f hero->corpse=%.0f', $i, math.sqrt(dx*dx+dy*dy+dz*dz), cd)" | tail -1
    sleep 0.5
  done
  bash pult.sh "lua FindFirstOf('BasePlayerChar_C'):OnUserInactiveChanged(false); return 'awake'" > /dev/null
  sleep 1.5
fi
powershell -NoProfile -ExecutionPolicy Bypass -File capture-window.ps1 -Out "$OUT/${TAG}.jpg" -Width 3840 | tail -1
# Края: SlateBlueprintLibrary.LocalToAbsolute / GetAbsoluteSize — пиксели рабочего стола (окно игры на весь экран: те же пиксели окна).
# LocalToViewport не годится: его выходные параметры UE4SS не заполняет (нули, 2026-10-28). Плашка Border_Underlay — не переменная
# виджета, берётся из WidgetTree по имени.
bash pult.sh "lua local SBL=StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary'); local WL=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary'); local w; for _,x in ipairs(FindAllOf('WBP_ContainerInfo_C') or {}) do if x:IsValid() and x:IsInViewport() then w=x end end; if not w then return 'no WBP_ContainerInfo_C in viewport' end; local sc=WL:GetViewportScale(w); local function edge(name, c) if not c or not c:IsValid() then return name..' nil' end; local g=c:GetCachedGeometry(); local a=SBL:LocalToAbsolute(g,{X=0.0,Y=0.0}); local s=SBL:GetAbsoluteSize(g); return string.format('%s vis=%s L=%.0f R=%.0f T=%.0f W=%.0f', name, tostring(c:IsVisible()), a.X, a.X+s.X, a.Y, s.X), a.X, a.X+s.X, c:IsVisible() end; local a,al,ar=edge('strip', (function() for _,x in ipairs(FindAllOf('Border') or {}) do if x:IsValid() and x:GetFName():ToString()=='Border_Underlay' and x:GetOuter():GetOuter()==w then return x end end end)()); local b,bl,br,bv=edge('loot', w.W_QuickLootPanel); local gap=(bv and bl and ar) and string.format(' gap=%.0f', bl-ar) or ''; return string.format('inViewport=%s scale=%.2f | %s | %s%s', tostring(w:IsInViewport()), sc, a, b, gap)" | tail -1
