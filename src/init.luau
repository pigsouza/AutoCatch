local Library = require("@self/library")
local SaveManager = require("@self/SaveManager")
local ThemeManager = require("@self/ThemeManager")

local window = Library:CreateWindow({
	Title = "Auto Catch - Ultra Efficiency v2",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
})

-- ==========================================
-- SERVIÇOS E VARIÁVEIS DE AMBIENTE
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
-- ABA PRINCIPAL (FARM)
-- ==========================================
local tabMain = window:AddTab("Main")
local tabGroupLeft = tabMain:AddLeftGroupbox("Farm Settings")

tabGroupLeft:AddToggle("AutoCatchToggle", {
	Text = "Auto Catch",
	Default = false,
	Tooltip = "Ativa a captura automatica de pets",
})

tabGroupLeft:AddToggle("OnlyColossalToggle", {
	Text = "Capturar Apenas Colossal",
	Default = false,
	Tooltip = "Ignora todos os pets que nao sejam do tamanho Colossal",
})

tabGroupLeft:AddToggle("LuckyBlockToggle", {
	Text = "Coletar Lucky Blocks",
	Default = false,
	Tooltip = "Ativa a coleta automatica de Lucky Blocks",
})

tabGroupLeft:AddToggle("AutoBuyFoodToggle", {
	Text = "Auto Buy Food",
	Default = false,
	Tooltip = "Compra comida automaticamente baseada no estoque",
})

-- ==========================================
-- SELEÇÃO DE PETS POR RARIDADE
-- ==========================================
local tabGroupRight = tabMain:AddRightGroupbox("Pets Selection")
local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret", "Boss" }
local RaritiesPets = require("@self/pets")

for i, v in ipairs(rarities) do
	local pets = RaritiesPets[v]
	if not pets then continue end

	local cleanPets = {}
	for _, name in ipairs(pets) do
		if not name:find("Lucky Block") then
			table.insert(cleanPets, name)
		end
	end

	table.sort(cleanPets, function(a, b)
		return string.lower(tostring(a)) < string.lower(tostring(b))
	end)

	local dropdown = tabGroupRight:AddDropdown(`Pets-{v}`, {
		Values = cleanPets,
		Default = 1,
		Multi = true,
		Text = v,
	})

	tabGroupRight:AddButton({
		Text = "Select All",
		Func = function()
			local selected = {}
			for _, petName in ipairs(dropdown.Values) do selected[petName] = true end
			dropdown:SetValue(selected)
		end
	})

	tabGroupRight:AddButton({
		Text = "Unselect All",
		Func = function() dropdown:SetValue({}) end
	})

	if i ~= #rarities then tabGroupRight:AddDivider() end
end

-- ==========================================
-- ABA MISC & WEBHOOK
-- ==========================================
local tabMisc = window:AddTab("Misc")
local webhookGroup = tabMisc:AddLeftGroupbox("Discord Webhook")

webhookGroup:AddToggle("WebhookToggle", {
	Text = "Enable Webhook",
	Default = false,
	Tooltip = "Envia informacoes da captura para o seu Discord",
})

webhookGroup:AddInput("WebhookURL", {
	Default = "https://discord.com/api/webhooks/1473029384465023058/pGxXWYxTBqAGGkrsK1rDT_yR07K7uBxbbgdsdeoCMn0u1GtWcyC1wqALNguN2HsQvXLT",
	Text = "Webhook URL",
	Finished = true,
})

-- ==========================================
-- SISTEMA DE LOGS E OTIMIZAÇÃO
-- ==========================================
local options = getgenv().Options
local toggles = getgenv().Toggles

