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

local islands = { "Roaming", "IceIsland", "SkyIsland", "WaterIsland", "BeeIsland" }
for i, v in islands do
    islands[i] = workspace:FindFirstChild(`{v}Pets`)
end
local function CatchPets()
    for _, islandFolder in islands do
        local pets = islandFolder:FindFirstChild("Pets")
        if not pets then
            continue
        end

        for _, pet in pets:GetChildren() do
            if not pet.PrimaryPart then
                continue
            end

            local rarity = pet:GetAttribute("Rarity")
            local petName = pet:GetAttribute("Name")
            if not petName or not rarity then
                continue
            end

            local dropdown = options[`Pets-{rarity}`]
            if not (
                (toggles.LuckyBlockToggle.Value and petName:lower():find("lucky block")) or
                (dropdown and dropdown.Value[petName])
            ) then
                continue
            end

            local myCFrame = character:GetPrimaryPartCFrame()
            local ok = minigameRequest:InvokeServer(pet, myCFrame)
            local l = tick()
            while not ok and tick() - l < 3 do
                task.wait()
                ok = minigameRequest:InvokeServer(pet, myCFrame)
            end

            if not ok then
                continue
            end

            retrieveData:InvokeServer()

            local total = 0
            for i = 1, 100 do
                total = math.min(100, total + (i + math.random()))
                updateProgress:FireServer(total)
                if total == 100 then
                    break
                end
            end
        end
        task.wait()
    end
end

local oldConnection
toggles.AutoCatchToggle:OnChanged(function(active)
    if oldConnection then
        oldConnection:Disconnect()
    end

    if active then
        oldConnection = RunService.RenderStepped:Connect(CatchPets)
    end
end)

Library:OnUnload(function()
    if oldConnection then
        oldConnection:Disconnect()
    end
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
