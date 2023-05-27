local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local leanCoroutines = {}

-- Network string for lean state
module:AddNetworkString("PlayerLeanState")

-- Receive lean state on server
module:NetReceive("PlayerLeanState", function(len, ply)
    local state = net.ReadInt(2)
    if (state == ply:GetNWInt("LeanState")) then
        return
    end
    ply:SetNWInt("LeanState", state) -- store lean state on player entity
    ply.UpdateLeanState = true -- The server needs to update the lean state
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
    EyePoses[ply] = self:ManipulateBones(ply, pos, targetAngle)
    ply.UpdateLeanState = false
end

-- Apply lean on server
module:HookAdd("PlayerTick", "ServerLean", function(ply, mv)
    if not ply.UpdateLeanState then return end
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
    if (JustFired[ply] or EyePoses[ply] == nil) then return end
    JustFired[ply] = true
    data.Src = EyePoses[ply]
    ply:FireBullets(data)
    JustFired[ply] = false
    return false
end)