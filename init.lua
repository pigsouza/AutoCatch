local githubUrl = "https://raw.githubusercontent.com/pigsouza/AutoCatch/main/"

getgenv().AutoCatchConfig = {
    AutoCatch = false,
    TargetRarities = {
        Common = false, Rare = false, Epic = false,
        Legendary = false, Mythical = false, Secret = false,
        Boss = false, Divine = false
    }
}

loadstring(game:HttpGet(githubUrl .. "bot-dsc/farm.lua"))()
loadstring(game:HttpGet(githubUrl .. "bot-dsc/ui.lua"))()

print("O script foi carregado.")
