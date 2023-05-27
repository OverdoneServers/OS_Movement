local module = OverdoneServers:GetModule("os_movement")
local OSMove = module.Data

-- Configurable variables
OSMove.leanTime = 0.7 -- How long it takes to lean in seconds
OSMove.leanAngle = 13 -- How far to lean in degrees

OSMove.LeanEnum = {
    NONE = 0,
    LEFT = -1,
    RIGHT = 1
}

-- Define the bones you want to manipulate
OSMove.LeanBones = {
    ["ValveBiped.Bip01_Head1"]   = {angleMultiplier = Angle(1, 0, 0), posMultiplier = Vector(0, 0, 0.05)},
    ["ValveBiped.Bip01_Spine"]   = {angleMultiplier = Angle(3, 0, 0), posMultiplier = Vector(-0.4, 0, 0)},
}

local function AngleOffset(new, old)
	local _, ang = WorldToLocal(vector_origin, new, vector_origin, old)
	return ang
end

function OSMove:ManipulateBones(ply, pos, rollAngle)
    for boneName, modifiers in pairs(OSMove.LeanBones) do
        local bone = ply:LookupBone(boneName)
        if bone then
            local boneMatrix = ply:GetBoneMatrix(bone)
            local curAngle = boneMatrix:GetAngles()
            local wantedAngle = boneMatrix:GetAngles()
            wantedAngle:RotateAroundAxis(ply:EyeAngles():Forward(), rollAngle * modifiers.angleMultiplier.p)
            ply:ManipulateBoneAngles(bone, AngleOffset(wantedAngle, curAngle), false)
        end
    end


    -- apply pos for camera offset
    pos.x = pos.x + ply:EyeAngles():Right().x * rollAngle * 1.3
    pos.z = pos.z + ply:EyeAngles():Right().z * rollAngle * 0.7

    return pos
end