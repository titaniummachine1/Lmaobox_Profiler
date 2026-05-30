--[[
    Tick vs frame — separate flame_graphs for tick.* and frame.* files.
]]

local TAG = "profiler_dual_context"

local function cleanup()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Draw", TAG)
	callbacks.Unregister("Unload", TAG)
end

if _G.PROFILER_DUAL_LOADED then
	cleanup()
	_G.PROFILER_DUAL_LOADED = false
end

local Profiler = require("Profiler")
Profiler.SetEnabled(true)
_G.PROFILER_DUAL_LOADED = true

callbacks.Register("CreateMove", TAG, function(cmd)
	Profiler.BeginTick()
	Profiler.Begin("Physics")
	for i = 1, 12000 do
		local _ = math.tan(i * 0.01)
	end
	Profiler.End("Physics")
	Profiler.EndTick()
end)

callbacks.Register("Draw", TAG, function()
	Profiler.BeginFrame()
	Profiler.Begin("Render")
	for i = 1, 6000 do
		local _ = math.cos(i * 0.02)
	end
	Profiler.End("Render")
	Profiler.EndFrame()
end)

callbacks.Register("Unload", TAG, function()
	Profiler.EndSession()
	cleanup()
	_G.PROFILER_DUAL_LOADED = false
	print("[dual_context] Exported tick.* and frame.* under flame_graphs/")
end)

print("[dual_context] session=" .. tostring(Profiler.GetSessionID()))
