--!strict
--[[
	Server-authoritative shop: catalog, purchase, equip.
	Remotes: GetShop (request), PurchaseItem, EquipItem, ShopResult, PlayerDataSync.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local ShopService = {}

local remotesFolder: Folder? = nil
local getShopRemote: RemoteEvent? = nil
local purchaseRemote: RemoteEvent? = nil
local equipRemote: RemoteEvent? = nil
local resultRemote: RemoteEvent? = nil

local function ensureRemotes()
	if remotesFolder and getShopRemote and purchaseRemote and equipRemote and resultRemote then
		return
	end
	remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	local function ensure(name: string): RemoteEvent
		local e = remotesFolder:FindFirstChild(name)
		if e and e:IsA("RemoteEvent") then
			return e
		end
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotesFolder
		return r
	end
	getShopRemote = ensure(Config.Remotes.GetShop)
	purchaseRemote = ensure(Config.Remotes.PurchaseItem)
	equipRemote = ensure(Config.Remotes.EquipItem)
	resultRemote = ensure(Config.Remotes.ShopResult)
end

local function catalogPayload(player: Player): { [string]: any }
	local profile = PlayerDataService.Get(player)
	local items = {}
	for _, item in Config.ShopItems do
		local owned = profile.OwnedItems[item.Id] == true
		local equippedId = nil
		local cat = item.Category
		if cat == "PistolSkin" then
			equippedId = profile.Equipped.PistolSkin
		elseif cat == "KnifeSkin" then
			equippedId = profile.Equipped.KnifeSkin
		elseif cat == "Trail" then
			equippedId = profile.Equipped.Trail
		elseif cat == "Hitmarker" then
			equippedId = profile.Equipped.Hitmarker
		elseif cat == "Title" then
			equippedId = profile.Equipped.Title
		end
		table.insert(items, {
			Id = item.Id,
			Name = item.Name,
			Category = item.Category,
			Price = item.Price,
			Description = item.Description or "",
			Owned = owned,
			Equipped = equippedId == item.Id,
			HandleColor = item.HandleColor,
			TipColor = item.TipColor,
			TrailColor = item.TrailColor,
			HitColor = item.HitColor,
			TitleText = item.TitleText,
			TitleColor = item.TitleColor,
			DisplayName = item.DisplayName,
		})
	end
	return {
		Credits = profile.Credits,
		Items = items,
		Equipped = {
			PistolSkin = profile.Equipped.PistolSkin,
			KnifeSkin = profile.Equipped.KnifeSkin,
			Trail = profile.Equipped.Trail,
			Hitmarker = profile.Equipped.Hitmarker,
			Title = profile.Equipped.Title,
		},
	}
end

local function sendResult(player: Player, ok: boolean, message: string, extra: any?)
	ensureRemotes()
	if resultRemote then
		resultRemote:FireClient(player, {
			ok = ok,
			message = message,
			extra = extra,
			shop = catalogPayload(player),
		})
	end
end

function ShopService.SendCatalog(player: Player)
	ensureRemotes()
	if getShopRemote then
		-- Reuse GetShop as S→C catalog push as well
		getShopRemote:FireClient(player, catalogPayload(player))
	end
	PlayerDataService.Sync(player)
end

function ShopService.Init()
	ensureRemotes()
	PlayerDataService.Init()

	assert(getShopRemote and purchaseRemote and equipRemote)

	getShopRemote.OnServerEvent:Connect(function(player)
		ShopService.SendCatalog(player)
	end)

	purchaseRemote.OnServerEvent:Connect(function(player, itemId)
		if typeof(itemId) ~= "string" then
			sendResult(player, false, "Invalid item")
			return
		end
		local item = Config.GetShopItem(itemId)
		if not item then
			sendResult(player, false, "Unknown item")
			return
		end
		if PlayerDataService.Owns(player, itemId) then
			sendResult(player, false, "Already owned")
			return
		end
		local price = math.max(0, math.floor(item.Price or 0))
		if price > 0 and not PlayerDataService.TrySpend(player, price) then
			sendResult(player, false, "Not enough Credits")
			return
		end
		PlayerDataService.GrantItem(player, itemId)
		-- Auto-equip on purchase
		PlayerDataService.Equip(player, itemId)
		sendResult(player, true, "Purchased " .. tostring(item.Name), { itemId = itemId })
		ShopService.SendCatalog(player)
	end)

	equipRemote.OnServerEvent:Connect(function(player, itemId)
		if typeof(itemId) ~= "string" then
			sendResult(player, false, "Invalid item")
			return
		end
		local ok, err = PlayerDataService.Equip(player, itemId)
		if ok then
			sendResult(player, true, "Equipped", { itemId = itemId })
			ShopService.SendCatalog(player)
		else
			sendResult(player, false, err or "Equip failed")
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			task.wait(0.4)
			if player.Parent then
				ShopService.SendCatalog(player)
			end
		end)
	end)
	for _, plr in Players:GetPlayers() do
		task.spawn(function()
			ShopService.SendCatalog(plr)
		end)
	end
end

return ShopService
