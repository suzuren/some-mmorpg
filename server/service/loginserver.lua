local skynet = require "skynet"
local socket = require "socket"

local syslog = require "syslog"
local config = require "config.system"


local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local CMD = {}

function CMD.open (conf)
	for i = 1, conf.slave do
		local s = skynet.newservice ("loginslave")
		skynet.call (s, "lua", "init", skynet.self (), i, conf)
		table.insert (slave, s)
	end
	nslave = #slave

	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	local sock = socket.listen (host, port)

	syslog.noticef ("loginserver listen on %s:%d", host, port) -- mmorpg/server/cnfig/loginserver.lua
	--socket.start(id , accept) accept 是一个函数。每当一个监听的 id 对应的 socket 上有连接接入的时候，
	--都会调用 accept 函数。这个函数会得到接入连接的 id 以及 ip 地址。你可以做后续操作。
	local balance = 1
	socket.start (sock, function (fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > nslave then balance = 1 end

		skynet.call (s, "lua", "auth", fd, addr)
	end)
end

function CMD.save_session (account, key, challenge)
	session = session_id
	session_id = session_id + 1

	s = slave[(session % nslave) + 1]
	print("-- loginserver.lua CMD.save_session:",s,session,account)
	skynet.call (s, "lua", "save_session", session, account, key, challenge)
	return session
end

function CMD.challenge (session, challenge)
	s = slave[(session % nslave) + 1]
	print("-- loginserver.lua CMD.challenge:",s,session)
	return skynet.call (s, "lua", "challenge", session, challenge)
end

function CMD.verify (session, token)
	local s = slave[(session % nslave) + 1]
	print("-- loginserver.lua CMD.verify:",s,session)
	return skynet.call (s, "lua", "verify", session, token)
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		print("-- loginserver.lua skynet.start:",command)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
