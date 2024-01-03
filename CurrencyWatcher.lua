--=======================================================
-- Author: Lordmatics
-- Date: 03/01/2024
-- Description: Addon to visualise various Currencies
--				Mitigating the tediousness of having to find them
--=======================================================

_addon.name = "CurrencyWatcher"
_addon.author = "Lordmatics"
_addon.version = "1.1"
_addon.commands = {"CurrencyWatcher", "cw", "cwatcher"}

---------- DEFINE VARIABLES ----------------

DEBUG = false

m_bUIEnabled = true

config = require("config")
packets = require('packets')

zoning_bool = false

texts = require('texts')

m_headingCol = "\\cs(255,255,255)"
m_preCol = "\\cs(0,200,200)"
m_stateCol = "\\cs(0,200,200)"

defaults = {}
defaults.display = {}
defaults.display.pos = {}
defaults.display.pos.x = 0
defaults.display.pos.y = 0
defaults.display.bg = {}
defaults.display.bg.red = 0
defaults.display.bg.green = 0
defaults.display.bg.blue = 0
defaults.display.bg.alpha = 102
defaults.display.text = {}
defaults.display.text.font = 'Consolas'
defaults.display.text.red = 255
defaults.display.text.green = 255
defaults.display.text.blue = 255
defaults.display.text.alpha = 255
defaults.display.text.size = 12
defaults.category_index = 7

settings = T{}
settings = config.load('data\\settings.xml', defaults)
config.save(settings, 'global')

box = texts.new(settings)

-- My way of figuring out what packets are fluff, and what are relevant to this addon.
local packetDataToIgnore = T{	
	223, -- Char Update
	55, -- Update Char
	13, -- PC Update
	103, -- Pet Info, happens periodically
	14, -- NPC Update - Every frame whilst something is targeted.
	31, -- Item Assign
	29, -- Finish Inventory
	52, -- NPC Interaction
	191, -- Reservation Response
	92, -- Dialogue Information
	82, -- NPC Release
	42, -- Resting Message
	225, -- Linkshell Equip
	32, -- Item Update
	30, -- Modify Inventory
	80, -- Equip Updates
	101, -- Item Repositions
	91, -- Spawn
	28, -- Inventory Count
	95, -- Music Change
	81, -- Model Change
	266, -- Bazaar Buyer Info
	263, -- Bazaar Closed
	265, -- Bazaar Purch
	262, -- Bazaar Seller Info
	40, -- Action
	97, -- Char Stats
	98, -- Skills Update
	281, -- Ability Recasts
	99, -- Set Update
	279, -- Equipset Response
	172, -- Ability List
	41, -- Action Message
	170, -- Spell List
	118, -- Party Buff
	75, -- Delivery Item
	76, -- Auction House Menu
	45, -- Kill Message
	273, -- Eminence Update
	56, -- Entity Animation
	210, -- Found Item,
	50, -- Linkshell NPC Interaction
	224, -- Linkshell Equip
	211, -- Lot Drop Item
	221, -- Party Member Update
	23, -- Incoming Chat
	54, -- NPC Chat
	68, -- Job Info Extra
	200, -- Party Struct Update
}

local packetsToRefreshUI = T{
	0x110, -- Sparks
	0x00B, -- Zoning
	0x00A,-- Zoning In
	-- Tested for Ichor
	9, -- Standard Message
	-- 50, -- NPC Interaction - occurs before menu and some cutscenes
	79, -- Downloading Data 2 - Tested for Bead Pouch.
	-- I think 79 for Data Download 2 might be relevant
	117, -- Unity Start and coincidentally, end.
}

-- Ensure these structures are in sync.
m_categoryIndex = settings.category_index -- "All"
m_categories =
T{
	"Mythic", -- 1
	"Aeonic", -- 2
	"Sparks",
	"Adoulin",
	"Ambuscade",
	"Oddysey",
	"All" -- Must be last.
}

	-- see fields.lua to get the exact names
	-- Note, when i learn how to use settings.xml properly.
	-- Add support to customise this further.
