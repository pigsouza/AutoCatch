local Library = require("@self/library")
local SaveManager = require("@self/SaveManager")
local ThemeManager = require("@self/ThemeManager")

local window = Library:CreateWindow({
	Title = "Auto Catch - Event Update",
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

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)

-- Anti AFK
player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- ABA MAIN (FARM)
-- ==========================================
local tabMain = window:AddTab("Main")
local tabGroupLeft = tabMain:AddLeftGroupbox("Configurações de Farm")

tabGroupLeft:AddToggle("AutoCatchToggle", {
	Text = "Auto Catch",
	Default = false,
	Tooltip = "Ativa a captura automática",
})

tabGroupLeft:AddToggle("OnlyColossalToggle", {
	Text = "Apenas Colossal",
	Default = false,
	Tooltip = "Ignora pets que não sejam Colossais",
})

tabGroupLeft:AddToggle("LuckyBlockToggle", {
	Text = "Coletar Lucky Blocks",
	Default = false,
})

tabGroupLeft:AddToggle("AutoBuyFoodToggle", {
	Text = "Auto Buy Food",
	Default = false,
})

-- ==========================================
-- SELEÇÃO DE PETS (RARIDADES)
-- ==========================================
local tabGroupRight = tabMain:AddRightGroupbox("Pets")
local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret", "Boss" }
local RaritiesPets = require("@self/pets")

for i, v in ipairs(rarities) do
	local pets = RaritiesPets[v]
	if not pets then continue end

	local cleanPets = {}
	for _, name in ipairs(pets) do
		if not name:find("Lucky Block") then table.insert(cleanPets, name) end
	end

	table.sort(cleanPets, function(a, b) return string.lower(tostring(a)) < string.lower(tostring(b)) end)

	local dropdown = tabGroupRight:AddDropdown(`Pets-{v}`, {
		Values = cleanPets,
		Default = 1,
		Multi = true,
		Text = v,
	})

	tabGroupRight:AddButton({Text = "Select All", Func = function()
		local selected = {}
		for _, petName in ipairs(dropdown.Values) do selected[petName] = true end
		dropdown:SetValue(selected)
	end})

	tabGroupRight:AddButton({Text = "Unselect All", Func = function() dropdown:SetValue({}) end})
	if i ~= #rarities then tabGroupRight:AddDivider() end
end

-- ==========================================
-- ABA MISC (WEBHOOK SEGURO)
-- ==========================================
local tabMisc = window:AddTab("Misc")
local webhookGroup = tabMisc:AddLeftGroupbox("Discord Webhook")

webhookGroup:AddToggle("WebhookToggle", {
	Text = "Ativar Webhook",
	Default = false,
})

webhookGroup:AddInput("WebhookURL", {
	Default = "", -- VAZIO POR SEGURANÇA. O usuário deve colar aqui.
	Text = "URL do Webhook",
	Finished = true,
	Placeholder = "Cole seu link do Discord aqui..."
})

-- ==========================================
-- LOGICA DE WEBHOOK
-- ==========================================
local options = getgenv().Options
local toggles = getgenv().Toggles

local function sendWebhook(petName, rarity, size, rps)
	if not toggles.WebhookToggle.Value then return end
	local url = options.WebhookURL.Value
	if url == "" or not url:find("discord.com") then return end

	local data = {
		embeds = {{
			title = "🐾 Pet Capturado!",
			description = string.format("A conta **%s** capturou um animal!", player.Name),
			color = 0x00FF00,
			fields = {
				{ name = "Animal", value = tostring(petName), inline = true },
				{ name = "Raridade", value = tostring(rarity), inline = true },
				{ name = "Tamanho", value = tostring(size), inline = true },
				{ name = "RPS", value = tostring(rps), inline = true },
			},
			timestamp = DateTime.now():ToIsoDate()
		}}
	}

	task.spawn(function()
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
-- LÓGICA DE CATCH (FOCO NO EVENTO)
-- ==========================================

-- Adicionamos o novo caminho que você passou
local petLocations = {
	workspace:FindFirstChild("NewEventIslandPets"), -- Caminho Prioritário
	workspace:FindFirstChild("IceIslandPets"),
	workspace:FindFirstChild("RoamingPets"),
	workspace:FindFirstChild("SkyIslandPets"),
	workspace:FindFirstChild("WaterIslandPets"),
	workspace:FindFirstChild("BeeIslandPets"),
}

local catching = false

local function CatchLoop()
	while toggles.AutoCatchToggle.Value do
		for _, location in ipairs(petLocations) do
			if not toggles.AutoCatchToggle.Value then break end
			if not location then continue end
			
			local petsFolder = location:FindFirstChild("Pets")
			if not petsFolder then continue end

			for _, pet in ipairs(petsFolder:GetChildren()) do
				if not toggles.AutoCatchToggle.Value then break end
				if not pet:IsA("Model") or not pet.PrimaryPart then continue end

				local rarity = pet:GetAttribute("Rarity")
				local petName = pet:GetAttribute("Name")
				local size = pet:GetAttribute("Size") or "Normal"
				local rps = pet:GetAttribute("RPS") or pet:GetAttribute("Coins") or 0 

				if not petName or not rarity then continue end

				-- Filtro de Colossal
				if toggles.OnlyColossalToggle.Value and size ~= "Colossal" then continue end

				-- Verificação de Seleção (Tolerante a erros de digitação/espaços)
				local dropdown = options[`Pets-{rarity}`]
				local isSelected = false
				
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

				if not isSelected then continue end

				-- Inicia Captura
				local myCFrame = character:GetPrimaryPartCFrame()
				local success = minigameRequest:InvokeServer(pet, myCFrame)
				
				if success then
					retrieveData:InvokeServer()
					
					-- Simulação de progresso ultra rápida
					for i = 1, 5 do
						updateProgress:FireServer(i * 20)
						task.wait() 
					end

					sendWebhook(petName, rarity, size, rps)
					task.wait(0.3) -- Delay mínimo para eficiência máxima
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
	catching = false
end

toggles.AutoCatchToggle:OnChanged(function(active)
	if active and not catching then
		catching = true
		task.spawn(CatchLoop)
	end
end)

-- ==========================================
-- AUTO BUY FOOD
-- ==========================================
local RS = game:GetService("ReplicatedStorage")
local knitPackages = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("_Index")
local BuyFoodRemote = nil
local FoodServiceRE = nil

if knitPackages and knitPackages:FindFirstChild("sleitnick_knit@1.7.0") then
	local knitRe = knitPackages["sleitnick_knit@1.7.0"].knit.Services.FoodService.RE
	BuyFoodRemote = knitRe.BuyFood
	FoodServiceRE = knitRe
end

toggles.AutoBuyFoodToggle:OnChanged(function(active)
	if active and FoodServiceRE then
		local conn = FoodServiceRE.ReplicateStock.OnClientEvent:Connect(function(stock)
			for item, amount in pairs(stock) do
				if amount > 0 then BuyFoodRemote:FireServer(item) end
			end
		end)
		repeat task.wait(1) until not toggles.AutoBuyFoodToggle.Value
		conn:Disconnect()
	end
end)

-- ==========================================
-- FINALIZAÇÃO
-- ==========================================
local UISettings = window:AddTab("UI Settings")
local SettingsGroup = UISettings:AddLeftGroupbox('Menu')
SettingsGroup:AddButton('Unload', function() Library:Unload() end)
SettingsGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = "End", NoUI = true, Text = "Menu keybind" })

Library["ToggleKeybind"] = options.MenuKeybind
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("AutoCatch")
SaveManager:SetFolder("AutoCatch/configs")
SaveManager:BuildConfigSection(UISettings)
ThemeManager:ApplyToTab(UISettings)
SaveManager:LoadAutoloadConfig()
