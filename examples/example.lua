-- Microprofiler example rewritten to showcase the manual API in a predictable way.
-- The profiler no longer auto-hooks anything – scripts must wrap their own scopes.

local SCRIPT_TAG = "microprofiler_example"

local Profiler = require("Profiler")
Profiler.SetVisible(true)

local state = {
	frame = 0,
	telemetry = {
		ai = 0,
		network = 0,
		ui = 0,
	},
}

local function runScoped(name, fn)
	Profiler.Begin(name)
	local ok, err = pcall(fn)
	Profiler.End()
	if not ok then
		print(string.format("[Profiler Example] scope '%s' error: %s", name, err))
	end
end

local function simulateAI()
	runScoped("AI.Pathfinding", function()
		local sum = 0
		for i = 1, 80 do
			sum = sum + math.sin(i * 0.05) * math.cos(i * 0.025)
		end
		state.telemetry.ai = sum
	end)

	runScoped("AI.Decision", function()
		local choice = 0
		for i = 1, 25 do
			choice = choice + math.random()
		end
		state.telemetry.ai = state.telemetry.ai + choice
	end)
end

local function simulateNetwork()
	runScoped("Net.Poll", function()
		local checksum = 0
		for i = 1, 15 do
			checksum = checksum + (i * 13) + math.sin(globals.RealTime() * i)
		end
		state.telemetry.network = checksum
	end)

	runScoped("Net.Decode", function()
		for _ = 1, 5 do
			local payload = string.format("pkt_%d", math.random(1000, 9000))
			state.telemetry.network = state.telemetry.network + #payload
		end
	end)
end

local function simulateUI()
	runScoped("UI.Layout", function()
		local total = 0
		for i = 1, 8 do
			total = total + math.sin(globals.RealTime() + i * 0.1)
		end
		state.telemetry.ui = total
	end)

	runScoped("UI.Animate", function()
		local t = globals.RealTime()
		for i = 1, 30 do
			state.telemetry.ui = state.telemetry.ui + math.cos(t + i * 0.07)
		end
	end)
end

local function manualSpike(name, iterations)
	runScoped(name, function()
		local acc = 0
		for i = 1, iterations do
			acc = acc + math.sqrt(i) * math.sin(i * globals.FrameTime())
		end
	end)
end

local function drawHUD()
	Profiler.Begin("ProfilerExample.DrawHUD")
	draw.Color(255, 255, 255, 255)
	draw.Text(
		10,
		20,
		string.format("AI %.2f | Net %.2f | UI %.2f", state.telemetry.ai, state.telemetry.network, state.telemetry.ui)
	)
	Profiler.End()
end

callbacks.Register("CreateMove", SCRIPT_TAG .. "_move", function(cmd)
	Profiler.Begin("ProfilerExample.CreateMove")
	simulateAI()
	simulateNetwork()
	simulateUI()

	state.frame = state.frame + 1
	if state.frame % 200 == 0 then
		manualSpike("ProfilerExample.Spike", 250)
	end
	Profiler.End()
end)

callbacks.Register("Draw", SCRIPT_TAG .. "_draw", function()
	Profiler.Begin("ProfilerExample.DrawLoop")
	simulateUI()
	drawHUD()
	Profiler.Draw()
	Profiler.End()
end)

callbacks.Register("Unload", SCRIPT_TAG .. "_unload", function()
	print("[Profiler Example] unloading")
	_G.MICROPROFILER_EXAMPLE_ACTIVE = false
end)

_G.MICROPROFILER_EXAMPLE_ACTIVE = true
print("[Profiler Example] loaded. Use Profiler.Begin/End in your own code just like this demo.")
