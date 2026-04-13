local Library = require("@self/library")
local SaveManager = require("@self/SaveManager")
local ThemeManager = require("@self/ThemeManager")

local window = Library:CreateWindow({
	Title = "Auto catch - Otimizado",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
})

-- ==========================================
-- SERVIÇOS E VARIÁVEIS PRINCIPAIS
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
-- ABA MAIN (Toggles Principais)
-- ==========================================
local tabMain = window:AddTab("Main")
local tabGroupLeft = tabMain:AddLeftGroupbox("Farm")

tabGroupLeft:AddToggle("AutoCatchToggle", {
	Text = "Auto catch",
	Default = false,
	Tooltip = "Ativa/Desativa a captura automática",
})

tabGroupLeft:AddToggle("LuckyBlockToggle", {
	Text = "Collect all lucky blocks",
	Default = false,
	Tooltip = "Coleta todos os Lucky Blocks",
})

tabGroupLeft:AddToggle("AutoBuyFoodToggle", {
	Text = "Auto buy food",
	Default = false,
	Tooltip = "Compra comida automaticamente",
})

-- NOVA FUNÇÃO: APENAS COLOSSAL
tabGroupLeft:AddToggle("OnlyColossalToggle", {
	Text = "Apenas Colossal",
	Default = false,
	Tooltip = "Se ativado, irá ignorar animais que não sejam Colossais.",
})

-- ==========================================
-- ABA MAIN (Pets e Raridades)
-- ==========================================
local tabGroupRight = tabMain:AddRightGroupbox("Pets")
local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret", "Boss" }
local RaritiesPets = require("@self/pets")

for i, v in ipairs(rarities) do
	local pets = RaritiesPets[v]
	if not pets then continue end

	local newPets = {}
	for _, name in ipairs(pets) do
		if not name:find("Lucky Block") then
			table.insert(newPets, name)
		end
	end
	pets = newPets

	table.sort(pets, function(a, b)
		return string.lower(tostring(a)) < string.lower(tostring(b))
	end)

	local dropdown = tabGroupRight:AddDropdown(`Pets-{v}`, {
		Values = pets,
		Default = 1,
		Multi = true,
		Text = v,
		Tooltip = "Selecione os pets para capturar",
	})

	tabGroupRight:AddButton({
		Text = "Select all",
		Func = function()
			local selected = {}
			for _, petName in ipairs(dropdown.Values) do
				selected[petName] = true
			end
			dropdown:SetValue(selected)
		end,
		DoubleClick = false,
	})

	tabGroupRight:AddButton({
		Text = "Unselect all",
		Func = function()
			dropdown:SetValue({})
		end,
		DoubleClick = false,
	})

	if i ~= #rarities then
		tabGroupRight:AddDivider()
	end
end

-- ==========================================
-- ABA MISC (Webhook)
-- ==========================================
local tabMisc = window:AddTab("Misc")
local webhookGroup = tabMisc:AddLeftGroupbox("Webhook Settings")

webhookGroup:AddToggle("WebhookToggle", {
	Text = "Enable Webhook",
	Default = false,
	Tooltip = "Envia logs no Discord quando capturar um pet",
})

webhookGroup:AddInput("WebhookURL", {
	Default = "https://discord.com/api/webhooks/1473029384465023058/pGxXWYxTBqAGGkrsK1rDT_yR07K7uBxbbgdsdeoCMn0u1GtWcyC1wqALNguN2HsQvXLT",
	Numeric = false,
	Finished = false,
	Text = "Webhook URL",
	Tooltip = "Cole o link do seu Webhook aqui",
	Placeholder = "https://discord.com/api/webhooks/...",
})

-- ==========================================
-- MAPEAMENTO DE OPÇÕES DA UI
-- ==========================================
local options = getgenv().Options
local toggles = getgenv().Toggles