local function sendWebhook(petName, rarity, size, rps)
	if not toggles.WebhookToggle.Value then return end
	local url = options.WebhookURL.Value
	if url == "" then return end

	local data = {
		content = nil,
		embeds = {
			{
				title = "✅ Captura Bem Sucedida!",
				description = string.format("A conta **%s** capturou um novo animal!", player.Name),
				color = 65280,
				fields = {
					{ name = "Raridade", value = tostring(rarity), inline = true },
					{ name = "Animal", value = tostring(petName), inline = true },
					{ name = "Tamanho", value = tostring(size), inline = true },
					{ name = "RPS", value = tostring(rps), inline = true },
				},
				footer = { text = "Auto Catch Bot - Eficiencia Maxima" },
				timestamp = DateTime.now():ToIsoDate()
			}
		}
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
-- LÓGICA DE CATCH (ULTRA FAST)
-- ==========================================
local islands = {
	workspace:FindFirstChild("IceIslandPets"),
	workspace:FindFirstChild("RoamingPets"),
	workspace:FindFirstChild("SkyIslandPets"),
	workspace:FindFirstChild("WaterIslandPets"),
	workspace:FindFirstChild("BeeIslandPets"),
}

local catching = false

local function CatchLoop()
	while toggles.AutoCatchToggle.Value do
		for _, island in ipairs(islands) do
			if not toggles.AutoCatchToggle.Value then break end
			if not island then continue end
			
			local petsFolder = island:FindFirstChild("Pets")
			if not petsFolder then continue end

			for _, pet in ipairs(petsFolder:GetChildren()) do
				if not toggles.AutoCatchToggle.Value then break end
				if not pet.PrimaryPart then continue end

				local rarity = pet:GetAttribute("Rarity")
				local petName = pet:GetAttribute("Name")
				local size = pet:GetAttribute("Size") or "Normal"
				local rps = pet:GetAttribute("RPS") or pet:GetAttribute("Coins") or 0 

				if not petName or not rarity then continue end

				-- Filtro Colossal
				if toggles.OnlyColossalToggle.Value and size ~= "Colossal" then continue end

				local dropdown = options[`Pets-{rarity}`]
				local isLuckyBlock = (toggles.LuckyBlockToggle.Value and petName:lower():find("lucky block"))
				
				-- Verificação inteligente (Ignora Case e Espaços)
				local isSelectedPet = false
				if dropdown and dropdown.Value then
					for selectedName, isToggled in pairs(dropdown.Value) do
						if isToggled and string.lower(selectedName:gsub("%s","")) == string.lower(petName:gsub("%s","")) then
							isSelectedPet = true
							break
						end
					end
				end

				if not (isLuckyBlock or isSelectedPet) then continue end

				local myCFrame = character:GetPrimaryPartCFrame()
				local ok = minigameRequest:InvokeServer(pet, myCFrame)
				
				if not ok then continue end

				retrieveData:InvokeServer()
				
				-- Progressão Acelerada (Otimizado para farm pesado)
				local total = 0
				for i = 1, 10 do
					total = math.min(100, total + math.random(10, 15))
					updateProgress:FireServer(total)
					if total >= 100 then break end
					task.wait() 
				end

				sendWebhook(petName, rarity, size, rps)
				task.wait(0.5) -- Delay reduzido para eficiencia maxima
			end
		end
		RunService.RenderStepped:Wait() 
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
-- AUTO BUY FOOD (FUNCIONAL)
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

local BUYABLE_FOODS = {
	{ name = "Farmers Feed", price = 75 },
	{ name = "Enriched Feed", price = 150 },
	{ name = "Hay", price = 300 },
	{ name = "Bone", price = 800 },
	{ name = "Prime Feed", price = 5000 },
	{ name = "Steak", price = 15000 },
	{ name = "Stew", price = 35000 },
}

local cashRawRef = player:WaitForChild("CashRaw", 10)

local function getPlayerMoney()
	return cashRawRef and cashRawRef.Value or 0
end

local stockConn1, stockConn2

local function connectAutoBuyFood()
	if not FoodServiceRE then return end
	stockConn1 = FoodServiceRE.ReplicateStock.OnClientEvent:Connect(function(stock)
		if not stock then return end
		for item, amount in pairs(stock) do
			if amount > 0 then
				for _, food in ipairs(BUYABLE_FOODS) do
					if food.name == item and getPlayerMoney() >= food.price then
						BuyFoodRemote:FireServer(item)
						break
					end
				end
			end
		end
	end)
end

toggles.AutoBuyFoodToggle:OnChanged(function(active)
	if active then connectAutoBuyFood() elseif stockConn1 then stockConn1:Disconnect() end
end)

-- ==========================================
-- CARREGAMENTO DE CONFIGURAÇÕES
-- ==========================================
local UISettings = window:AddTab("UI Settings")
local SettingsGroup = UISettings:AddLeftGroupbox('Menu')

SettingsGroup:AddButton('Unload', function() Library:Unload() end)
SettingsGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = "End", NoUI = true, Text = "Menu keybind" })

Library["ToggleKeybind"] = options.MenuKeybind
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("AutoCatch")
SaveManager:SetFolder("AutoCatch/configs")
SaveManager:BuildConfigSection(UISettings)
ThemeManager:ApplyToTab(UISettings)
SaveManager:LoadAutoloadConfig()
