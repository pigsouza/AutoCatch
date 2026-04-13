local Library = require("@self/library")
local SaveManager = require("@self/SaveManager")
local ThemeManager = require("@self/ThemeManager")

local window = Library:CreateWindow({
    Title = "Auto Catch - Ultra Optimized v4",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

-- ==========================================
-- SERVIÇOS E REMOTES
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local minigameRequest = Remotes:WaitForChild("minigameRequest")
local retrieveData = Remotes:WaitForChild("retrieveData")
local updateProgress = Remotes:WaitForChild("UpdateProgress")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Anti AFK
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- UI - ABAS
-- ==========================================
local tabMain = window:AddTab("Main")
local tabGroupLeft = tabMain:AddLeftGroupbox("Farm Principal")

tabGroupLeft:AddToggle("AutoCatchToggle", { Text = "Auto Catch", Default = false })
tabGroupLeft:AddToggle("OnlyColossalToggle", { Text = "Apenas Colossal", Default = false })
tabGroupLeft:AddToggle("LuckyBlockToggle", { Text = "Coletar Lucky Blocks", Default = false })

local tabGroupRight = tabMain:AddRightGroupbox("Pets Selection")
local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret", "Boss" }
local RaritiesPets = require("@self/pets")

for i, v in ipairs(rarities) do
    local pets = RaritiesPets[v]
    if not pets then continue end
    
    local cleanPets = {}
    for _, name in ipairs(pets) do 
        if not name:find("Lucky Block") then table.insert(cleanPets, name) end 
    end
    table.sort(cleanPets)

    local dropdown = tabGroupRight:AddDropdown(`Pets-{v}`, { 
        Values = cleanPets, 
        Default = 1, 
        Multi = true, 
        Text = v 
    })

    -- BOTÕES DE SELEÇÃO (RESTORED)
    tabGroupRight:AddButton({Text = "Select All", Func = function()
        local selected = {}
        for _, petName in ipairs(dropdown.Values) do selected[petName] = true end
        dropdown:SetValue(selected)
    end})

    tabGroupRight:AddButton({Text = "Unselect All", Func = function()
        dropdown:SetValue({})
    end})

    if i ~= #rarities then tabGroupRight:AddDivider() end
end

local tabMisc = window:AddTab("Misc")
local webhookGroup = tabMisc:AddLeftGroupbox("Discord Webhook")
webhookGroup:AddToggle("WebhookToggle", { Text = "Ativar Webhook", Default = false })
webhookGroup:AddInput("WebhookURL", { Default = "", Text = "URL do Webhook", Finished = true, Placeholder = "Cole o link aqui..." })

-- ==========================================
-- SISTEMA DE WEBHOOK
-- ==========================================
local options = getgenv().Options
local toggles = getgenv().Toggles

local function sendWebhook(petName, rarity, size, rps)
    if not toggles.WebhookToggle.Value then return end
    local url = options.WebhookURL.Value
    if url == "" or not url:find("discord.com") then return end

    task.spawn(function()
        local data = {
            embeds = {{
                title = "🐾 Pet Capturado!",
                description = string.format("A conta **%s** capturou um novo animal!", player.Name),
                color = 0x00FF00,
                fields = {
                    { name = "Animal", value = tostring(petName), inline = true },
                    { name = "Raridade", value = tostring(rarity), inline = true },
                    { name = "Tamanho", value = tostring(size), inline = true },
                    { name = "RPS", value = tostring(rps), inline = true }
                },
                footer = { text = "Auto Catch Event Mode" },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }

        pcall(function()
            request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

-- ==========================================
-- LÓGICA DE CAPTURA (EVENTO FOCADO)
-- ==========================================
local catching = false

local function CatchLoop()
    while toggles.AutoCatchToggle.Value do
        local locations = {
            workspace:FindFirstChild("NewEventIslandPets"), -- CAMINHO QUE VOCÊ PASSOU
            workspace:FindFirstChild("IceIslandPets"),
            workspace:FindFirstChild("RoamingPets"),
            workspace:FindFirstChild("SkyIslandPets"),
            workspace:FindFirstChild("WaterIslandPets"),
            workspace:FindFirstChild("BeeIslandPets")
        }

        for _, loc in ipairs(locations) do
            if not loc then continue end
            local folder = loc:FindFirstChild("Pets") or loc
            
            for _, pet in ipairs(folder:GetChildren()) do
                if not toggles.AutoCatchToggle.Value then break end
                
                -- Os atributos estão dentro do objeto com nome de UUID
                local petName = pet:GetAttribute("Name")
                local rarity = pet:GetAttribute("Rarity")
                
                if not petName or not rarity then continue end

                local size = pet:GetAttribute("Size") or "Normal"
                local rps = pet:GetAttribute("RPS") or pet:GetAttribute("Coins") or 0

                -- Filtro Colossal
                if toggles.OnlyColossalToggle.Value and size ~= "Colossal" then continue end

                -- Checar se está selecionado
                local isSelected = false
                local dropdown = options[`Pets-{rarity}`]
                
                if toggles.LuckyBlockToggle.Value and petName:lower():find("lucky block") then
                    isSelected = true
                elseif dropdown and dropdown.Value then
                    for name, enabled in pairs(dropdown.Value) do
                        if enabled and string.lower(name:gsub("%s","")) == string.lower(petName:gsub("%s","")) then
                            isSelected = true
                            break
                        end
                    end
                end

                if isSelected and pet:FindFirstChild("PrimaryPart") then
                    -- Usa a posição exata do pet para evitar erro de distância do servidor
                    local targetPos = pet.PrimaryPart.CFrame
                    
                    local success = minigameRequest:InvokeServer(pet, targetPos)
                    
                    if success then
                        retrieveData:InvokeServer()
                        -- Progresso rápido
                        for i = 1, 4 do
                            updateProgress:FireServer(i * 25)
                            task.wait()
                        end
                        
                        -- Dispara o Webhook
                        sendWebhook(petName, rarity, size, rps)
                        task.wait(0.2)
                    end
                end
            end
        end
        RunService.Heartbeat:Wait()
    end
    catching = false
end

toggles.AutoCatchToggle:OnChanged(function(v)
    if v and not catching then catching = true; task.spawn(CatchLoop) end
end)

-- ==========================================
-- CONFIGURAÇÕES FINAIS
-- ==========================================
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("AutoCatch")
SaveManager:SetFolder("AutoCatch/configs")
SaveManager:BuildConfigSection(window:AddTab("UI Settings"))
SaveManager:LoadAutoloadConfig()
