#!/usr/bin/env bash
# strip-open.sh <tag> [class] [outdir] — the corpse/container strip WBP_ContainerInfo opened BY CODE on the nearest live actor of <class>
# (default Corpse_C), then the 4K frame and the edges readout of corpse-loot-geom.sh noaim (KUMM plan 36 W6, EXP-0394).
# `[OWNER]` «ты много мучаешься над созданием тестовых условий» · «саму плашку кодом открывай» · 2026-10-30 21:14. Aiming the camera at a body
# is unreliable (bug 70); the widget the game creates on a look is the same class and Lua, a second instance.
# Steps: remove the strip this script opened before (_G.__stripOpen) → nearest <class> actor to the hero by full name (no method call on a
# non-matching object: EXP-0386/0387) → LoadAsset + WidgetBlueprintLibrary:Create(pc, cls, pc) → AddToViewport(50) → SetObject(<actor>, 0).
# The game must run and a world be entered; for a corpse make one first (corpse-prompt-shot.sh kills by code).
# Exit: 0 strip in viewport · 1 no strip after SetObject · 2 no <class> actor within MAXD_M (default 50) m.
# [TESTED: 2026-10-30 · Corpse_C and a campfire at 1064 m, two runs, frames read · KUMM testcases/reports/2026-10-30_conan-corpse-strip-backing.md]
TAG="${1:-strip}"; CLS="${2:-Corpse_C}"; OUT="${3:-D:/work/ai_sandbox/ConanExiles/_scratch/corpse-prompt}"; MAXD="${MAXD_M:-50}"   # MAXD_M: search radius, m (a far campfire works — the strip needs no proximity)
cd "$(dirname "$0")"
mkdir -p "$OUT"
r=$(bash pult.sh "lua local old=_G.__stripOpen; if old and old:IsValid() then old:RemoveFromParent() end; _G.__stripOpen=nil; local p=FindFirstOf('BasePlayerChar_C'); local pc=FindFirstOf('FunCombat_PlayerController_C'); local h=p:K2_GetActorLocation(); local best,bd; for _,x in ipairs(FindAllOf('$CLS') or {}) do local f=x:GetFullName(); if not f:find('Default__') and f:find('$CLS', 1, true) then local ok,l=pcall(function() return x:K2_GetActorLocation() end); if ok and l then local d=math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2+(l.Z-h.Z)^2)/100; if d<=$MAXD and (not bd or d<bd) then best,bd=x,d end end end end; if not best then return 'none' end; LoadAsset('/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo.WBP_ContainerInfo'); local cls=StaticFindObject('/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo.WBP_ContainerInfo_C'); local wbl=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'); local w=wbl:Create(pc, cls, pc); w:AddToViewport(50); w:SetObject(best, 0); _G.__stripOpen=w; return string.format('opened on %s at %.1f m', best:GetFName():ToString(), bd)" | tail -1)
echo "$r"
case "$r" in opened*) ;; *) exit 2;; esac
sleep 1
g=$(OUT="$OUT" bash corpse-loot-geom.sh "$TAG" noaim 2>&1 | tail -1)
echo "$g"
case "$g" in *inViewport=true*) exit 0;; *) exit 1;; esac