CurrencyResultsCategorised = T{
	["Mythic"] =
	{
		Name = "Mythic",
		["Nyzul Tokens"] = 0,
		["Zeni"] = 0,
		["Jettons"] = 0,
		["Therion Ichor"] = 0,
	},
	["Aeonic"] = 
	{
		Name = "Aeonic",
		["Escha Beads"] = 0,
		["Domain Points"] = 0,
	},
	["Sparks"] =
	{
		Name = "Sparks",
		["Deeds"] = 0,
		["Sparks of Eminence"] = 0,
		["Unity Accolades"] = 0,
	},
	["Adoulin"] =
	{
		Name = "Adoulin",
		["Bayld"] = 0,
		["Coalition Imprimaturs"] = 0,
	},
	["Ambuscade"] =
	{
		Name = "Ambuscade",
		["Hallmarks"] = 0,
		["Total Hallmarks"] = 0,
		["Badges of Gallantry"] = 0,
	},
	["Oddysey"] =
	{
		Name = "Oddysey",
		["Mog Segments"] = 0,
		["Gallimaufry"] = 0,
	},
	["All"] =
	{
		Name = "All",
	}
}

local player_name = windower.ffxi.get_info().logged_in and windower.ffxi.get_player().name

-- Emulate opening the menu to get accurate values for these fields.
	-- See Packets/Data.lua for hex values 
local requests = {
    [0x113] = packets.new('outgoing', 0x10F),
    [0x118] = packets.new('outgoing', 0x115),
}

---------- DEFINE PACKET TABLE ----------------

