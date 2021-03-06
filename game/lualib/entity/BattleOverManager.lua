local skynet = require "skynet"
local snax = require "snax"

local CardMethod = require "agent.cards_method"
local EntityManager = require "entity.EntityManager"
local DropManager = require "drop.DropManager"

local BattleOverManager = class("BattleOverManager")

local S = 300
local N = 32
local K = 1
local database
function BattleOverManager:ctor()
	self.RedHomeBuilding = nil
	self.BlueHomeBuilding = nil
	self.RedKillNum = 0
	self.BlueKillNum = 0
	self.RestTime = 0
	self.OverRes = 0
	self.MapDat = nil
end

function BattleOverManager:init( mapDat )
	database = skynet.uniqueservice("database")
	self.MapDat = mapDat
	self.RestTime = self.MapDat.n32Time * 1000
end

function BattleOverManager:update( dt )
	if self.OverRes ~= 0 then return end
	self.RestTime = self.RestTime - dt
	repeat
		if self.RedHomeBuilding:isDead() then
			self.OverRes = 1	--蓝方胜
			break
		end
		if self.BlueHomeBuilding:isDead() then
			self.OverRes = 2	--红方胜
			break
		end
		if self.RedKillNum >= self.MapDat.n32Kills then
			self.OverRes = 2	--红方胜
			break
		end
		if self.BlueKillNum >= self.MapDat.n32Kills then
			self.OverRes = 1	--蓝方胜
			break
		end
		if self.RestTime <= 0 then
			if self.RedKillNum > self.BlueKillNum then
				self.OverRes = 2	--红方胜
			elseif self.RedKillNum < self.BlueKillNum then
				self.OverRes = 1	--蓝方胜
			else
				self.OverRes = 3	--平局
			end
			break
		end
	until true
	if self.OverRes ~= 0 then
		print ('战斗结束')
		local winners, failers, redRunAway, blueRunAway = self:calcRes()
		self:giveResult()
		self:sendResult(winners, failers)
		self:recordResult(self.OverRes)
		--任务推进
		self:closeRoom()
	end
end

function BattleOverManager:calcRes()
	local redPlayers = {}
	local bluePlayers = {}
	local redRunAway = {}
	local blueRunAway = {}
	for k, v in pairs(EntityManager.entityList) do
		if v.entityType == EntityType.player then
			v.BattleGains = {items = {}, exp=0, gold=0,win=2}
			--win 0:胜 1:负 2:平局 3:逃跑
			v.BattleGains.kills = v.HonorData[4]
			v.BattleGains.deads = v.HonorData[5]
			if v:isRed() then
				if v:getOffLineTime() > 90 then
					table.insert(redRunAway, v)
				elseif v:getOffLineTime() > 15 then
					local isOnLine = skynet.call(v.agent, "lua", "isOnLine")
					if not isOnLine then
						table.insert(redRunAway, v)
					else
						table.insert(redPlayers, v)
					end
				else
					table.insert(redPlayers, v)
				end
			else
				if v:getOffLineTime() > 90 then
					table.insert(blueRunAway, v)
				elseif v:getOffLineTime() > 15 then
					local isOnLine = skynet.call(v.agent, "lua", "isOnLine")
					if not isOnLine then
						table.insert(blueRunAway, v)
					else
						table.insert(bluePlayers, v)
					end

				else
					table.insert(bluePlayers, v)
				end
			end
		end
	end
	local winners = {}
	local failers = {}
	if self.OverRes == 1 then
		winners = bluePlayers
		failers = redPlayers
	elseif self.OverRes == 2 then
		winners = redPlayers
		failers = bluePlayers
	end
	--道具
	local activity = snax.uniqueservice("activity")
	for k, v in pairs(winners) do
		local arena = Quest.Arena[v.accountLevel]
		local val = activity.req.getValue(v.account_id, ActivityAccountType.PvpWinTimes)
		if val < arena.VictoryRewardLimit then
			v.BattleGains.items = usePackageItem(arena.VictoryReward, v.accountLevel)
		end
	end
	--金币
	for k, v in pairs(redPlayers) do
		local arena = Quest.Arena[v.accountLevel]
		local val = activity.req.getValue(v.account_id, ActivityAccountType.PvpTimes)
		if val < arena.GoldRewardLimit then
			v.BattleGains.gold = arena.GoldReward
		end
	end
	for k, v in pairs(bluePlayers) do
		local arena = Quest.Arena[v.accountLevel]
		local val = activity.req.getValue(v.account_id, ActivityAccountType.PvpTimes)
		if val < arena.GoldRewardLimit then
			v.BattleGains.gold = arena.GoldReward
		end
	end
	--经验
	local redScore = 0
	local blueScore = 0
	for k, v in pairs(redPlayers) do
		redScore = redScore + v.accountExp
	end
	for k, v in pairs(redRunAway) do
		redScore = redScore + v.accountExp
		v.BattleGains.win = 3
	end

	for k, v in pairs(bluePlayers) do
		blueScore = blueScore + v.accountExp
	end
	for k, v in pairs(blueRunAway) do
		blueScore = blueScore + v.accountExp
		v.BattleGains.win = 3
	end
	local pRedStar = 1 / (1 + 10 ^ ((blueScore - redScore) / S))
	local pBlueStar = 1 / (1 + 10 ^ ((redScore - blueScore) / S))
	local winExp, failExp
	if self.OverRes == 1 then
		winExp = 2 * N * K * (1 - pBlueStar)
		failExp = 2 * N * K * (-pRedStar)
	elseif self.OverRes == 2 then
		winExp = 2 * N * K * (1 - pRedStar)
		failExp = 2 * N * K * (-pBlueStar)
	end

	for k, v in pairs(winners) do
		v.BattleGains.win = 0
		v.BattleGains.cardId = v.attDat.id
		v.BattleGains.exp = math.ceil( winExp )
	end
	for k, v in pairs(failers) do
		v.BattleGains.win = 1
		v.BattleGains.cardId = v.attDat.id
		v.BattleGains.exp = math.ceil( failExp )
	end
	if self.OverRes == 1 then
		for k, v in pairs(redRunAway) do
			v.BattleGains.cardId = v.attDat.id
			v.BattleGains.exp = math.ceil( failExp )
		end
	elseif self.OverRes == 2 then
		for k, v in pairs(blueRunAway) do
			v.BattleGains.cardId = v.attDat.id
			v.BattleGains.exp = math.ceil( failExp )
		end
	end
	return winners, failers, redRunAway, blueRunAway
