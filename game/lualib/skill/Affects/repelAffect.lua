local vector3 = require "vector3"
local Affect = require "skill.Affects.Affect"
local repelAffect = class("repelAffect",Affect)
local transfrom = require "entity.transfrom"

function repelAffect:ctor(owner,source,data)
	self.super.ctor(self,owner,source,data)
	self.effectId = data[3] or 0
	self.distance = data[2] or 0
	self.speed = 6 
	self.effectTime = math.floor(1000 * self.distance / self.speed) 
end

function repelAffect:onEnter()
	self.super.onEnter(self)
	self.owner.curActionState = ActionState.forcemove
	local dir = vector3.create()
	dir:set(self.owner.pos.x,0,self.owner.pos.z)
	dir:sub(self.source.pos)
	dir:normalize()
	dir:mul_num(self.distance)	
	local dst = vector3.create()
	dst:set(self.owner.pos.x,0,self.owner.pos.z)
	dst:add(dir)
	self.owner.setTargetVar(transfrom.new(dst,nil))
end

function repelAffect:onExec(dt)
	self.effectTime = self.effectTime - dt
	if self.effectTime < 0 then
		self:onExit()
	end
end

function repelAffect:onExit()
	self.owner:stand()
	self.super.onExit(self)
end

return repelAffect
