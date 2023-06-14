local MODULE = {}

MODULE.DisplayName = "Movement"

MODULE.DataToLoad = {
    Server = {
        "lean.lua",
        "idle.lua",
        "look_around.lua"
    },
    Shared = {
        "lean.lua",
        "idle.lua",
    },
    Client = {
        "lean.lua",
        "idle.lua",
        "look_around.lua"
    }
}

return MODULE