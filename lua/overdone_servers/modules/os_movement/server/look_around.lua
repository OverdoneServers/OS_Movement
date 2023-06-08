local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

module:AddNetworkString("LookAround:Status")

local playerLookAroundAngles = {} -- If player exists in this table, they are currently using the look around feature.

module:NetReceive("LookAround:Status", function(_, ply)
    if net.ReadBool() then
        playerLookAroundAngles[ply] = true
    else
        playerLookAroundAngles[ply] = nil
    end
end)

module:HookAdd("SetupMove", "LookAround:ApplyMovement", function(ply, mv, cmd)
    if playerLookAroundAngles[ply] == true then -- if true we need to save their base move angles
        playerLookAroundAngles[ply] = mv:GetMoveAngles()
    end

    if isangle(playerLookAroundAngles[ply]) then -- if an angle we need to apply their base move angles
        mv:SetMoveAngles(playerLookAroundAngles[ply])
    end
end)

module:HookAdd("FinishMove", "LookAround:FixJump", function(ply, mv)

end)