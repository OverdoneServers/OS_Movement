local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local maxLook = 140 -- Maximum degree to look left/right
local edgeSensitivityMultiplier = 0.3 -- Sensitivity reduction at the screen's edge
local resetDuration = 0.3 -- Duration of the reset animation in seconds

local sensitivityYaw = GetConVar("m_yaw"):GetFloat() -- TODO: Make this update automatically when the convar changes
local sensitivityPitch = GetConVar("m_pitch"):GetFloat()

local lookAroundActive = false
local initialAngles = nil
local currentYaw = 0
local lookAroundAngles = nil
local resetStartTime = nil

module:HookAdd("Think", "LookAround:SendAltStatus", function()
    local isAiming = input.IsMouseDown(MOUSE_RIGHT)
    local isLookBindPressed = input.IsKeyDown(KEY_LALT)

    if isAiming then
        module:NetStart("LookAround:Status")
        net.WriteBool(false)
        net.SendToServer()
        lookAroundActive = false
        initialAngles = nil
    elseif isLookBindPressed and not lookAroundActive then
        module:NetStart("LookAround:Status")
        net.WriteBool(true)
        net.SendToServer()
        lookAroundActive = true
        lookAroundAngles = nil
        resetStartTime = nil
        currentYaw = 0
    elseif lookAroundActive and not isLookBindPressed then
        module:NetStart("LookAround:Status")
        net.WriteBool(false)
        net.SendToServer()
        lookAroundActive = false
    end
end)

local function mathSign(x) -- TODO: Move to maffs
    return x > 0 and 1 or x < 0 and -1 or 0
end

module:HookAdd("CreateMove", "LookAround:OverTheShoulderView", function(cmd)
    if lookAroundActive then
        cmd:RemoveKey(IN_WALK) -- This is a bit hacky, but it works for now. (Not requried but makes LookAround more usable)

        if not isangle(initialAngles) then
            initialAngles = cmd:GetViewAngles()
            currentYaw = 0 -- Reset yaw when we start looking around
        end

        local mouseLookX = cmd:GetMouseX() * sensitivityYaw

        -- Calculate if we are moving towards the edge or away from it.
        local moveDirection = mathSign(mouseLookX) == mathSign(currentYaw) and 1 or 0

        -- Adjust mouseLookX based on how far we are from the center. When yaw is 0, sensitivity is unchanged. When yaw is at maxLook, sensitivity is reduced to edgeSensitivityMultiplier%.
        mouseLookX = mouseLookX * Lerp(moveDirection * math.abs(currentYaw) / maxLook, 1, edgeSensitivityMultiplier)

        currentYaw = math.Clamp(currentYaw + mouseLookX, -maxLook, maxLook)

        -- Calculate the difference between the initial angles and the current angles, then apply the yaw and pitch changes to the, now, wanted angles.
        local anglesOffset = initialAngles - cmd:GetViewAngles()
        anglesOffset.yaw = currentYaw
        -- anglesOffset.pitch = math.NormalizeAngle(anglesOffset.pitch - cmd:GetMouseY() * sensitivityPitch)
        -- anglesOffset.pitch = math.Clamp(anglesOffset.pitch, -89.9, 89.9) -- This is not 90 because angle math is super awesome and allows you to look behind you if you go over +-90 degrees.

        -- Calculate the angles we want to set the view to
        lookAroundAngles = initialAngles - anglesOffset

        cmd:SetViewAngles(lookAroundAngles)
    else
        if isangle(initialAngles) then
            -- If this is the first frame after lookAroundActive has become false, record the current time
            if resetStartTime == nil then
                resetStartTime = CurTime()
            end

            -- Update the initialAngles with the current mouse movements
            local mouseDelta = Angle(cmd:GetMouseY() * sensitivityPitch, -cmd:GetMouseX() * sensitivityYaw, 0)
            initialAngles = initialAngles + mouseDelta

            -- Calculate the amount of time that has passed since we started the reset
            local timeElapsed = CurTime() - resetStartTime

            -- If we're still in the reset duration, calculate the interpolated angles
            if timeElapsed <= resetDuration then
                local lerpFraction = timeElapsed / resetDuration
                local interpolatedAngles = LerpAngle(math.ease.OutQuart(lerpFraction), lookAroundAngles, initialAngles)
                cmd:SetViewAngles(interpolatedAngles)
            else
                -- After the reset duration, set the angles directly and clear initialAngles
                -- cmd:SetViewAngles(initialAngles)
                initialAngles = nil
                resetStartTime = nil
            end
        end

    end
end)