local packetData = {}
packetData.incoming= {}
packetData.incoming[0x009] = {name='Standard Message',    description='A standardized message send from FFXI.'}
packetData.incoming[0x00A] = {name='Zone In',             description='Info about character and zone around it.'}
packetData.incoming[0x00B] = {name='Zone Out',            description='Packet contains IP and port of next zone to connect to.'}
packetData.incoming[0x00D] = {name='PC Update',           description='Packet contains info about another PC (i.e. coordinates).'}
packetData.incoming[0x00E] = {name='NPC Update',          description='Packet contains data about nearby targets (i.e. target\'s position, name).'}
packetData.incoming[0x017] = {name='Incoming Chat',       description='Packet contains data about incoming chat messages.'}
packetData.incoming[0x01B] = {name='Job Info',            description='Job Levels and levels unlocked.'}
packetData.incoming[0x01C] = {name='Inventory Count',     description='Describes number of slots in inventory.'}
packetData.incoming[0x01D] = {name='Finish Inventory',    description='Finish listing the items in inventory.'}
packetData.incoming[0x01E] = {name='Modify Inventory',    description='Modifies items in your inventory.'}
packetData.incoming[0x01F] = {name='Item Assign',         description='Assigns an ID to equipped items in your inventory.'}
packetData.incoming[0x020] = {name='Item Update',         description='Info about item in your inventory.'}
packetData.incoming[0x021] = {name='Trade Requested',     description='Sent when somebody offers to trade with you.'}
packetData.incoming[0x022] = {name='Trade Action',        description='Sent whenever something happens with the trade window.'}
packetData.incoming[0x023] = {name='Trade Item',          description='Sent when an item appears in the trade window.'}
packetData.incoming[0x025] = {name='Item Accepted',       description='Sent when the server will allow you to trade an item.'}
packetData.incoming[0x026] = {name='Count to 80',         description='It counts to 80 and does not have any obvious function. May have something to do with populating inventory.'}
packetData.incoming[0x027] = {name='String Message',      description='Message that includes a string as a parameter.'}
packetData.incoming[0x028] = {name='Action',              description='Packet sent when an NPC is attacking.'}
packetData.incoming[0x029] = {name='Action Message',      description='Packet sent for simple battle-related messages.'}
packetData.incoming[0x02A] = {name='Resting Message',     description='Packet sent when you rest in Abyssea.'}
packetData.incoming[0x02D] = {name='Kill Message',        description='Packet sent when you gain XP/LP/CP/JP/MP, advance RoE objectives, etc. by defeating a mob.'}
packetData.incoming[0x02E] = {name='Mog House Menu',      description='Sent when talking to moogle inside mog house.'}
packetData.incoming[0x02F] = {name='Digging Animation',   description='Generates the chocobo digging animation'}
packetData.incoming[0x030] = {name='Synth Animation',     description='Generates the synthesis animation'}
packetData.incoming[0x031] = {name='Synth List',          description='List of recipes or materials needed for a recipe'}
packetData.incoming[0x032] = {name='NPC Interaction 1',   description='Occurs before menus and some cutscenes'}
packetData.incoming[0x033] = {name='String NPC Interaction',description='Triggers a menu or cutscene to appear. Contains 4 strings.'}
packetData.incoming[0x034] = {name='NPC Interaction 2',   description='Occurs before menus and some cutscenes'}
packetData.incoming[0x036] = {name='NPC Chat',            description='Dialog from NPC\'s.'}
packetData.incoming[0x037] = {name='Update Char',         description='Updates a characters stats and animation.'}
packetData.incoming[0x038] = {name='Entity Animation',    description='Sent when a model should play a specific animation.'}
packetData.incoming[0x039] = {name='Env. Animation',      description='Sent to force animations to specific objects.'}
packetData.incoming[0x03A] = {name='Independ. Animation', description='Used for arbitrary battle animations that are unaccompanied by an action packet.'}
packetData.incoming[0x03C] = {name='Shop',                description='Displays items in a vendors shop.'}
packetData.incoming[0x03D] = {name='Shop Value/Sale',     description='Returns the value of an item or notice it has been sold.'}
packetData.incoming[0x03E] = {name='Open Buy/Sell',       description='Opens the buy/sell menu for vendors.'}
packetData.incoming[0x03F] = {name='Shop Buy Response',   description='Sent when you buy something from normal vendors.'}
packetData.incoming[0x041] = {name='Blacklist',           description='Contains player ID and name for blacklist.'}
packetData.incoming[0x042] = {name='Blacklist Command',   description='Sent in response to /blacklist add or /blacklist delete.'}
packetData.incoming[0x044] = {name='Job Info Extra',      description='Contains information about Automaton stats and set Blue Magic spells.'}
packetData.incoming[0x047] = {name='Translate Response',  description='Response to a translate request.'}
packetData.incoming[0x04B] = {name='Logout Acknowledge',  description='Acknowledges a logout attempt.'}
packetData.incoming[0x04B] = {name='Delivery Item',       description='Item in delivery box.'}
packetData.incoming[0x04C] = {name='Auction House Menu',  description='Sent when visiting auction counter.'}
packetData.incoming[0x04D] = {name='Servmes Resp',        description='Server response when someone requests it.'}
packetData.incoming[0x04F] = {name='Data Download 2',     description='The data that is sent to the client when it is "Downloading data...".'}
packetData.incoming[0x050] = {name='Equip',               description='Updates the characters equipment slots.'}
packetData.incoming[0x051] = {name='Model Change',        description='Info about equipment and appearance.'}
packetData.incoming[0x052] = {name='NPC Release',         description='Allows your PC to move after interacting with an NPC.'}
packetData.incoming[0x053] = {name='Logout Time',         description='The annoying message that tells how much time till you logout.'}
packetData.incoming[0x055] = {name='Key Item Log',        description='Updates your key item log on zone and when appropriate.'}
packetData.incoming[0x056] = {name='Quest/Mission Log',   description='Updates your quest and mission log on zone and when appropriate.'}
packetData.incoming[0x057] = {name='Weather Change',      description='Updates the weather effect when the weather changes.'}
packetData.incoming[0x058] = {name='Lock Target',         description='Locks your target.'}
packetData.incoming[0x05A] = {name='Server Emote',        description='This packet is the server\'s response to a client /emote p.'}
packetData.incoming[0x05B] = {name='Spawn',               description='Server packet sent when a new mob spawns in area.'}
packetData.incoming[0x05C] = {name='Dialogue Information',description='Used when all the information required for a menu cannot be fit in an NPC Interaction packet.'}
packetData.incoming[0x05E] = {name='Camp./Besieged Map',  description='Contains information about Campaign and Besieged status.'}
packetData.incoming[0x05F] = {name='Music Change',        description='Changes the current music.'}
packetData.incoming[0x061] = {name='Char Stats',          description='Packet contains a lot of data about your character\'s stats.'}
packetData.incoming[0x062] = {name='Skills Update',       description='Packet that shows your weapon and magic skill stats.'}
packetData.incoming[0x063] = {name='Set Update',          description='Frequently sent packet during battle that updates specific types of job information, like currently available/set automaton equipment and currently set BLU spells.'}
packetData.incoming[0x065] = {name='Repositioning',       description='Moves your character. Seems to be functionally idential to the Spawn packet'}
packetData.incoming[0x067] = {name='Pet Info',            description='Updates information about whether or not you have a pet and the TP, HP, etc. of the pet if appropriate.'}
packetData.incoming[0x068] = {name='Pet Status',          description='Updates information about whether or not you have a pet and the TP, HP, etc. of the pet if appropriate.'}
packetData.incoming[0x06F] = {name='Self Synth Result',   description='Results of an attempted synthesis process by yourself.'}
packetData.incoming[0x070] = {name='Others Synth Result', description='Results of an attempted synthesis process by others.'}
packetData.incoming[0x071] = {name='Campaign Map Info',   description='Populates the Campaign map.'}
packetData.incoming[0x075] = {name='Unity Start',         description='Creates the timer and glowing fence that accompanies Unity fights.'}
packetData.incoming[0x076] = {name='Party Buffs',         description='Packet updated every time a party member\'s buffs change.'}
packetData.incoming[0x078] = {name='Proposal',            description='Carries proposal information from a /propose or /nominate command.'}
packetData.incoming[0x079] = {name='Proposal Update',     description='Proposal update following a /vote command.'}
packetData.incoming[0x082] = {name='Guild Buy Response',  description='Buy an item from a guild.'}
packetData.incoming[0x083] = {name='Guild Inv List',      description='Provides the items, prices, and counts for guild inventories.'}
packetData.incoming[0x084] = {name='Guild Sell Response', description='Sell an item to a guild.'}
packetData.incoming[0x085] = {name='Guild Sale List',     description='Provides the items, prices, and counts for guild inventories.'}
packetData.incoming[0x086] = {name='Guild Open',          description='Sent to update the current guild status or open the guild buy/sell menu.'}
packetData.incoming[0x08C] = {name='Merits',              description='Contains all merit information. 3 packets are sent.'}
packetData.incoming[0x08D] = {name='Job Points',          description='Contains all job point information. 12 packets are sent.'}
packetData.incoming[0x0A0] = {name='Party Map Marker',    description='Marks where players are on your map.'}
packetData.incoming[0x0AA] = {name='Spell List',          description='Packet that shows the spells that you know.'}
packetData.incoming[0x0AC] = {name='Ability List',        description='Packet that shows your current abilities and traits.'}
packetData.incoming[0x0AD] = {name='MMM List',            description='Packet that shows your current Moblin Maze Mongers Vouchers and Runes.'}
packetData.incoming[0x0AE] = {name='Mount List',          description='Packet that shows your current mounts.'}
packetData.incoming[0x0B4] = {name='Seek AnonResp',       description='Server response sent after you put up party or anon flag.'}
packetData.incoming[0x0B5] = {name='Help Desk Open',      description='Sent when you open the Help Desk submenu.'}
packetData.incoming[0x0BF] = {name='Reservation Response',description='Sent to inform the client about the status of entry to an instanced area.'}
packetData.incoming[0x0C8] = {name='Party Struct Update', description='Updates all party member info in one struct. No player vital data (HP/MP/TP) or names are sent here.'}
packetData.incoming[0x0C9] = {name='Show Equip',          description='Shows another player your equipment after using the Check command.'}
packetData.incoming[0x0CA] = {name='Bazaar Message',      description='Shows another players bazaar message after using the Check command or sets your own on zoning.'}
packetData.incoming[0x0CC] = {name='Linkshell Message',   description='/lsmes text and headers.'}
packetData.incoming[0x0D2] = {name='Found Item',          description='This command shows an item found on defeated mob or from a Treasure Chest.'}
packetData.incoming[0x0D3] = {name='Lot/drop item',       description='Sent when someone casts a lot on an item or when the item drops to someone.'}
packetData.incoming[0x0DC] = {name='Party Invite',        description='Party Invite packet.'}
packetData.incoming[0x0DD] = {name='Party Member Update', description='Alliance/party member info - zone, HP%, HP% etc.'}
packetData.incoming[0x0DF] = {name='Char Update',         description='A packet sent from server which updates character HP, MP and TP.'}
packetData.incoming[0x0E0] = {name='Linkshell Equip',     description='Updates your linkshell menu with the current linkshell.'}
packetData.incoming[0x0E1] = {name='Party Member List',   description='Sent when you look at the party member list.'}
packetData.incoming[0x0E2] = {name='Char Info',           description='Sends name, HP, HP%, etc.'}
packetData.incoming[0x0F4] = {name='Widescan Mob',        description='Displays one monster.'}
packetData.incoming[0x0F5] = {name='Widescan Track',      description='Updates information when tracking a monster.'}
packetData.incoming[0x0F6] = {name='Widescan Mark',       description='Marks the start and ending of a widescan list.'}
packetData.incoming[0x0F9] = {name='Reraise Activation',  description='Reassigns targetable status on reraise activation?'}
packetData.incoming[0x0FA] = {name='Furniture Interact',  description='Confirms furniture manipulation.'}
packetData.incoming[0x105] = {name='Data Download 4',     description='The data that is sent to the client when it is "Downloading data...".'}
packetData.incoming[0x106] = {name='Bazaar Seller Info',  description='Information on the purchase sent to the buyer when they attempt to buy something.'}
packetData.incoming[0x107] = {name='Bazaar closed',       description='Tells you when a bazaar you are currently in has closed.'}
packetData.incoming[0x108] = {name='Data Download 5',     description='The data that is sent to the client when it is "Downloading data...".'}
packetData.incoming[0x109] = {name='Bazaar Purch. Info',  description='Information on the purchase sent to the buyer when the purchase is successful.'}
packetData.incoming[0x10A] = {name='Bazaar Buyer Info',   description='Information on the purchase sent to the seller when a sale is successful.'}
packetData.incoming[0x110] = {name='Sparks Update',       description='Occurs when you sparks increase and generates the related message.'}
packetData.incoming[0x111] = {name='Eminence Update',     description='Causes Records of Eminence messages.'}
packetData.incoming[0x112] = {name='RoE Quest Log',       description='Updates your RoE quest log on zone and when appropriate.'}
packetData.incoming[0x113] = {name='Currency Info',       description='Contains all currencies to be displayed in the currency menu.'}
packetData.incoming[0x115] = {name='Fish Bite Info',      description='Contains information about the fish that you hooked.'}
packetData.incoming[0x116] = {name='Equipset Build Response', description='Returned from the server when building a set.'}
packetData.incoming[0x117] = {name='Equipset Response',   description='Returned from the server after the /equipset command.'}
packetData.incoming[0x118] = {name='Currency 2 Info',     description='Contains all currencies to be displayed in the currency menu.'}
packetData.incoming[0x119] = {name='Ability Recasts',     description='Contains the currently available job abilities and their remaining recast times.'}

