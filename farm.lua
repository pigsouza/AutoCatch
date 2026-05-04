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

getgenv().StartFarm = function(NotificationUI)
    task.spawn(function()
        local petsSendoCapturados = {}

        while task.wait(0.5) do
            if not getgenv().AutoCatchConfig.AutoCatch then continue end
            
            local character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then continue end

            local petFolders = getPetFolders()
            
            for _, petContainer in pairs(petFolders) do
                if not getgenv().AutoCatchConfig.AutoCatch then break end
                
                for _, pet in pairs(petContainer:GetChildren()) do
                    if not getgenv().AutoCatchConfig.AutoCatch then break end
                    
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
                                    Title = "Pet Capturado!",
                                    Description = petName .. " [" .. rarity .. "]",
                                    Duration = 3,
                                    Icon = "rbxassetid://8997385628"
                                })
                            end
                            
                            task.wait(2.5) 
                            petsSendoCapturados[pet] = nil
                        end
                    end
                end
            end
        end
    end)
end
