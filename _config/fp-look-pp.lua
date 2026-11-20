-- fp-look-pp.lua — KUMM plan 52 (remote stand, `pult.sh "lua _G.__fpl = {on=true, neck=0.5, eye={0,8,0}}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fp-look-pp.lua')"`):
-- sets our post-process anim blueprint ABP_KrinikFirstPersonLook on the HERO's mesh only (SetOverridePostProcessAnimBP — no vanilla asset touched), writes its
-- Active flag and the live tunables (SpineUndo, NeckShare, EyeX/Y/Z, BlendSpeed), and reads back the instance. _G.__fpl.off_pp = true removes the PP blueprint.
-- Until KrinikConanArchery's Lua drives Active on events, this is how the look is switched for a case. [NOT-TESTED]
local cfg = _G.__fpl or {}
local CLASS = '/Game/Mods/KrinikConanArchery/ABP_KrinikFirstPersonLook.ABP_KrinikFirstPersonLook_C'
local h = FindFirstOf('FunCombat_PlayerController_C'):K2_GetPawn()
local mesh = h.Mesh
if cfg.off_pp then mesh:SetOverridePostProcessAnimBP(nil, true); return 'post-process removed' end
local cls = StaticFindObject(CLASS)
if not (cls and cls:IsValid()) then
    LoadAsset('/Game/Mods/KrinikConanArchery/ABP_KrinikFirstPersonLook.ABP_KrinikFirstPersonLook')   -- the full object path (the package path alone did not load, 16:0x)
    cls = StaticFindObject(CLASS)
end
if not (cls and cls:IsValid()) then return 'class not found: ' .. CLASS end
local pp = mesh:GetPostProcessInstance()
if not (pp and pp:IsValid()) or pp:GetClass():GetFullName() ~= cls:GetFullName() then
    mesh:SetOverridePostProcessAnimBP(cls, true)
    pp = mesh:GetPostProcessInstance()
end
if not (pp and pp:IsValid()) then return 'post-process instance not created' end
if cfg.on ~= nil then pp.Active = cfg.on and true or false end
if cfg.spine then pp.SpineUndo = cfg.spine end
if cfg.neck then pp.NeckShare = cfg.neck end
if cfg.eye then pp.EyeX, pp.EyeY, pp.EyeZ = cfg.eye[1], cfg.eye[2], cfg.eye[3] end
if cfg.blend then pp.BlendSpeed = cfg.blend end
return string.format('pp %s · Active %s Alpha %.2f PitchNow %.1f · SpineUndo %.2f NeckShare %.2f Eye %.1f %.1f %.1f · main %s', pp:GetClass():GetFName():ToString(),
    tostring(pp.Active), pp.Alpha, pp.PitchNow, pp.SpineUndo, pp.NeckShare, pp.EyeX, pp.EyeY, pp.EyeZ, mesh:GetAnimInstance():GetClass():GetFName():ToString())