---------- DEFINE EVENTS----------------

-- Update player name for the user of the addon.
windower.register_event('login', function(name)
    player_name = name
end)

-- Initialise the addon.
windower.register_event('load',function()
	OnLoaded()
end)

-- Game Events in the form of packets, we can respond to.
windower.register_event(
'incoming chunk',
function (id,original,modified,is_injected,is_blocked)
    OnIncomingChunk(id, original, modifier, is_injected, is_blocked)
end)
    
-- Debugging
windower.register_event(
'outgoing chunk',
function (id,original,modified,is_injected,is_blocked)
    OnOutgoingChunk(id, original, modifier, is_injected, is_blocked)
end)

-- Commands to help interact with the addon.
windower.register_event(
    "addon command",
    function(cmd, ...)
		OnCommandRecieved(cmd, ...)
    end
)

windower.register_event('prerender', function()
    local info = windower.ffxi.get_info()

	-- Hide UI when Zoning
	-- Incoming Chunks will resume it, if it's set to be visible.
    if not info.logged_in or not windower.ffxi.get_player() or zoning_bool then
        box:hide()
        return
    end
end)

---------- ADDON IMPLEMENTATION ----------------

function OnIncomingChunk(id, original, modifier, is_injected, is_blocked)
   
	-- NOTE: When you gain ichor etc, this is not hit, its a different ID

	-- Update Our internal readings of the values pulled from these menus.
	
	-- Currency 1
	if id == 0x113 then
		local parsePackets = packets.parse('incoming', original)
		if DEBUG then
			Printf("Incoming Currency 1")
		end

		UpdateTableValues(parsePackets)
		if DEBUG then
			Printf("End Currency 1")
		end
	end

	-- Currency 2
	if id == 0x118 then
		local parsePackets = packets.parse('incoming', original)	
		if DEBUG then
			Printf("Incoming Currency 2")
		end
		UpdateTableValues(parsePackets)
		if DEBUG then
			Printf("End Currency 2")
		end
	end

	-- Detected a change in one of our interested values.
	-- Update things accordingly.

	if id == 0xB then
        zoning_bool = true
    elseif id == 0xA then
        zoning_bool = false
    end

	if packetsToRefreshUI:contains(id) then
		if DEBUG then
			Printf("Refreshing UI via: PacketID: "..tostring(id).." Name: "..tostring(packetData.incoming[id].name)..', '..tostring(packetData.incoming[id].description))
		end
		RefreshValues()
	end

	if DEBUG then
		if not packetDataToIgnore:contains(id) then
			if packetData.incoming[id] then
				Printf("PacketID: "..tostring(id).." Name: "..tostring(packetData.incoming[id].name)..', '..tostring(packetData.incoming[id].description))
			end
		end
	end
