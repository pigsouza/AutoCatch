local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local githubUrl = "https://raw.githubusercontent.com/pigsouza/AutoCatch/bot-dsc/"

getgenv().AutoCatchConfig = getgenv().AutoCatchConfig or {
    AutoCatch = false,
    AutoEgg = false,          -- 👈 ADICIONADO
    SecretLuckyBlockOnly = false,
    TargetRarities = {
        Common = false, Rare = false, Epic = false,
        Legendary = false, Mythical = false, Secret = false,
        Boss = false, Divine = false
    },
    Blink = {
        Islands = { Cave = false, Safari = false },
        TargetRarities = {
            Common = false, Rare = false, Epic = false,
            Legendary = false, Mythical = false, Secret = false,
            Boss = false, Divine = false
        }
    }
}

loadstring(game:HttpGet(githubUrl .. "egg.lua"))()   -- 👈 ADICIONADO
loadstring(game:HttpGet(githubUrl .. "farm.lua"))()
loadstring(game:HttpGet(githubUrl .. "ui.lua"))()

print("Script carregado com sucesso.")
