local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("Anti-AFK: Prevenindo desconexão!")
end)

local githubUrl = "https://raw.githubusercontent.com/pigsouza/AutoCatch/bot-dsc/"

getgenv().AutoCatchConfig = getgenv().AutoCatchConfig or {
    AutoCatch = false,
    SecretLuckyBlockOnly = false,
    TargetRarities = {
        Common = false, Rare = false, Epic = false,
        Legendary = false, Mythical = false, Secret = false,
        Boss = false, Divine = false
    },
    Blink = {
        Islands = {
            Cave = false,
            Safari = false
        },
        TargetRarities = {
            Common = false, Rare = false, Epic = false,
            Legendary = false, Mythical = false, Secret = false,
            Boss = false, Divine = false
        }
    }
}

loadstring(game:HttpGet(githubUrl .. "farm.lua"))()
loadstring(game:HttpGet(githubUrl .. "ui.lua"))()

print("O script foi carregado com sucesso (Anti-AFK ativado).")