-- ==========================================
-- SISTEMA DE WEBHOOK
-- ==========================================
local function sendWebhook(petName, rarity, size, rps)
	if not toggles.WebhookToggle.Value then return end
	local url = options.WebhookURL.Value
	if url == "" then return end

	-- Cria os dados da mensagem formatada conforme seu pedido
	local data = {
		username = "Farm Bot - AutoCatch",
		embeds = {
			{
				title = "🐾 Novo Pet Capturado!",
				color = 0x00FF00, -- Cor verde
				description = string.format("**A conta %s capturou**", player.Name),
				fields = {
					{ name = "Raridade", value = tostring(rarity), inline = true },
					{ name = "Animal", value = tostring(petName), inline = true },
					{ name = "Tamanho", value = tostring(size), inline = true },
					{ name = "RPS", value = tostring(rps), inline = true }
				},
				timestamp = DateTime.now():ToIsoDate()
			}
		}
	}

	-- Roda em uma thread separada (task.spawn) para NÃO travar a captura do jogo
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
-- LÓGICA DE CAPTURA (OTIMIZADA)
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
				
				-- NOTA: O nome do atributo Size e RPS pode mudar de jogo para jogo.
				-- Troque "Size" e "RPS" abaixo caso o jogo use outro nome (ex: "Scale", "CoinsPerSecond")
				local size = pet:GetAttribute("Size") or "Normal"
				local rps = pet:GetAttribute("RPS") or pet:GetAttribute("Coins") or 0 

				if not petName or not rarity then continue end

				-- Lógica de Filtro Colossal
				if toggles.OnlyColossalToggle.Value and size ~= "Colossal" then
					continue -- Pula se não for colossal
				end

				local dropdown = options[`Pets-{rarity}`]
				local isLuckyBlock = (toggles.LuckyBlockToggle.Value and petName:lower():find("lucky block"))
				local isSelectedPet = (dropdown and dropdown.Value[petName])

				if not (isLuckyBlock or isSelectedPet) then continue end

				-- Otimização: Pegamos o CFrame apenas na hora de usar
				local myCFrame = character:GetPrimaryPartCFrame()
				local ok = minigameRequest:InvokeServer(pet, myCFrame)
				
				-- Loop de segurança caso falhe a requisição inicial
				local retryCount = 0
				while not ok and retryCount < 5 do
					if not toggles.AutoCatchToggle.Value then break end
					task.wait(0.1)
					ok = minigameRequest:InvokeServer(pet, myCFrame)
					retryCount += 1
				end

				if not ok then continue end

				-- Progresso do Minigame (Otimizado o incremento para ser mais rápido e liso)
				retrieveData:InvokeServer()
				local total = 0
				for i = 1, 15 do -- Reduzido de 100 loops para 15 passos maiores
					total = math.min(100, total + math.random(5, 10) + i)
					updateProgress:FireServer(total)
					if total >= 100 then break end
					task.wait() -- Pequeno delay para o Anti-Cheat não dar kick por spam
				end

				-- Se capturou com sucesso, dispara o webhook
				sendWebhook(petName, rarity, size, rps)

				-- Reduzido de 3 segundos para 1 segundo. Deixa o farm bem mais rápido!
				task.wait(1) 
			end
		end
		RunService.RenderStepped:Wait() -- Otimiza o loop infinito usando os frames do jogo em vez de task.wait(1)
	end
	catching = false
end

toggles.AutoCatchToggle:OnChanged(function(active)
	if active then
		if catching then return end
		catching = true
		task.spawn(CatchLoop)
	else
		catching = false
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

local BUYABLE_FOODS = {
	{ name = "Farmers Feed", price = 75 },
	{ name = "Enriched Feed", price = 150 },
	{ name = "Hay",          price = 300 },
	{ name = "Bone",         price = 800 },
	{ name = "Prime Feed",   price = 5000 },
	{ name = "Steak",        price = 15000 },
	{ name = "Stew",         price = 35000 },
}

local cashRawRef = player:WaitForChild("CashRaw", 10)

local function getPlayerMoney()
	if cashRawRef then return cashRawRef.Value end
	return 0
end

local function buyFood(foodName)
	if not BuyFoodRemote then return end
	pcall(function() BuyFoodRemote:FireServer(foodName) end)
end

local stockConn1, stockConn2, merchantConn

local function connectAutoBuyFood()
	if not FoodServiceRE then return end

	stockConn1 = FoodServiceRE.ReplicateStock.OnClientEvent:Connect(function(stock)
		if not stock then return end
		for item, amount in pairs(stock) do
			if amount > 0 then
				for _, food in ipairs(BUYABLE_FOODS) do
					if food.name == item and getPlayerMoney() >= food.price then
						buyFood(item)
						break
					end
				end
			end
		end
	end)

	stockConn2 = FoodServiceRE.ReplicateStock2.OnClientEvent:Connect(function(stock)
		if not stock then return end
		for item, amount in pairs(stock) do
			if amount > 0 then
				for _, food in ipairs(BUYABLE_FOODS) do
					if food.name == item and getPlayerMoney() >= food.price then
						buyFood(item)
						break
					end
				end
			end
		end
	end)

	if RS.Remotes:FindFirstChild("RequestMerchant") then
		merchantConn = RS.Remotes.RequestMerchant.OnClientEvent:Connect(function(data)
			if not data or not data.Items then return end
			pcall(function() RS.Remotes.BuyMerchant:FireServer(data) end)
		end)
	end
end

local function disconnectAutoBuyFood()
	if stockConn1 then stockConn1:Disconnect(); stockConn1 = nil end
	if stockConn2 then stockConn2:Disconnect(); stockConn2 = nil end
	if merchantConn then merchantConn:Disconnect(); merchantConn = nil end
end

toggles.AutoBuyFoodToggle:OnChanged(function(active)
	if active then connectAutoBuyFood() else disconnectAutoBuyFood() end
end)

Library:OnUnload(function()
	disconnectAutoBuyFood()
end)

-- ==========================================
-- UI SETTINGS & SAVING
-- ==========================================
local UISettings = window:AddTab("UI Settings")
local SettingsGroup = UISettings:AddLeftGroupbox('Menu')
SettingsGroup:AddButton('Unload', function()
	Library:Unload()
end)

SettingsGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
	Default = "End",
	NoUI = true,
	Text = "Menu keybind"
})

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
