local NothingLibrary = loadstring(game:HttpGetAsync('https://raw.githubusercontent.com/3345-c-a-t-s-u-s/NOTHING/main/source.lua'))()
local Notification = NothingLibrary.Notification()

local Windows = NothingLibrary.new({
    Title = "zyt hub",
    Description = "Auto Catch Otimizado",
    Keybind = Enum.KeyCode.RightControl,
    Logo = "rbxthumb://type=Asset&id=125361711744319&w=150&h=150"
})

local TabFrame = Windows:NewTab({
    Title = "Auto Farm",
    Description = "Selecione",
    Icon = "rbxassetid://7733960981"
})

local MainSection = TabFrame:NewSection({ Title = "Controle Principal", Icon = "rbxassetid://7743869054", Position = "Left" })
local RaritySection = TabFrame:NewSection({ Title = "Filtro de Raridades", Icon = "rbxassetid://7733964719", Position = "Right" })

MainSection:NewToggle({
    Title = "Ativar Auto Catch",
    Default = false,
    Callback = function(state)
        getgenv().AutoCatchConfig.AutoCatch = state
        if state then
            Notification.new({
                Title = "Farm Iniciado",
                Description = "Buscando pets selecionados...",
                Duration = 3,
                Icon = "rbxassetid://8997385628"
            })
        end
    end,
})

local raritiesToCreate = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Boss", "Divine"}

for _, rarity in ipairs(raritiesToCreate) do
    RaritySection:NewToggle({
        Title = "Capturar " .. rarity,
        Default = false,
        Callback = function(state)
            getgenv().AutoCatchConfig.TargetRarities[rarity] = state
        end,
    })
end

if getgenv().StartFarm then
    getgenv().StartFarm(Notification)
end
