--!strict
--[[
	Player profile: Credits, OwnedItems, Equipped.
	DataStore with in-memory fallback (Studio / API failure).
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerDataService = {}

export type EquippedMap = {
	PistolSkin: string,
	KnifeSkin: string,
	Trail: string,
	Hitmarker: string,
	Title: string,
}

export type Profile = {
	Credits: number,
	OwnedItems: { [string]: boolean },
	Equipped: EquippedMap,
}

local memory: { [number]: Profile } = {}
local dirty: { [number]: boolean } = {}
local saveTokens: { [number]: number } = {}
local store: DataStore? = nil
local syncRemote: RemoteEvent? = nil
local creditsRemote: RemoteEvent? = nil

local function getRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local function ensure(name: string): RemoteEvent
		local e = folder:FindFirstChild(name)
		if e and e:IsA("RemoteEvent") then
			return e
		end
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		return r
	end
	syncRemote = ensure(Config.Remotes.PlayerDataSync)
	creditsRemote = ensure(Config.Remotes.CreditsUpdate)
end

local function defaultOwned(): { [string]: boolean }
	local owned = {}
	for _, item in Config.ShopItems do
		if item.Default == true or item.Price == 0 then
			owned[item.Id] = true
		end
	end
	return owned
end

local function defaultEquipped(): EquippedMap
	local d = Config.GetDefaultShopIds()
	return {
		PistolSkin = d.PistolSkin or "pistol_default",
		KnifeSkin = d.KnifeSkin or "knife_default",
		Trail = d.Trail or "trail_none",
		Hitmarker = d.Hitmarker or "hit_default",
		Title = d.Title or "title_none",
	}
end

local function defaultProfile(): Profile
	return {
		Credits = Config.Economy.StartingCredits,
		OwnedItems = defaultOwned(),
		Equipped = defaultEquipped(),
	}
end

local function sanitize(raw: any): Profile
	local base = defaultProfile()
	if typeof(raw) ~= "table" then
		return base
	end
	if typeof(raw.Credits) == "number" then
		base.Credits = math.max(0, math.floor(raw.Credits))
	end
	if typeof(raw.OwnedItems) == "table" then
		for id, v in raw.OwnedItems do
			if typeof(id) == "string" and (v == true or v == 1) then
				if Config.GetShopItem(id) then
					base.OwnedItems[id] = true
				end
			end
		end
	end
	-- Always keep defaults owned
	for id in pairs(defaultOwned()) do
		base.OwnedItems[id] = true
	end
	if typeof(raw.Equipped) == "table" then
		local eq = raw.Equipped
		local function slot(key: string, fallback: string)
			local id = eq[key]
			if typeof(id) == "string" and base.OwnedItems[id] and Config.GetShopItem(id) then
				(base.Equipped :: any)[key] = id
			else
				(base.Equipped :: any)[key] = fallback
			end
		end
		local d = defaultEquipped()
		slot("PistolSkin", d.PistolSkin)
		slot("KnifeSkin", d.KnifeSkin)
		slot("Trail", d.Trail)
		slot("Hitmarker", d.Hitmarker)
		slot("Title", d.Title)
	end
	return base
end

local function keyFor(userId: number): string
	return (Config.Economy.DataStoreKeyPrefix or "plr_") .. tostring(userId)
end

local function serialize(profile: Profile): { [string]: any }
	local ownedList = {}
	for id, owned in profile.OwnedItems do
		if owned then
			table.insert(ownedList, id)
		end
	end
	return {
		Credits = profile.Credits,
		OwnedItems = ownedList,
		Equipped = {
			PistolSkin = profile.Equipped.PistolSkin,
			KnifeSkin = profile.Equipped.KnifeSkin,
			Trail = profile.Equipped.Trail,
			Hitmarker = profile.Equipped.Hitmarker,
			Title = profile.Equipped.Title,
		},
	}
end

local function deserialize(raw: any): Profile
	if typeof(raw) ~= "table" then
		return defaultProfile()
	end
	local ownedMap: { [string]: boolean } = {}
	if typeof(raw.OwnedItems) == "table" then
		-- Support both array and map
		local isArray = raw.OwnedItems[1] ~= nil
		if isArray then
			for _, id in raw.OwnedItems do
				if typeof(id) == "string" then
					ownedMap[id] = true
				end
			end
		else
			for id, v in raw.OwnedItems do
				if typeof(id) == "string" and v then
					ownedMap[id] = true
				end
			end
		end
	end
	return sanitize({
		Credits = raw.Credits,
		OwnedItems = ownedMap,
		Equipped = raw.Equipped,
	})
end

function PlayerDataService.Get(player: Player): Profile
	local p = memory[player.UserId]
	if not p then
		p = defaultProfile()
		memory[player.UserId] = p
	end
	return p
end

function PlayerDataService.Owns(player: Player, itemId: string): boolean
	local p = PlayerDataService.Get(player)
	return p.OwnedItems[itemId] == true
end

function PlayerDataService.GetEquipped(player: Player): EquippedMap
	return PlayerDataService.Get(player).Equipped
end

function PlayerDataService.GetCredits(player: Player): number
	return PlayerDataService.Get(player).Credits
end

local function pushSync(player: Player)
	getRemotes()
	local profile = PlayerDataService.Get(player)
	player:SetAttribute("CQCCredits", profile.Credits)
	player:SetAttribute("CQCTitle", profile.Equipped.Title)
	player:SetAttribute("CQCHitmarker", profile.Equipped.Hitmarker)
	player:SetAttribute("CQCTrail", profile.Equipped.Trail)
	player:SetAttribute("CQCPistolSkin", profile.Equipped.PistolSkin)
	player:SetAttribute("CQCKnifeSkin", profile.Equipped.KnifeSkin)
	if syncRemote then
		local ownedList = {}
		for id, owned in profile.OwnedItems do
			if owned then
				table.insert(ownedList, id)
			end
		end
		syncRemote:FireClient(player, {
			Credits = profile.Credits,
			OwnedItems = ownedList,
			Equipped = {
				PistolSkin = profile.Equipped.PistolSkin,
				KnifeSkin = profile.Equipped.KnifeSkin,
				Trail = profile.Equipped.Trail,
				Hitmarker = profile.Equipped.Hitmarker,
				Title = profile.Equipped.Title,
			},
		})
	end
	if creditsRemote then
		creditsRemote:FireClient(player, profile.Credits)
	end
end

function PlayerDataService.Sync(player: Player)
	pushSync(player)
end

function PlayerDataService.AddCredits(player: Player, amount: number, reason: string?): number
	local profile = PlayerDataService.Get(player)
	local add = math.floor(amount)
	if add == 0 then
		return profile.Credits
	end
	profile.Credits = math.max(0, profile.Credits + add)
	dirty[player.UserId] = true
	pushSync(player)
	PlayerDataService.ScheduleSave(player)
	return profile.Credits
end

function PlayerDataService.TrySpend(player: Player, amount: number): boolean
	local profile = PlayerDataService.Get(player)
	local cost = math.floor(amount)
	if cost < 0 or profile.Credits < cost then
		return false
	end
	profile.Credits -= cost
	dirty[player.UserId] = true
	pushSync(player)
	PlayerDataService.ScheduleSave(player)
	return true
end

function PlayerDataService.GrantItem(player: Player, itemId: string): boolean
	if not Config.GetShopItem(itemId) then
		return false
	end
	local profile = PlayerDataService.Get(player)
	if profile.OwnedItems[itemId] then
		return true
	end
	profile.OwnedItems[itemId] = true
	dirty[player.UserId] = true
	pushSync(player)
	PlayerDataService.ScheduleSave(player)
	return true
end

function PlayerDataService.Equip(player: Player, itemId: string): (boolean, string?)
	local item = Config.GetShopItem(itemId)
	if not item then
		return false, "Unknown item"
	end
	local profile = PlayerDataService.Get(player)
	if not profile.OwnedItems[itemId] then
		return false, "Not owned"
	end
	local cat = item.Category
	if cat == "PistolSkin" then
		profile.Equipped.PistolSkin = itemId
	elseif cat == "KnifeSkin" then
		profile.Equipped.KnifeSkin = itemId
	elseif cat == "Trail" then
		profile.Equipped.Trail = itemId
	elseif cat == "Hitmarker" then
		profile.Equipped.Hitmarker = itemId
	elseif cat == "Title" then
		profile.Equipped.Title = itemId
	else
		return false, "Bad category"
	end
	dirty[player.UserId] = true
	pushSync(player)
	PlayerDataService.ScheduleSave(player)
	return true, nil
end

function PlayerDataService.Save(player: Player)
	local profile = memory[player.UserId]
	if not profile then
		return
	end
	dirty[player.UserId] = false
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player.UserId), serialize(profile))
	end)
	if not ok then
		warn("[CQC] DataStore save failed:", err)
	end