end

function OnOutgoingChunk(id, original, modifier, is_injected, is_blocked)
	--if id == 0x016 then
	--	Printf("Outgoing Update Request")
	--	RefreshValues()
	--end
	--
	--if id ~= 21 then
	--	Printf("Outgoing ID: "..tostring(id))
	--end
end

function OnLoaded()
	-- Initialise values.
	box:color(255,255,255)
	RefreshValues()
end

function OnCommandRecieved(command, ...)
	local args = T{...}
	local HasAdditionalArgs = #args > 0
	local fullCommand = command
	for i = 1, #args do
		--windower.add_to_chat(207, "Arg "..i..": "..args[i])
		fullCommand = fullCommand.." "..args[i]
	end

	if command == "show" then
		box:show()
		m_bUIEnabled = true
	elseif command == "hide" then		
		box:hide()
		m_bUIEnabled = false	
	elseif command == 'cycleui' then
		local numCategories = #m_categories
		local oldIndex = m_categoryIndex
		if DEBUG then
			local categoryToString = m_categories[oldIndex]
			Printf("OldIndex: "..tostring(oldIndex)..' ['..tostring(CurrencyResultsCategorised[categoryToString].Name)..']')
		end
		m_categoryIndex = m_categoryIndex + 1
		if m_categoryIndex > numCategories then
			m_categoryIndex = 1
		end
		if DEBUG then
			local categoryToString = m_categories[m_categoryIndex]
			Printf("NewIndex: "..tostring(m_categoryIndex)..' ['..tostring(CurrencyResultsCategorised[categoryToString].Name)..']')
		end

		settings.category_index = m_categoryIndex
		config.save(settings, 'global')
		UpdateHUD()
	elseif command == "toggledebug" then
		if DEBUG then
			DEBUG = false
			Printf("DebugOff")
			box:color(255,255,255)
			box:update(defaults)
		else
			DEBUG = true
			Printf("DebugOn")	
			box:color(255,0,0)
			box:update(defaults)
		end
	elseif command == 'testing' then
		-- Output results which will end up on a UI somewhere.
		--for k, v in pairs(CurrencyResults) do
		--	Printf("K: "..tostring(k)..", Value: "..tostring(v))
		--end
	elseif command == 'help' then
		OutputHelp()
	elseif command == "refresh" then
		RefreshValues()
	elseif command == "save" then
		config.save(settings)
	end
