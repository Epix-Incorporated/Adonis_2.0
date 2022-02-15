--!strict
--[[
	Description: Contains bytecode/loadstring-related functionality
	Author: github@ccuser44
	Date: 15.2.2022
--]]

type dictionary = { [string]: any }
type func = (...any?) -> (...any?)

local globalEnv: dictionary = {
	-- // Libraries
	coroutine = coroutine,
	debug = debug,
	math = math,
	os = os,
	string = string,
	table = table,
	utf8 = utf8,
	bit32 = bit32,
	task = task,

	-- // Lua globals
	assert = assert,
	collectgarbage = function(action: string): number -- Use gcinfo instead
		assert(type(action) == "string", "invalid argument #1 to 'collectgarbage' (string expected, got "..type(action)..")")
		assert(action == "count", "collectgarbage must be called with 'count'; use gcinfo() instead")

		return gcinfo()
	end,
	error = error,
	getmetatable = getmetatable,
	ipairs = ipairs,
	newproxy = newproxy,
	next = next,
	pairs = pairs,
	pcall = pcall,
	print = print,
	rawequal = rawequal,
	rawget = rawget,
	rawset = rawset,
	select = select,
	setmetatable = setmetatable,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	xpcall = xpcall,
	warn = warn,
	gcinfo = gcinfo,
	_G = _G,
	_VERSION = _VERSION,

	-- // Roblox globals
	settings = settings,
	time = time,
	typeof = typeof,
	UserSettings = UserSettings,
	require = require,
	game = game,
	workspace = workspace,
	shared = shared,

	-- // Deprecated Roblox globals (Please don't use, use the alternative instead)
	delay = task.delay,-- Use task.delay instead
	spawn = task.defer,-- Use task.spawn instead
	wait = task.wait,-- Use task.wait instead
	elapsedTime = os.clock,-- Use os.clock instead
	stats = function(): Stats
		return game:GetService("Stats")
	end,-- Use game:GetService("Stats") instead
	tick = tick,-- Use os.time or os.clock instead

	-- // Roblox datatypes
	Axes = Axes,
	BrickColor = BrickColor,
	CatalogSearchParams = CatalogSearchParams,
	CFrame = CFrame,
	Color3 = Color3,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	DateTime = DateTime,
	DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo,
	Enum = Enum,
	Faces = Faces,
	FloatCurveKey = FloatCurveKey,
	Instance = Instance,
	NumberRange = NumberRange,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	OverlapParams = OverlapParams,
	PathWaypoint = PathWaypoint,
	PhysicalProperties = PhysicalProperties,
	Random = Random,
	Ray = Ray,
	RaycastParams = RaycastParams,
	Rect = Rect,
	Region3 = Region3,
	Region3int16 = Region3int16,
	TweenInfo = TweenInfo,
	UDim = UDim,
	UDim2 = UDim2,
	Vector2 = Vector2,
	Vector2int16 = Vector2int16,
	Vector3 = Vector3,
	Vector3int16 = Vector3int16,
}

table.freeze(globalEnv)

return function()
	local env: dictionary = {}

	for k: string, v: any in pairs(globalEnv) do
		env[k] = v
	end

	env._ENV = env :: dictionary

	env["getf".."env"] = function(target: (func | number)?): dictionary
		assert(type(target) == "number" or type(target) == "function" or type(target) == "nil", "invalid argument #1 to 'getf".."env' (number expected, got "..type(target)..")")
		assert(type(target) == "number" and target >= 0 or type(target) ~= "number", "invalid argument #1 to 'getf".."env' (level must be non-negative)")

		return env
	end

	env["setf".."env"] = function(target: func | number, newEnv: dictionary): ()
		assert(type(newEnv) == "table", "invalid argument #2 to 'setfenv' (table expected, got "..type(newEnv)..")")
		assert(type(target) == "number" or type(target) == "function", "invalid argument #1 to 'setf".."env' (number expected, got "..type(target)..")")
		assert(type(target) == "number" and target >= 0, "invalid argument #1 to 'setfenv' (level must be non-negative)")

		table.clear(env)

		for k: string, v: any in pairs(newEnv) do
			if type(k) == "string" then
				env[k] = v
			end
		end
	end

	setmetatable(env, table.freeze({
		__index = globalEnv,
		__metatable = "The metatable is locked"
	}))

	return env
end
