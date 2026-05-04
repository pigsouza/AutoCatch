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

print("O script foi carregado.")
