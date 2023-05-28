local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local leanCoroutines = {}
local PlayerIsLeaning = {}

-- Network string for lean state
module:AddNetworkString("PlayerLeanState")

-- Receive lean state on server
module:NetReceive("PlayerLeanState", function(len, ply)
    local state = net.ReadInt(2)
    if (state == ply:GetNWInt("LeanState")) then
        return
    end
    ply:SetNWInt("LeanState", state) -- store lean state on player entity
    PlayerIsLeaning[ply] = true -- The server needs to update the lean state
end)

local EyePoses = {} -- Store the eye positions of players

function OSMove:AnimateLean(ply, pos, targetAngle)
    local startAngle = ply:GetNWFloat("LeanAngle")
    local startTime = CurTime()
    
    while CurTime() < startTime + OSMove.leanTime do -- Math is the smallest bit different from the client version
        local t = (CurTime() - startTime) / OSMove.leanTime
        local currentAngle = Lerp(t, startAngle, targetAngle)
        
        EyePoses[ply] = self:ManipulateBones(ply, pos, currentAngle)
        
        coroutine.yield()
    end
    -- Ensure the final angle is set correctly
    if (ply:GetNWInt("LeanState") == OSMove.LeanEnum.NONE) then
        self:ManipulateBones(ply, pos, 0)
        EyePoses[ply] = nil
    else
        EyePoses[ply] = self:ManipulateBones(ply, pos, targetAngle)
    end
    PlayerIsLeaning[ply] = nil
end

-- Apply lean on server
module:HookAdd("PlayerTick", "ServerLean", function(ply, mv)
    if not PlayerIsLeaning[ply] then return end
    local state = ply:GetNWInt("LeanState")
    local leanAngle = OSMove.leanAngle * state
    local pos = ply:EyePos()
    
    -- Check if there's an existing coroutine for this player
    if leanCoroutines[ply] then
        -- If the lean state has changed, stop the existing coroutine and start a new one
        if state != leanCoroutines[ply].state then
            leanCoroutines[ply].coroutine = nil
            leanCoroutines[ply] = {
                state = state,
                coroutine = coroutine.create(function()
                    OSMove:AnimateLean(ply, pos, leanAngle)
                end)
            }
        -- If the coroutine has completed, remove it
        elseif coroutine.status(leanCoroutines[ply].coroutine) == "dead" then
            leanCoroutines[ply] = nil
        else
            -- Otherwise, resume the existing coroutine
            coroutine.resume(leanCoroutines[ply].coroutine)
        end
    else
        -- If there's no existing coroutine for this player, start a new one
        leanCoroutines[ply] = {
            state = state,
            coroutine = coroutine.create(function()
                OSMove:AnimateLean(ply, pos, leanAngle)
            end)
        }
        coroutine.resume(leanCoroutines[ply].coroutine)
    end
end)

local JustFired = {}
module:HookAdd("EntityFireBullets", "AccurateHeadPos", function(ply, data)
    local temp = ""
    if (JustFired[ply]) then temp = "true" else temp = "false" end

    if (EyePoses[ply] == nil) then return nil end
    PrintMessage(HUD_PRINTTALK, "Overriding bullet position for " .. ply:Nick() .. " " .. temp)
    if (JustFired[ply]) then return false end
    JustFired[ply] = true
    data.Src = EyePoses[ply]
    ply:FireBullets(data)
    JustFired[ply] = nil
    return true
end)


local timeToRandomSize = 0
local scaleOffset = 1
local targetScale = scaleOffset -- start with target scale equal to current scale
local transitionStartTime = CurTime()

-- for all players, set their scale
-- module:HookAdd("PlayerTick", "SetScale", function(ply, mv)
--     -- default mode
--     -- ply:SetModelScale(1)
--     -- ply:SetWalkSpeed(200)
--     -- ply:SetRunSpeed(300)
--     -- ply:SetJumpPower(200)
--     -- ply:SetViewOffset(Vector(0, 0, 64))
--     -- ply:SetViewOffsetDucked(Vector(0, 0, 28))
--     -- ply:SetStepSize(18)
--     -- ply:SetCrouchedWalkSpeed(0.3)
--     -- ply:SetDuckSpeed(0.3)
--     -- ply:SetUnDuckSpeed(0.3)
--     -- ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
--     -- ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36))
--     -- ply:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))

--     -- local timePassed = CurTime() - transitionStartTime

--     -- if timePassed >= timeToRandomSize then
--     --     transitionStartTime = CurTime()
--     --     timeToRandomSize = math.Rand(30, 60)
--     --     targetScale = math.Rand(0.2, 1.3) -- choose target scale randomly
--     --     PrintMessage(HUD_PRINTTALK, "New scale: " .. targetScale)
--     -- end

--     -- local progress = math.Clamp(timePassed / 10, 0, 1) -- transition over the course of 10 seconds
--     -- scaleOffset = Lerp(progress, scaleOffset, targetScale) -- interpolate towards target scale
--     scaleOffset = 0.33
--     ply:SetModelScale(scaleOffset)
--     ply:SetWalkSpeed(200 * scaleOffset)
--     ply:SetRunSpeed(300 * scaleOffset)
--     ply:SetJumpPower(200)
--     ply:SetViewOffset(Vector(0, 0, 32 * scaleOffset))
--     ply:SetViewOffsetDucked(Vector(0, 0, 16 * scaleOffset))
--     ply:SetStepSize(16 * scaleOffset)
--     ply:SetCrouchedWalkSpeed(0.5 * scaleOffset)
--     ply:SetDuckSpeed(0.5 * scaleOffset)
--     ply:SetUnDuckSpeed(0.5 * scaleOffset)
--     ply:SetHull(Vector(-16 * scaleOffset, -16 * scaleOffset, 0), Vector(16 * scaleOffset, 16 * scaleOffset, 32 * scaleOffset))
--     ply:SetHullDuck(Vector(-16 * scaleOffset, -16 * scaleOffset, 0), Vector(16 * scaleOffset, 16 * scaleOffset, 16 * scaleOffset))
--     ply:SetCollisionBounds(Vector(-16 * scaleOffset, -16 * scaleOffset, 0), Vector(16 * scaleOffset, 16 * scaleOffset, 32 * scaleOffset))
-- end)