local skynet = require "skynet"
local snax = require "snax"
require "skynet.manager"	-- import skynet.monitor
local sprotoloader = require "sprotoloader"

local game_config = require "config.gameserver"
local login_config = require "config.loginserver"
local max_client = 64

skynet.start(function()
			
	math.randomseed(skynet.now())
	local monitor = skynet.monitor "simplemonitor"
	
	skynet.uniqueservice("protod")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",8000)
	skynet.uniqueservice("globaldata")
	--启动数据库服务
	local database = skynet.uniqueservice ("database")
	local bg = skynet.uniqueservice ("bgsavemysql", database)
	skynet.call(monitor, "lua", "watch", bg)
	-----------------------------------------------------------
	------------
	--启动web server 服务
	skynet.uniqueservice("simpleweb")
	skynet.uniqueservice("match")
	--启动聊天服务
	skynet.uniqueservice("chatserver")
	--启动CD时间服务
	local CD = snax.uniqueservice("cddown")
	--启动activity活动服务
	snax.uniqueservice("activity")
	--启动服务管理服务
	snax.uniqueservice("servermanager")

	local loginserver = skynet.newservice("loginserver")
	skynet.call(loginserver,"lua","open",login_config)
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", game_config)
	
	--启动GM服务
	snax.uniqueservice("gm", watchdog)

	
	CD.post.Start()	

	skynet.exit()
end)
