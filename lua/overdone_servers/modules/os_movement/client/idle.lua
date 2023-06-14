local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local StatefulHooks = OverdoneServers:GetLibrary("stateful_hooks")

StatefulHooks:AddState("Idle")

local lastActiveTime = CurTime()

local function PlayerMoved(ply)
    if (IsFirstTimePredicted()) then -- Required because gmod
        lastActiveTime = CurTime()
        StatefulHooks:DisableState("Idle")
    end
end

module:HookAdd("PlayerButtonDown", "PlayerIdleCancel", PlayerMoved)
module:HookAdd("PlayerButtonUp", "PlayerIdleCancel", PlayerMoved)

local idleTimeBeforeAnimation = 30 -- Time before the animation starts (also delay between animations)
local lookAroundMaxAngle = 120 -- Maximum angle to look away from the original angle
local maxDownAngle = 10 -- Maximum angle to look down
local maxUpAngle = 15 -- Maximum angle to look up

local ponderAmount = 3 -- (multiplyer - INT ONLY) How much to stay in one spot until moving again
local ponderChance = 0.2 -- (0-1) Chance to ponder

local numAngles = 8 -- Number of angles to generate
local animationLength = 60 -- Duration of the entire animation

local segmentDuration -- Duration of each animation segment
local lastAnimationEndTime = CurTime()
local currentAngleIndex = 1 -- Index of the current angle we are animating towards
local angles = {} -- Stores angles to interpolate between

module:HookAdd("Tick", "TestIfIdle", function()
    if (lastActiveTime + idleTimeBeforeAnimation < CurTime()) then
        StatefulHooks:EnableState("Idle")
    end
end)

local function interpolateAngles(t, p0, p1, p2, p3)
    -- Catmull-Rom spline interpolation
    local t2 = t * t
    local t3 = t2 * t
    local factor1 = -0.5 * t3 + t2 - 0.5 * t
    local factor2 = 1.5 * t3 - 2.5 * t2 + 1.0
    local factor3 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
    local factor4 = 0.5 * t3 - 0.5 * t2
    local result = p0 * factor1 + p1 * factor2 + p2 * factor3 + p3 * factor4
    return result
end

function AddNoiseToAngle(x, y, noiseFactor, initialAng)
    local noiseX = math.Clamp(x + (math.random() * (noiseFactor * 2) - noiseFactor), -maxDownAngle, maxUpAngle) -- up and down
    local noiseY = math.Clamp(y + (math.random() * (noiseFactor * 2) - noiseFactor), initialAng.yaw - lookAroundMaxAngle, initialAng.yaw + lookAroundMaxAngle) -- left and right
    return noiseX, noiseY
end

StatefulHooks:Add("CalcView", "PlayerIdle", function(ply, pos, angle, fov)
    local currentTime = CurTime()
    segmentDuration = animationLength / #angles

    -- Check if enough idle time has passed and the last animation has finished
    if currentTime - lastAnimationEndTime > idleTimeBeforeAnimation then
        lastAnimationEndTime = currentTime + animationLength
        currentAngleIndex = 1 -- Reset index
        angles = {} -- Reset angles
        table.insert(angles, angle)
        for i = 1, numAngles do
            local lastAngle = angles[#angles]
            local noiseFactor = 120
            local noiseX, noiseY = AddNoiseToAngle(lastAngle.pitch, lastAngle.yaw, noiseFactor, angle)
            local newAngle = Angle(noiseX, noiseY, lastAngle.roll)
            table.insert(angles, newAngle)
            if math.random() < ponderChance then
                for i = 1, ponderAmount do
                    noiseX, noiseY = AddNoiseToAngle(noiseX, noiseY, noiseFactor/50, newAngle)
                    table.insert(angles, Angle(noiseX, noiseY, lastAngle.roll))
                end
            end
            -- table.insert(angles, Angle(math.random(-lookAroundMaxAngle, lookAroundMaxAngle) + angle.pitch, math.random(-lookAroundMaxAngle, lookAroundMaxAngle) + angle.yaw, angle.roll)) -- Preserve the original roll
        end
        table.insert(angles, angle)
    end

    -- If in the middle of the animation
    if currentTime < lastAnimationEndTime then
        local timeIntoAnimation = currentTime - (lastAnimationEndTime - animationLength)
        local segmentIndex = math.ceil(timeIntoAnimation / segmentDuration)

        if segmentIndex ~= currentAngleIndex then
            currentAngleIndex = segmentIndex
        end

        local p0 = angles[math.max(currentAngleIndex - 1, 1)]
        local p1 = angles[currentAngleIndex]
        local p2 = angles[currentAngleIndex + 1]
        local p3 = angles[math.min(currentAngleIndex + 2, #angles)]

        -- If in the middle of the segment
        if p0 and p1 and p2 and p3 then
            local t = (timeIntoAnimation - (segmentDuration * (currentAngleIndex - 1))) / segmentDuration
            local arcFactor = interpolateAngles(t, p0, p1, p2, p3)
            angle = arcFactor
            return { angles = angle }
        end
    end

    return nil -- Return nil if no angle is being applied
end, "Idle")