end

---------- CORE ----------------

function UpdateTableValues(packet)
	-- If a value is not updating correctly, chances are it's not an eact match to packets/fields.lua'
	for currencyCategoryKey, currencyCategoryTable in pairs(CurrencyResultsCategorised) do
		for k, v in pairs(currencyCategoryTable) do
			local Value = comma_value(packet[k])
			if Value ~= nil then
				--Printf("Key: "..tostring(k)..", Value: "..tostring(Value))			
				CurrencyResultsCategorised[currencyCategoryKey][k] = Value
			end
		end
	end

	UpdateHUD()
end

function RefreshValues()

	-- Essentially all this does, is emulate openning the currency menus, so that we get the packet
	-- with the data that is associated with those menus.
	if windower.ffxi.get_info().logged_in then
        local results = false
		local bInject = false
        for id, packet in pairs(requests) do
			--Printf("Request: "..tostring(id))
            local fields = packets.fields('incoming', id)

            for field in fields:it() do
                if field.type ~= 'data' then
					-- THE FORMATTING CAN STRIP SPACES AND FORCE LOWER CASE.
                    local str = field.label --:gsub('[%s%p]', '') --:lower()

					-- Determine whether this currency actually exists in game
					-- Compared to our search criteria.
					
					for currencyCategoryKey, currencyCategoryTable in pairs(CurrencyResultsCategorised) do
						for k, v in pairs(currencyCategoryTable) do
							if str:find(k) then
								bInject = true
								break
							end
						end
						if bInject then
							break
						end
					end

					if bInject then
						break
					end
                end
            end

			if bInject then
				--Printf("Injecting")
			    packets.inject(packet)
                results = true
			else 
				Printf("NOT Injecting - Failed to find field in currency results table.")
            end
        end
        return results
    end
