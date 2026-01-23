-- Runtime-friendly Profiler demo: showcases real-time work without freezing the game

local SCRIPT_TAG = "microprofiler_simple_test"

-- Properly unload existing profiler instance before loading new one
if _G.SIMPLE_PROFILER_TEST_LOADED then
	print("[Simple Test] Unloading previous profiler instance...")
	callbacks.Unregister("CreateMove", SCRIPT_TAG .. "_move")
	callbacks.Unregister("Draw", SCRIPT_TAG .. "_draw")
	callbacks.Unregister("Unload", SCRIPT_TAG .. "_unload")
	_G.SIMPLE_PROFILER_TEST_LOADED = false
	collectgarbage("collect")
end

local Profiler = require("Profiler")
Profiler.SetVisible(true)

_G.SIMPLE_PROFILER_TEST_LOADED = true

local runtimeState = {
	lastHUDUpdate = 0,
	frameCount = 0,
	metrics = {
		physics = 0,
		network = 0,
		ui = 0,
		background = 0,
	},
}

local function simulatePhysics(now)
	Profiler.Begin("Physics.Integration")
	local total = 0
	for i = 1, 150 do
		local t = now + i * 0.002
		total = total + math.sin(t) * math.cos(t * 0.5)
	end
	Profiler.End()

	Profiler.Begin("Physics.ContactSolve")
	for i = 1, 45 do
		total = total + math.sin(now + i * 0.01) * 0.25
	end
	Profiler.End()

	runtimeState.metrics.physics = total
end

local function simulateNetwork(now)
	Profiler.Begin("Network.PollLoop")
	local packets = 12
	local checksum = 0
	for i = 1, packets do
		local jitter = math.sin(now * i) * 0.3
		checksum = checksum + (i * 17) + jitter
	end
	Profiler.End()

	Profiler.Begin("Network.DecodeSmall")
	for i = 1, 4 do
		checksum = checksum + math.cos(now * i) * 0.1
	end
	Profiler.End()

	runtimeState.metrics.network = checksum
end

local function simulateUI(now)
	Profiler.Begin("UI.Layout")
	local text = {}
	for i = 1, 6 do
		text[i] = string.format("UI_%d_%.2f", i, now + i * 0.1)
	end
	Profiler.End()

	Profiler.Begin("UI.Animations")
	local anim = 0
	for i = 1, 20 do
		anim = anim + math.sin(now + i * 0.05) * 0.25
	end
	Profiler.End()

	runtimeState.metrics.ui = #table.concat(text, "|")
end

local runtimeTasks = {
	{
		name = "Runtime.Physics",
		interval = 0.05,
		lastRun = 0,
		fn = function(now)
			Profiler.Begin("Physics.Step")
			simulatePhysics(now)
			Profiler.End()
		end,
	},
	{
		name = "Runtime.Network",
		interval = 0.1,
		lastRun = 0,
		fn = function(now)
			Profiler.Begin("Network.Poll")
			simulateNetwork(now)
			Profiler.End()
		end,
	},
	{
		name = "Runtime.UI",
		interval = 0.2,
		lastRun = 0,
		fn = function(now)
			Profiler.Begin("UI.Update")
			simulateUI(now)
			Profiler.End()
		end,
	},
}

local function processTasks()
	local now = globals.RealTime()
	Profiler.Begin("Runtime.Tick")
	for _, task in ipairs(runtimeTasks) do
		if now - task.lastRun >= task.interval then
			task.lastRun = now
			task.fn(now)
		end
	end
	Profiler.End()
end

local function runManualSpike()
	Profiler.Begin("ManualSpike")
	local total = 0
	for i = 1, 200 do
		total = total + math.sqrt(i * globals.FrameTime())
	end
	Profiler.End()
	return total
end

local function drawHud()
	Profiler.Begin("HUD.Update")
	local now = globals.RealTime()
	if now - runtimeState.lastHUDUpdate < 0.25 then
		Profiler.End()
		return
	end
	runtimeState.lastHUDUpdate = now
	print(
		string.format(
			" Runtime stats | Physics %.2f | Network %.2f | UI %d",
			runtimeState.metrics.physics,
			runtimeState.metrics.network,
			runtimeState.metrics.ui
		)
	)
	Profiler.End()
end

callbacks.Register("CreateMove", SCRIPT_TAG .. "_move", function(cmd)
	Profiler.Begin("CreateMove")
	processTasks()
	runtimeState.frameCount = runtimeState.frameCount + 1
	if runtimeState.frameCount % 180 == 0 then
		local spike = runManualSpike()
		print(string.format(" Manual spike sample: %.2f", spike))
	end
	Profiler.End()
end)

callbacks.Register("Draw", SCRIPT_TAG .. "_draw", function()
	Profiler.Begin("DrawLoop")
	processTasks()
	drawHud()
	Profiler.Draw()
	Profiler.End()
end)

callbacks.Register("Unload", SCRIPT_TAG .. "_unload", function()
	print("[Simple Test] Unloading microprofiler simple test")
	Profiler.SetVisible(false)
	Profiler.Shutdown()
	_G.SIMPLE_PROFILER_TEST_LOADED = false
end)

print(" Microprofiler simple runtime test loaded!")
