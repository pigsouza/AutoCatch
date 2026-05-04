local githubUrl = "https://raw.githubusercontent.com/pigsouza/AutoCatch/main/"

-- Cria uma tabela global para os dois scripts se comunicarem
getgenv().AutoCatchConfig = {
    AutoCatch = false,
    TargetRarities = {
        Common = false, Rare = false, Epic = false,
        Legendary = false, Mythical = false, Secret = false,
        Boss = false, Divine = false
    }
}

-- Baixa e executa os módulos
loadstring(game:HttpGet(githubUrl .. "src/farm.lua"))()
loadstring(game:HttpGet(githubUrl .. "src/ui.lua"))()

print("⚡ Scripts carregados com sucesso!")