end

---------- HUD ----------------

function UpdateHUD()
	-- Push values to HUD accordingly.

	if CurrencyResultsCategorised == nil then
		return
	end

	local currentCategory = m_categories[m_categoryIndex]
	if currentCategory == nil then
		return
	end

	-- Prefix Bar with the current category.
	local categoryTypeText = CurrencyResultsCategorised[currentCategory]
	if categoryTypeText == nil then
		return
	end

	-- NOTE: Be nice if I could use the table index as a string, but can't find a way to make that possible in lua.
	if categoryTypeText.Name == nil then
		return
	end

	local bInjectAll = string.find(categoryTypeText.Name, "All") or nil
	local combinedText = {}
	table.insert(combinedText, categoryTypeText.Name..': ')

	-- NOTE: does lua support continue ?
	for currencyCategoryKey, currencyCategoryTable in pairs(CurrencyResultsCategorised) do

		local localCategoryName = CurrencyResultsCategorised[currencyCategoryKey].Name
		local bCategoryMatches = (localCategoryName == categoryTypeText.Name) or nil
		if bInjectAll == 1 or bCategoryMatches == true then
			for k, v in pairs(currencyCategoryTable) do
				-- Ignore Name case.
				if tostring(k) ~= "Name" then
					-- Only inject if the category matches or it's set to ALL			
					local injectedText = ''..m_headingCol..tostring(k)..m_preCol..': '..tostring(v)..' '
					table.insert(combinedText, injectedText)
				end
			end
		end
	end

	local Result = table.concat(combinedText)

	box:text(tostring(Result))

	if m_bUIEnabled then
		box:show()
	end
end

---------- UTILITY ----------------

function Printf(info)
	windower.add_to_chat(207, info)
end

function PrintTable(prefix, tableToPrint)
	if tableToPrint == nil then
		Printf("Cannot print null table")
		return
	end

	for k, v in pairs(tableToPrint) do
		Printf("["..prefix.."] TableDebug: "..tostring(k)..", V: "..tostring(v))
	end
end

function comma_value(n) -- credit http://richard.warburton.it
	if n == nil then
		return nil
	end

    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function concat_strings(s)
    local t = { }
    for k,v in ipairs(s) do
        t[#t+1] = tostring(v)
    end
    return table.concat(t,"\n")
end

function OutputHelp()
	local HelpTable =
	{
		'\nWelcome to CurrencyWatcher Help Info\n',
		' Simply drag the bar to where you want the info displayed.\n',
		'  Useful Commands\n',
		'   //cw show - Makes the bar visible\n',
		'   //cw hide - Makes the bar invisible\n',
		'   //cw refresh - Forces a UI Update\n',
		'   //cw toggledebug - Will output packet info to help identify if all cases are accounted for. Bottom Left goes red in debug mode.\n',
		'   //cw cycleui - this will filter the bar to only show relevant currency information relating to that category.'
		'   //cw help - Brings this menu back.\n',
	}
	local HelpText = concat_strings(HelpTable)
	Printf(HelpText)
end

--Copyright © 2024, Lordmatics
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.