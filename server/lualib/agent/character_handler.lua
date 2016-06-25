local skynet = require "skynet"
local sharedata = require "sharedata"

local syslog = require "syslog"
local dbpacker = require "db.packer"
local handler = require "agent.handler"
local uuid = require "uuid"

local print_r = require "utils.print_r"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd

handler:init (function (u)
	user = u
	database = skynet.uniqueservice ("database")
	gdd = sharedata.query "gdd"
end)

local function load_list (account)
	local list = skynet.call (database, "lua", "character", "list", account)
	print ("-- character_handler.lua load_list fun 1:", list)
	if list then
		list = dbpacker.unpack (list)
	else
		list = {}
	end
	print ("-- character_handler.lua load_list fun 2:", list)
	return list
end

local function check_character (account, id)
	print ("-- character_handler.lua check_character fun:", account, id)
	local list = load_list (account)
	if list then
		print("--list--------------------------------------------------")
		print_r(list)
		print("--------------------------------------------------------")
	end
	for _, v in pairs (list) do
		print ("list", v)
		if v == id then return true end
	end
	return false
end

function REQUEST.character_list ()
	local list = load_list (user.account)
	--print ("-- character_handler.lua character_list fun:", list)
	if list then
		print("--list--------------------------------------------------")
		print_r(list)
		print("--------------------------------------------------------")
	end
	local character = {}
	for _, id in pairs (list) do
		local c = skynet.call (database, "lua", "character", "load", id)
		if c then
			print ("-- character_handler.lua character_list fun:", c)
			character[id] = dbpacker.unpack (c)
		end
	end
	return { character = character }
end

local function create (name, race, class)
	assert (name and race and class)
	assert (#name > 2 and #name < 24)
	assert (gdd.class[class])

	local r = gdd.race[race] or error ()

	local character = { 
		general = {
			name = name,
			race = race,
			class = class,
			map = r.home,
		}, 
		attribute = {
			level = 1,
			exp = 0,
		},
		movement = {
			mode = 0,
			pos = { x = r.pos_x, y = r.pos_y, z = r.pos_z, o = r.pos_o },
		},
	}
	return character
end

function REQUEST.character_create (args)
	if args then
		print("--args--------------------------------------------------")
		print_r(args)
		print("--------------------------------------------------------")
	end
	for k, v in pairs (args) do print (k, v) end
	local c = args.character or error ("invalid argument")

	local character = create (c.name, c.race, c.class)

	if character then
		print("--character--------------------------------------------------")
		print_r(character)
		print("--------------------------------------------------------")
	end

	local id = skynet.call (database, "lua", "character", "reserve", uuid.gen (), c.name)
	print("--character_handler.lua character_create:",id)
	if not id then return {} end

	character.id = id



	local json = dbpacker.pack (character)
	skynet.call (database, "lua", "character", "save", id, json)

	local list = load_list (user.account)
	table.insert (list, id)
	json = dbpacker.pack (list)
	skynet.call (database, "lua", "character", "savelist", user.account, json)

	return { character = character }
end

function REQUEST.character_pick (args)
	local id = args.id or error ()
	print("--character_handler.lua character_pick:",user.account,id)
	assert (check_character (user.account, id))

	local c = skynet.call (database, "lua", "character", "load", id) or error ()
	local character = dbpacker.unpack (c)
	user.character = character

	local world = skynet.uniqueservice ("world")
	skynet.call (world, "lua", "character_enter", id)

	return { character = character }
end

attribute_string = {
	"health",
	"strength",
	"stamina",
}

function handler.init (character)
	local temp_attribute = {
		[1] = {},
		[2] = {},
	}
	local attribute_count = #temp_attribute

	character.runtime = {
		temp_attribute = temp_attribute,
		attribute = temp_attribute[attribute_count],
	}

	local class = character.general.class
	local race = character.general.race
	local level = character.attribute.level

	local gda = gdd.attribute

	local base = temp_attribute[1]
	base.health_max = gda.health_max[class][level]
	base.strength = gda.strength[race][level]
	base.stamina = gda.stamina[race][level]
	base.attack_power = 0
	
	local last = temp_attribute[attribute_count - 1]
	local final = temp_attribute[attribute_count]

	if last.stamina >= 20 then
		final.health_max = last.health_max + 20 + (last.stamina - 20) * 10
	else
		final.health_max = last.health_max + last.stamina
	end
	final.strength = last.strength
	final.stamina = last.stamina
	final.attack_power = last.attack_power + final.strength

	local attribute = setmetatable (character.attribute, { __index = character.runtime.attribute })

	local health = attribute.health
	if not health or health > attribute.health_max then
		attribute.health = attribute.health_max
	end

if handler then
print("--handler-----------------------------------------------")
print_r(handler)
print("--------------------------------------------------------")
end
end

function handler.save (character)
	if not character then return end

	local runtime = character.runtime
	character.runtime = nil
	local data = dbpacker.pack (character)
	character.runtime = runtime
	skynet.call (database, "lua", "character", "save", character.id, data)
end


return handler

