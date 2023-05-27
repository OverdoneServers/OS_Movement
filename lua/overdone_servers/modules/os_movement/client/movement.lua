local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

local leanOffset = 16

local isLeaning = false

function OSMove:GetShootPos(player)
    if not IsValid(player) then return 0 end
    local off = Vector(0, (isLeaning and 1 or 0) * -leanOffset, 0)
    off:Rotate(player:EyeAngles())

    return player:EyePos() + off
end

local lastTraceStart = Vector(0, 0, 0)
local lastTraceEnd = Vector(0, 0, 0)
local lastTraceHit = false

module:HookAdd("StartCommand", "Test", function(ply, ucmd)
    if not ply:Alive() then return end
    local shootPos = OSMove:GetShootPos(ply)
    local trace = util.TraceLine({
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * 1000,
        filter = ents.GetAll()
    })

    lastTraceHit = trace.Hit
    lastTraceStart = shootPos
    if trace.Hit then
        lastTraceEnd = trace.HitPos
    else
        lastTraceEnd = shootPos + ply:GetAimVector() * 1000
    end
end)

module:HookAdd("PostDrawTranslucentRenderables", "PreviewTrace", function()
    render.DrawLine(lastTraceStart, lastTraceEnd, lastTraceHit and Color(255, 0, 0) or Color(0, 8, 255), false) 
end )