end

function BattleOverManager:giveResult()
	for k, v in pairs(EntityManager.entityList) do
		if v.entityType == EntityType.player then
			print('结算 :', v.BattleGains)
			skynet.call(v.agent, "lua", "giveBattleGains", v.BattleGains)
		end
	end
end


function BattleOverManager:sendResult(winners, failers)
	local ret = {}
	for k, v in pairs(EntityManager.entityList) do
		if v.entityType == EntityType.player then
			local r = {accountid = v.account_id, serverid=v.serverId}
			r.result = v.BattleGains.win
			r.beDamage = v.HonorData[2]
			r.damage = v.HonorData[1]
			r.score = v.BattleGains.exp
			r.gold = v.BattleGains.gold
			r.kills = v.HonorData[4]
			r.deads = v.HonorData[5]
			r.helps = v.HonorData[3]
			r.items = {}
			for p, q in pairs(v.BattleGains.items) do
				table.insert(r.items, {x=p,y=q})
			end
			r.skills = {}
			for p, q in pairs(v.skillTable) do
				table.insert(r.skills, {x=p,y=q})
			end
		
			table.insert(ret , r)
		end
	end
	print( ret )
	EntityManager:sendToAllPlayers("battleOver", {accounts = ret})
end

--战斗记录
function BattleOverManager:recordResult(winflag)
	local tb = {}
	for k, v in pairs(EntityManager.entityList) do
		if v.entityType == EntityType.player then
			local item  = {}
			item.account_id = v.account_id --账号id
			item.nickName = v.nickName --昵称
			item.color = v.color    --颜色
			item.winflag = v.BattleGains.win
			item.heroId = v.attDat.id --英雄id
			item.skillTable = {}
			for k,v in pairs(v.skillTable) do
				table.insert(item.skillTable,k+v-1)
			end
			item.assistNum = v.HonorData[3] --助攻数
			item.killNum = v.HonorData[4] --击杀数
			item.deadthNum = v.HonorData[5] --死亡数
			item.time = os.time()
			table.insert(tb,item)	
		end
	end
	local accounts = {}
	for k,v in pairs(EntityManager.entityList) do
		if v.entityType == EntityType.player then
			table.insert(accounts,v.account_id)
		end
	end			
	skynet.call(database, "lua", "fightrecords", "add", accounts,tb)
end
function BattleOverManager:closeRoom()
 	print("close room")
	local sm = snax.uniqueservice("servermanager")
	for k, v in pairs(EntityManager.entityList) do
		if v.clear_coroutine ~= nil then 
			v:clear_coroutine()
			if v.entityType == EntityType.player then
				if v.agent then
					skynet.call(v.agent, "lua", "leaveMap", skynet.self())
				end
			end
		end
	end
                                                                                               
        sm.post.roomend(skynet.self())
	skynet.exit()
end

return BattleOverManager.new()
