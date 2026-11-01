-- fov-sampler.lua — замер камеры лука для матрицы кейсов (KUMM testcases/TC_conan_bow_camera_rmb_matrix_2026-10-27.md).
-- Пульт: `lua dofile([[D:\work\ai_sandbox\ConanExiles\_config\fov-sampler.lua]])` — один раз за запуск, затем
-- `lua return _G.fov_sample(<мс>, '<метка>')` — каждые 50 мс: время, обзор, ПКМ (физическая), сдвиг штанги первого лица, камера↔штанга,
-- место камеры относительно героя в его осях (вперёд, вправо, вверх, см) — для кейсов «камера ниже, чем в покое» (2026-10-28);
-- по окончании пишет `ue4ss/Mods/KrinikAgentRemote/fov-<метка>.tsv`. Только чтение, ни одной записи в игру.
-- Шаги — отложенные действия игрового потока (ExecuteInGameThreadWithDelay), не ExecuteWithDelay → ExecuteInGameThread: тот двойной прыжок
-- роняет UE4SS при частых событиях (падение 2026-10-28 20:06, EXP-0062). [NOT-TESTED]
_G.fov_sample = function(total_ms, tag)
    local rows, t0 = {}, os.clock()
    local function tick()
        pcall(function()
            local pc = FindFirstOf('FunCombat_PlayerController_C')
            local p = pc.Pawn
            local cm = pc.PlayerCameraManager
            local arm = p.FirstPersonCameraArm
            local o = arm.SocketOffset
            local a, c = arm:K2_GetComponentLocation(), cm:GetCameraLocation()
            local h = p:K2_GetActorLocation()
            local f, r = p:GetActorForwardVector(), p:GetActorRightVector()
            local d = { X = c.X - h.X, Y = c.Y - h.Y, Z = c.Z - h.Z }
            rows[#rows + 1] = string.format('%d\t%.1f\t%s\t%.0f,%.0f,%.0f\t%.0f\t%.1f\t%.1f\t%.1f', math.floor((os.clock() - t0) * 1000),
                cm:GetFOVAngle(), tostring(pc:IsInputKeyDown({ KeyName = FName('RightMouseButton') })), o.X, o.Y, o.Z,
                math.sqrt((a.X - c.X) ^ 2 + (a.Y - c.Y) ^ 2 + (a.Z - c.Z) ^ 2),
                d.X * f.X + d.Y * f.Y, d.X * r.X + d.Y * r.Y, d.Z)
        end)
        if (os.clock() - t0) * 1000 < total_ms then
            ExecuteInGameThreadWithDelay(50, tick)
        else
            local f = io.open('ue4ss/Mods/KrinikAgentRemote/fov-' .. tag .. '.tsv', 'w')
            f:write('ms\tfov\trmb\tfp_offset\tcam_arm_cm\tcam_fwd\tcam_right\tcam_up\n' .. table.concat(rows, '\n') .. '\n')
            f:close()
        end
    end
    -- первый шаг — тоже в игровом потоке: команда пульта исполняется там, но так надёжнее при вызове извне
    ExecuteInGameThreadWithDelay(0, tick)
    return 'sampling ' .. total_ms .. ' ms -> fov-' .. tag .. '.tsv'
end
return 'fov sampler ready'