end

function PlayerDataService.ScheduleSave(player: Player)
	local uid = player.UserId
	saveTokens[uid] = (saveTokens[uid] or 0) + 1
	local token = saveTokens[uid]
	local delaySec = Config.Economy.SaveDebounceSeconds or 4
	task.delay(delaySec, function()
		if saveTokens[uid] ~= token then
			return
		end
		local plr = Players:GetPlayerByUserId(uid)
		if plr then
			PlayerDataService.Save(plr)
		end
	end)
end

local function loadPlayer(player: Player)
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(keyFor(player.UserId))
		end)
		if ok and data ~= nil then
			profile = deserialize(data)
		elseif not ok then
			warn("[CQC] DataStore load failed, using memory defaults:", data)
		end
	end
	memory[player.UserId] = profile
	dirty[player.UserId] = false
	pushSync(player)
end

function PlayerDataService.Init()
	getRemotes()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Economy.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[CQC] DataStore unavailable — in-memory only:", result)
		store = nil
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, plr in Players:GetPlayers() do
		task.spawn(loadPlayer, plr)
	end

	Players.PlayerRemoving:Connect(function(player)
		if dirty[player.UserId] then
			PlayerDataService.Save(player)
		end
		memory[player.UserId] = nil
		dirty[player.UserId] = nil
		saveTokens[player.UserId] = nil
	end)

	game:BindToClose(function()
		for _, plr in Players:GetPlayers() do
			pcall(PlayerDataService.Save, plr)
		end
	end)
end

return PlayerDataService
