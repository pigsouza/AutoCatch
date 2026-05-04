local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local minigameRequest = Remotes:WaitForChild("minigameRequest")
local retrieveData = Remotes:WaitForChild("retrieveData")
local updateProgress = Remotes:WaitForChild("UpdateProgress")

local function getPetFolders()
    local folders = {}
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name:match("Pets$") and obj:FindFirstChild("Pets") then
            table.insert(folders, obj.Pets)
        end
    end
    return folders
end

local IslandData = {
    Cave = {Nome = "CaveIslandPets", Pos = Vector3.new(-4595, -505, -1592)},
    Safari = {Nome = "SafariIslandPets", Pos = Vector3.new(-2496, 83, -2695)}
}

getgenv().StartFarm = function(NotificationUI)
    
    task.spawn(function()
        local petsSendoCapturados = {}
        while task.wait(0.5) do
            if not getgenv().AutoCatchConfig.AutoCatch then continue end
            
            if getgenv().IsBlinking then continue end 
            
            local character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then continue end

            local petFolders = getPetFolders()
            
            for _, petContainer in pairs(petFolders) do
                if not getgenv().AutoCatchConfig.AutoCatch or getgenv().IsBlinking then break end
                
                for _, pet in pairs(petContainer:GetChildren()) do
                    if not getgenv().AutoCatchConfig.AutoCatch or getgenv().IsBlinking then break end
                    if petsSendoCapturados[pet] then continue end
                    
                    if pet:IsA("Model") and pet.PrimaryPart then
                        local rarity = pet:GetAttribute("Rarity")
                        local petName = pet:GetAttribute("Name") or pet.Name
                        
                        local deveCapturar = false
                        
                        if getgenv().AutoCatchConfig.SecretLuckyBlockOnly then
                            if petName == "Secret Lucky Block" and rarity == "Secret" then
                                deveCapturar = true
                            end
                        else
                            if rarity and getgenv().AutoCatchConfig.TargetRarities[rarity] then
                                deveCapturar = true
                            end
                        end
                        
                        if deveCapturar then
                            petsSendoCapturados[pet] = true 
                            local myCFrame = character.HumanoidRootPart.CFrame
                            
                            local tentativas = 0
                            local ok = minigameRequest:InvokeServer(pet, myCFrame)
                            
                            while not ok and tentativas < 40 do
                                if not getgenv().AutoCatchConfig.AutoCatch then break end
                                task.wait(0.1)
                                tentativas = tentativas + 1
                                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                                    myCFrame = player.Character.HumanoidRootPart.CFrame
                                end
                                ok = minigameRequest:InvokeServer(pet, myCFrame)
                            end

                            if not ok then 
                                petsSendoCapturados[pet] = nil
                                continue 
                            end

                            retrieveData:InvokeServer()
                            task.wait(0.1)

                            local total = 0
                            for i = 1, 100 do
                                if not getgenv().AutoCatchConfig.AutoCatch then break end
                                total = math.min(100, total + (i + math.random()))
                                updateProgress:FireServer(math.min(100, total))
                                if total == 100 then break end
                                task.wait()
                            end

                            if NotificationUI and getgenv().AutoCatchConfig.AutoCatch then
                                NotificationUI.new({
                                    Title = "Pet Local Capturado!",
                                    Description = petName .. " [" .. rarity .. "]",
                                    Duration = 3,
                                    Icon = "rbxassetid://8997385628"
                                })
                            end
                            
                            task.wait(1.5) 
                            petsSendoCapturados[pet] = nil
                        end
                    end
                end
            end
        end
    end)

    task.spawn(function()
        local cam = workspace.CurrentCamera
        
        while task.wait(1) do
            local configBlink = getgenv().AutoCatchConfig.Blink
            if not configBlink then continue end
            
            local temIlha = configBlink.Islands.Cave or configBlink.Islands.Safari
            local temRaridade = false
            for _, state in pairs(configBlink.TargetRarities) do
                if state then temRaridade = true break end
            end
            
            if temIlha and temRaridade then
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
                
                local hrp = char.HumanoidRootPart
                local posicaoOriginal = hrp.CFrame
                
                getgenv().IsBlinking = true 
                
                local camPart = Instance.new("Part", workspace)
                camPart.Transparency = 1
                camPart.Anchored = true
                camPart.CFrame = cam.CFrame
                cam.CameraSubject = camPart
                if char:FindFirstChild("Animate") then char.Animate.Disabled = true end
                
                local ilhasAtivas = {}
                if configBlink.Islands.Cave then table.insert(ilhasAtivas, IslandData.Cave) end
                if configBlink.Islands.Safari then table.insert(ilhasAtivas, IslandData.Safari) end
                
                for _, ilhaAtual in ipairs(ilhasAtivas) do
                    hrp.CFrame = CFrame.new(ilhaAtual.Pos)
                    task.wait(0.3) 
                    
                    local pastaIlha = workspace:FindFirstChild(ilhaAtual.Nome)
                    if pastaIlha and pastaIlha:FindFirstChild("Pets") then
                        for _, pet in pairs(pastaIlha.Pets:GetChildren()) do
                            if pet:IsA("Model") and pet.PrimaryPart then
                                local rarity = pet:GetAttribute("Rarity") or "Desconhecido"
                                
                                if configBlink.TargetRarities[rarity] then
                                    local petName = pet:GetAttribute("Name") or pet.Name
                                    local ok = minigameRequest:InvokeServer(pet, hrp.CFrame)
                                    
                                    if ok then
                                        retrieveData:InvokeServer()
                                        local total = 0
                                        for j = 1, 100 do
                                            total = math.min(100, total + (j + math.random()))
                                            updateProgress:FireServer(math.min(100, total))
                                            if total == 100 then break end
                                            task.wait()
                                        end
                                        
                                        if NotificationUI then
                                            NotificationUI.new({
                                                Title = "Blink Ativado!",
                                                Description = petName .. " [" .. rarity .. "]\nIlha: " .. ilhaAtual.Nome,
                                                Duration = 3,
                                                Icon = "rbxassetid://10261314948" 
                                            })
                                        end
                                        task.wait(1.5) 
                                    end
                                end
                            end
                        end
                    end
                end
                
                hrp.CFrame = posicaoOriginal
                task.wait(0.1)
                
                if char:FindFirstChild("Humanoid") then cam.CameraSubject = char.Humanoid end
                camPart:Destroy()
                if char:FindFirstChild("Animate") then char.Animate.Disabled = false end
                
                getgenv().IsBlinking = false 
            end
        end
    end)
end
