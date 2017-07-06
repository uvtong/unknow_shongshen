local handler = {}
local mt = { __index = handler }

function handler.new (request, response, cmd)
	return setmetatable ({
		init_func = {},
		request = request,
		response = response,
		cmd = cmd,
	}, mt)
end

local function merge (dest, t)
	if not dest or not t then return end
	for k, v in pairs (t) do
		dest[k] = v
	end
end

function handler:add ( expand )
	if not self.request and expand.request then self.request = {} end
	if not self.response and expand.response then self.response = {} end
	if not self.cmd and expand.cmd then self.cmd = {} end
	merge( self.request, expand.request )
	merge( self.response, expand.response )
	merge( self.cmd , expand.cmd )
end

function handler:init (f)
	table.insert (self.init_func, f)
end


function handler:register (user)
	for _, f in pairs (self.init_func) do
		f (user)
	end

	merge (user.REQUEST, self.request)
	merge (user.RESPONSE, self.response)
	merge (user.CMD, self.cmd)
end

local function clean (dest, t)
	if not dest or not t then return end
	for k, _ in pairs (t) do
		dest[k] = nil
	end
end

function handler:unregister (user)
	clean (user.REQUEST, self.request)
	clean (user.RESPONSE, self.response)
	clean (user.CMD, self.cmd)
end

return handler
