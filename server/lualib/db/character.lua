local syslog = require "syslog"
local packer = require "db.packer"
local print_r = require "utils.print_r"

local character = {}
local connection_handler

function character.init (ch)
	connection_handler = ch
end

local function make_list_key (account)
	local major = account // 100
	local minor = account % 100
	return connection_handler (account), string.format ("char-list:%d", major), minor
end

local function make_character_key (id)
	local major = id // 100
	local minor = id % 100
	return connection_handler (id), string.format ("character:%d", major), minor
end

local function make_name_key (name)
	return connection_handler (name), "char-name", name
end

function character.reserve (id, name)
	local connection, key, field = make_name_key (name)
	print("--character.lua reserve:",id,name,connection,key,field)
	if connection then
		print("--connection--------------------------------------------")
		print_r(connection)
		print("--------------------------------------------------------")
	end
	assert (connection:hsetnx (key, field, id) ~= 0)
	return id
end

function character.save (id, data)
	connection, key, field = make_character_key (id)
	connection:hset (key, field, data)
end

function character.load (id)
	connection, key, field = make_character_key (id)
	print("--character.lua load:",tostring(id),connection,key,field)
	local data = connection:hget (key, field) or error ()
	return data
end

function character.list (account)
	local connection, key, field = make_list_key (account)
	print("--character.lua list 1:",account,connection,key,field)
	local v = connection:hget (key, field) or error ()
	print("--character.lua list 2:",v)

	return v
end

function character.savelist (id, data)
	connection, key, field = make_list_key (id)
	connection:hset (key, field, data)
end

return character

