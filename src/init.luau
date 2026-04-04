	local Library = require("@self/library")

	local window = Library:CreateWindow({
		Title = "Auto catch",
		Center = true,
		AutoShow = true,
		TabPadding = 8,
		MenuFadeTime = 0.2,
	})

	local tab = window:AddTab("Main")
	local tabGroupLeft = tab:AddLeftGroupbox("Groupbox")

	tabGroupLeft:AddToggle("AutoCatchToggle", {
		Text = "Auto catch",
		Default = false,
		Tooltip = "enabled/disabled auto catch",
		Callback = function()
		end,
	})

	tabGroupLeft:AddToggle("LuckyBlockToggle", {
		Text = "Collect all lucky blocks",
		Default = false,
		Tooltip = "enabled/disabled collect all lucky blocks",
		Callback = function()
		end,
	})

	tabGroupLeft:AddToggle("AutoBuyFoodToggle", {
		Text = "Auto buy food",
		Default = false,
		Tooltip = "enabled/disabled auto buy food",
		Callback = function()
		end,
	})

	local tabGroupRight = tab:AddRightGroupbox("Pets")
	local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret", "Boss" }
	local RaritiesPets = require("@self/pets")
	for i, v in rarities do
		local pets = RaritiesPets[v]
		if not pets then
			continue
		end

		local newPets = {}
		for index, name in pets do
			if name:find("Lucky Block") then
				continue
			end
			table.insert(newPets, name)
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
			Tooltip = "select pets",
			Callback = function(selected)
			end,
		})

		tabGroupRight:AddButton({
			Text = "Select all",
			Func = function()
				local selected = {}
				for i, v in dropdown.Values do
					selected[v] = true
				end
				dropdown:SetValue(selected)
			end,
			DoubleClick = false,
			Tooltip = "select all pets",
		})

		tabGroupRight:AddButton({
			Text = "Unselect all",
			Func = function()
				dropdown:SetValue({})
			end,
			DoubleClick = false,
			Tooltip = "unselect all pets",
		})

		if i ~= #rarities then
			tabGroupRight:AddDivider()
		end
	end

	-- main
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")

	local Remotes = ReplicatedStorage.Remotes
	local minigameRequest = Remotes.minigameRequest
	local retrieveData = Remotes.retrieveData
	local updateProgress = Remotes.UpdateProgress

	local player = Players.LocalPlayer

	-- Anti AFK
	local VirtualUser = game:GetService("VirtualUser")
	player.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)

	local character
	local function CharacterAdded(newCharacter)
		character = newCharacter
	end

	if player.Character then
		CharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(CharacterAdded)

	type Dropdown = typeof(tabGroupRight:AddDropdown("", {}))
	type Keybind = typeof(tabGroupRight:AddKeybind("", {}))
	local options: {
		Islands: Dropdown,
		RaritiesToCapture: Dropdown,
		MenuKeybind: Keybind,
	} = {}
	for i, v in getgenv().Options do
		options[i] = v
	end

	type Toggle = typeof(tabGroupLeft:AddToggle("", {}))
	local toggles = (getgenv().Toggles :: {
		AutoCatchToggle: Toggle,
		LuckyBlockToggle: Toggle,
	})

	local islands = {
		workspace.IceIslandPets,
		workspace.RoamingPets,
		workspace.SkyIslandPets,
		workspace.WaterIslandPets,
		workspace.BeeIslandPets,
	}

	local catching = false

	local function CatchLoop()
		while toggles.AutoCatchToggle.Value do
			for _, island in islands do
				if not toggles.AutoCatchToggle.Value then break end
				local pets = island:FindFirstChild("Pets")
				if not pets then continue end

				for _, pet in pets:GetChildren() do
					if not toggles.AutoCatchToggle.Value then break end
					if not pet.PrimaryPart then continue end

					local rarity = pet:GetAttribute("Rarity")
					local petName = pet:GetAttribute("Name")
					if not petName or not rarity then continue end

					local dropdown = options[`Pets-{rarity}`]
					if not (
						(toggles.LuckyBlockToggle.Value and petName:lower():find("lucky block")) or
						(dropdown and dropdown.Value[petName])
					) then continue end

					local myCFrame = character:GetPrimaryPartCFrame()
					local ok = minigameRequest:InvokeServer(pet, myCFrame)
					while not ok do
						if not toggles.AutoCatchToggle.Value then break end
						task.wait()
						ok = minigameRequest:InvokeServer(pet, myCFrame)
					end

					if not ok then continue end

					retrieveData:InvokeServer()

					local total = 0
					for i = 1, 100 do
						total = math.min(100, total + (i + math.random()))
						updateProgress:FireServer(math.min(100, total))
						if total >= 100 then break end
					end

					task.wait(3)
				end
			end
			task.wait(1)
		end
		catching = false
	end

	-- Auto Buy Food
	local RS = game:GetService("ReplicatedStorage")
	local BuyFoodRemote = nil
	pcall(function() BuyFoodRemote = RS.Packages._Index["sleitnick_knit@1.7.0"].knit.Services.FoodService.RE.BuyFood end)
	local FoodServiceRE = RS.Packages._Index["sleitnick_knit@1.7.0"].knit.Services.FoodService.RE

	local BUYABLE_FOODS = {
		{ name = "Farmers Feed", price = 75 },
		{ name = "Enriched Feed", price = 150 },
		{ name = "Hay",          price = 300 },
		{ name = "Bone",         price = 800 },
		{ name = "Prime Feed",   price = 5000 },
		{ name = "Steak",        price = 15000 },
		{ name = "Stew",         price = 35000 },
	}

	local cashRawRef = player:FindFirstChild("CashRaw")
	local function getPlayerMoney()
		if cashRawRef and cashRawRef.Parent then return cashRawRef.Value end
		return 0
	end

	local function buyFood(foodName)
		if not BuyFoodRemote then return end
		pcall(function() BuyFoodRemote:FireServer(foodName) end)
	end

	local stockConn1, stockConn2, merchantConn

	local function connectAutoBuyFood()
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

		merchantConn = RS.Remotes.RequestMerchant.OnClientEvent:Connect(function(data)
			if not data or not data.Items then return end
			pcall(function() RS.Remotes.BuyMerchant:FireServer(data) end)
		end)
	end

	local function disconnectAutoBuyFood()
		if stockConn1 then stockConn1:Disconnect(); stockConn1 = nil end
		if stockConn2 then stockConn2:Disconnect(); stockConn2 = nil end
		if merchantConn then merchantConn:Disconnect(); merchantConn = nil end
	end

	toggles.AutoBuyFoodToggle:OnChanged(function(active)
		if active then connectAutoBuyFood() else disconnectAutoBuyFood() end
	end)

	toggles.AutoCatchToggle:OnChanged(function(active)
		if active then
			if catching then return end
			catching = true
			task.spawn(CatchLoop)
		else
			catching = false
		end
	end)

	Library:OnUnload(function()
		disconnectAutoBuyFood()
	end)

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

	Library["ToggleKeybind"] = getgenv().Options.MenuKeybind

	local SaveManager = require("@self/SaveManager")
	local ThemeManager = require("@self/ThemeManager")
	SaveManager:SetLibrary(Library)
	ThemeManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
	ThemeManager:SetFolder("AutoCatch")
	SaveManager:SetFolder("AutoCatch/catch-and-fezes")
	SaveManager:BuildConfigSection(UISettings)
	ThemeManager:ApplyToTab(UISettings)
	SaveManager:LoadAutoloadConfig()
