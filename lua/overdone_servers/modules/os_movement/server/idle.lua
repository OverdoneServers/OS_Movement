local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

module:HookAdd("PlayerButtonDown", "PlayerIdleCancel", function(ply, button)
    -- print(ply:Nick() .. " pressed " .. button)
end)

-- animate player head to look around like they are idle