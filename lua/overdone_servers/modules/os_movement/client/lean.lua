local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local StatefulHooks = OverdoneServers.StatefulHooks

-- Initialize lean state
OSMove.leanState = OSMove.leanState or 0 -- 0 = no lean, -1 = lean left, 1 = lean right
OSMove.lastLeanAngle = OSMove.lastLeanAngle or 0

local UpdateLeanState = false

-- Set lean state
function SetLeanState(state)
    OSMove.leanState = state

    -- Send lean state to server
    net.Start(module:GetNetworkString("PlayerLeanState"))
    net.WriteInt(OSMove.leanState, 2) -- 2 bits, because we only have three states (-1, 0, 1)
    net.SendToServer()

    OSMove.startTime = CurTime()
    OSMove.startLeanRollAngle = OSMove.lastLeanAngle

    UpdateLeanState = true
end

-- Get lean state from command
concommand.Add("os_lean", function(ply, cmd, args)
    local state = tonumber(args[1])
    if state == nil then return end

    SetLeanState(state)
end)

-- Get lean state from keypress
module:HookAdd("PlayerButtonDown", "LeanKeyPress", function(ply, key)
    if key == KEY_LEFT then
        SetLeanState(OSMove.LeanEnum.LEFT)
    elseif key == KEY_RIGHT then
        SetLeanState(OSMove.LeanEnum.RIGHT)
    elseif key == KEY_UP or key == KEY_DOWN then
        SetLeanState(OSMove.LeanEnum.NONE)
    end
end)

function InitHooks()
    StatefulHooks:Add("CalcView", module.HookPrefix .. "LeanView", function(ply, pos, angles, fov)
        if (not OSMove.startTime or (OSMove.leanState == OSMove.LeanEnum.NONE and not UpdateLeanState)) then return end
        local wantedLean = OSMove.leanState * OSMove.leanAngle -- adjust as needed for lean angle

        local leanTime = OSMove.leanState != OSMove.LeanEnum.NONE and OSMove.leanTime or OSMove.leanTime * 0.5
    
        local timeElapsed = CurTime() - OSMove.startTime
        if timeElapsed <= leanTime then
            local t = timeElapsed / leanTime -- t will range from 0 to 1 over the duration of the animation
            rollAngle = OverdoneServers.EaseFunctions:EaseInOutSine(t, OSMove.startLeanRollAngle, wantedLean)
        else
            rollAngle = wantedLean
            UpdateLeanState = false
        end
    
        angles.roll = rollAngle

        OSMove.lastLeanAngle = angles.roll
        OSMove:ManipulateBones(ply, pos, OSMove.lastLeanAngle)

        ply:SetupBones()

        return {origin = pos, angles = angles, fov = fov}
    end)


    local lastHeadPos = LocalPlayer():EyePos()

    StatefulHooks:Add("CalcView", module.HookPrefix .. "AccurateHeadPos", function(ply, pos, angles, fov)
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            local headPos, headAng = ply:GetBonePosition(headBone)
            if headPos then
                pos = headPos + (ply:EyePos() - ply:GetPos()) / 12

                pos = OverdoneServers.EaseFunctions:EaseInSine(100*RealFrameTime(), lastHeadPos, pos)
                lastHeadPos = pos
            end
        end

        return {origin = pos, angles = angles, fov = fov}
    end)

    StatefulHooks:Add("CalcViewModelView", module.HookPrefix .. "AccurateHeadPos", function(wep, viewModel, oldEyePos, oldEyeAng, eyePos, eyeAng)
        return lastHeadPos
    end)
end

module:HookAdd("OverdoneServers:PlayerReady", "InitHooks", function(ply)
    InitHooks()
end)

-- InitHooks() -- Remove this


-- StatefulHooks:Remove("CalcView", module.HookPrefix .. "LeanView")
-- StatefulHooks:Remove("CalcView", module.HookPrefix .. "AccurateHeadPos")
-- StatefulHooks:Remove("CalcViewModelView", module.HookPrefix .. "AccurateHeadPos")

-- local screenHalfWidth = ScrW() / 2
-- local screenHalfHeight = ScrH() / 2
-- local crosshairSize = 6

-- local lastCrosshairPos = {x = screenHalfWidth, y = screenHalfHeight}

-- module:HookAdd("HUDPaint", "Crosshair", function()
--     local lastView = StatefulHooks.AllHooks["CalcView"].Result
--     local lastViewPos = lastView.origin
--     local lastViewAngles = lastView.angles

--     -- Get the position where the player is looking at
--     local trace = util.GetPlayerTrace(LocalPlayer(), lastViewAngles:Forward())
--     local traceRes = util.TraceLine(trace)
--     local hitPos = traceRes.HitPos

--     -- Convert the hit position to screen coordinates
--     local screenPos = hitPos:ToScreen()
--     local x = screenPos.x
--     local y = screenPos.y

--     -- Ease the crosshair movement
--     x = OverdoneServers.EaseFunctions:EaseInSine(70*RealFrameTime(), lastCrosshairPos.x, x)
--     y = OverdoneServers.EaseFunctions:EaseInSine(70*RealFrameTime(), lastCrosshairPos.y, y)

--     lastCrosshairPos.x = x
--     lastCrosshairPos.y = y

--     surface.SetDrawColor(255, 255, 255, 200)
--     surface.DrawRect(x - crosshairSize / 2, y - crosshairSize / 2, crosshairSize, crosshairSize)
-- end)

local justFired = false

module:HookAdd("EntityFireBullets", "AccurateHeadPos", function(ply, data)
    if (justFired) then return end
    justFired = true
    data.Src = StatefulHooks.AllHooks["CalcView"].Result.origin
    ply:FireBullets(data)
    justFired = false
    return false
end)