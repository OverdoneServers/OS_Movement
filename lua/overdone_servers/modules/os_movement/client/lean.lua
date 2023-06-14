local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local StatefulHooks = OverdoneServers:GetLibrary("stateful_hooks")
local Easing = OverdoneServers:GetLibrary("easing")

StatefulHooks:AddState("Aiming")
StatefulHooks:AddState("Walking")
StatefulHooks:EnableState("Walking")

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
            rollAngle = Lerp(math.ease.InOutSine(t), OSMove.startLeanRollAngle, wantedLean)
        else
            rollAngle = wantedLean
            UpdateLeanState = false
        end
    
        angles.roll = rollAngle

        OSMove.lastLeanAngle = angles.roll
        OSMove:ManipulateBones(ply, pos, OSMove.lastLeanAngle)

        ply:SetupBones()

        return {origin = pos, angles = angles}
    end, "Walking")

    local lastHeadPos = LocalPlayer():EyePos()
    local lastEyeAng = Angle()
    local lastArmPos = LocalPlayer():EyePos()
    local hasUpdatedThisFrame = false

    StatefulHooks:Add("CalcView", module.HookPrefix .. "AccurateHeadPos", function(ply, pos, angles, fov)
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            local headPos, headAng = ply:GetBonePosition(headBone)
            if headPos then
                pos = headPos + (ply:EyePos() - ply:GetPos()) / 12
                pos = Lerp(20*RealFrameTime(), lastHeadPos, pos)
                lastHeadPos = pos
            end
        end

        hasUpdatedThisFrame = true
        return {origin = pos, angles = angles}
    end, {"Walking"})

    local lagAmount = 16 -- Change this to control the amount of lag
    
    local function NormalizeAngleDifference(angle1, angle2)
        local difference = angle1 - angle2
        if difference < -180 then
            difference = difference + 360
        elseif difference > 180 then
            difference = difference - 360
        end
        return difference
    end

    local function ClampMagnitude(vector, maxLength)
        local sqrMagnitude = vector:LengthSqr()
        if sqrMagnitude > maxLength * maxLength then
            local mag = math.sqrt(sqrMagnitude)
            vector.x = vector.x / mag * maxLength
            vector.y = vector.y / mag * maxLength
            vector.z = vector.z / mag * maxLength
        end
        return vector
    end
    
    local armVelocity = Vector(0,0,0)

    local lastEyePos = LocalPlayer():EyePos()
    StatefulHooks:Add("CalcViewModelView", module.HookPrefix .. "AccurateHeadPos", function(wep, viewModel, oldEyePos, oldEyeAng, eyePos, eyeAng)
        if not hasUpdatedThisFrame then
            return nil
        end

        hasUpdatedThisFrame = false

        local wantedPos = StatefulHooks:GetResult("CalcView").origin
        local wantedAng = StatefulHooks:GetResult("CalcView").angles
    
        -- Normalize angle differences
        local normalizedPitch = NormalizeAngleDifference(wantedAng.p, lastEyeAng.p)
        local normalizedYaw = NormalizeAngleDifference(wantedAng.y, lastEyeAng.y)
        local normalizedRoll = NormalizeAngleDifference(wantedAng.r, lastEyeAng.r)
    
        lastEyeAng.p = Lerp(RealFrameTime()*lagAmount, lastEyeAng.p, lastEyeAng.p + normalizedPitch)
        lastEyeAng.y = Lerp(RealFrameTime()*lagAmount, lastEyeAng.y, lastEyeAng.y + normalizedYaw)
        lastEyeAng.r = Lerp(RealFrameTime()*lagAmount, lastEyeAng.r, lastEyeAng.r + normalizedRoll)
        
        -- move the wantedPos forward
        wantedPos = wantedPos + lastEyeAng:Forward() * 4
        wantedPos = wantedPos + lastEyeAng:Right() * -1

        lastArmPos, armVelocity = Easing:SmoothDamp(lastArmPos, wantedPos, armVelocity, 0.015, math.huge, RealFrameTime())
        
        return lastArmPos, lastEyeAng
    end, "Walking")

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
--     local lastView = StatefulHooks:GetResult("CalcView")
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
    data.Src = StatefulHooks:GetResult("CalcView").origin
    ply:FireBullets(data)
    justFired = false
    return false
end)

module:HookAdd("PlayerButtonDown", "DetectAimingStart", function(ply, button)
    if button == MOUSE_RIGHT then
        StatefulHooks:DisableState("Walking")
    end
end)

module:HookAdd("PlayerButtonUp", "DetectAimingEnd", function(ply, button)
    if button == MOUSE_RIGHT then
        StatefulHooks:EnableState("Walking")
    end
end)