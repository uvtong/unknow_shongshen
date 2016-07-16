#!/usr/bin/env lua
---Sample application to read a XML file and print it on the terminal.
--@author Manoel Campos da Silva Filho - http://manoelcampos.com
dofile("../3rd/LuaXMLlib/xml.lua")
dofile("../3rd/LuaXMLlib/handler.lua")
local filename = "./lualib/gamedata/BuffRepository.xml"
local xmltext = ""
local f, e = io.open(filename, "r")
if f then
  xmltext = f:read("*a")
else
  error(e)
end
local xmlhandler = simpleTreeHandler()
local xmlparser = xmlParser(xmlhandler)
xmlparser:parse(xmltext)

local buffTable = {}
for k, p in pairs(xmlhandler.root.BuffRepository.info) do
	local tmpTb = {}
	for _i,_v in pairs(p)do
		if _i == "_attr" then
			tmpTb.id = tonumber(_v.id)
		else
			if string.match(_i,"n32%a+") then
				tmpTb[_i] = tonumber(_v)
			elseif string.match(_i,"b%a+") then
				if tonumber(_v) == 0 then
					tmpTb[_i] = false
				else
					tmpTb[_i] = true
				end
			else
				tmpTb[_i] = _v
			end 
		end
	end
	if tmpTb.n32LimitCount <= 0 then
                tmpTb.n32LimitCount = 9999
        end
        if tmpTb.n32LimitTime <= 0 then
                tmpTb.n32limitTime  = 1000
        end
	tmpTb.seriesId = Macro_GetBuffSeriesId(tmpTb.id)
	tmpTb.level = Macro_GetBuffLevel(tmpTb.id) 
	assert(buffTable[tmpTb.id]==nil, "BuffRespository has two more id: " .. tmpTb.id)
	buffTable[tmpTb.id] = tmpTb
end

--for _k,_v in pairs(skillTable) do
--	print(_k,_v.id,_v)
--end
return buffTable