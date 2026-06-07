local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimFeepEgg = Remotes:WaitForChild("ClaimFeepEgg")
local FeepEggSpawn = Remotes:WaitForChild("FeepEggSpawn")

-- Config global para o egg
getgenv().AutoCatchConfig = getgenv().AutoCatchConfig or {}
getgenv().AutoCatchConfig.AutoEgg = getgenv().AutoCatchConfig.AutoEgg or false

-- Função para buscar o ovo nos nil instances
local function GetNilByName(Name)
    for _, Object in getnilinstances() do
        if Object.Name == Name then
            return Object
        end
    end
    return nil
end

-- Tenta pegar o ovo com retries
local function TryClaimEgg(eggName, NotificationUI)
    task.wait(0.3) -- pequeno delay para o ovo "existir"
    
    local egg = GetNilByName(eggName)
    
    if not egg then
        -- Segunda tentativa com GetDebugId não necessário,
        -- pois só existe 1 ovo com esse nome por vez
        task.wait(0.5)
        egg = GetNilByName(eggName)
    end
    
    if egg then
        local success, err = pcall(function()
            ClaimFeepEgg:FireServer(egg)
        end)
        
        if success then
            if NotificationUI and getgenv().AutoCatchConfig.AutoEgg then
                NotificationUI.new({
                    Title = "🥚 Ovo Coletado!",
                    Description = "Pegou: " .. eggName,
                    Duration = 4,
                    Icon = "rbxassetid://8997385628"
                })
            end
            print("[AutoEgg] Coletado:", eggName)
        else
            print("[AutoEgg] Erro ao coletar:", err)
        end
    else
        print("[AutoEgg] Ovo não encontrado nos nil instances:", eggName)
    end
end

-- Listener do evento do servidor
getgenv().EggConnection = getgenv().EggConnection

local function StartEggListener(NotificationUI)
    -- Remove conexão antiga se existir
    if getgenv().EggConnection then
        getgenv().EggConnection:Disconnect()
        getgenv().EggConnection = nil
    end
    
    getgenv().EggConnection = FeepEggSpawn.OnClientEvent:Connect(function(position, eggName)
        -- Verifica se o auto egg está ativo
        if not getgenv().AutoCatchConfig.AutoEgg then return end
        
        print("[AutoEgg] Ovo detectado:", eggName, "| Posição:", tostring(position))
        
        -- Tenta coletar instantaneamente
        TryClaimEgg(eggName, NotificationUI)
    end)
    
    print("[AutoEgg] Listener ativo.")
end

getgenv().StartEggListener = StartEggListener
