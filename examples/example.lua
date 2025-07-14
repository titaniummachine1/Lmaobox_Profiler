--[[
    Lmaobox Profiler Library - Real Usage Example
    This example shows how to profile actual Lmaobox scripts and monitor memory usage
    
    Place this in your %localappdata% folder and load with: lua_load example.lua
]]

--[[
    IMPORTANT: If reloading this script, first run:
    lua_load unload_profiler.lua
    
    Then reload this script:
    lua_load example.lua
]]

-- Clear any existing profiler before loading new one
if package.loaded["Profiler"] then
	local oldProfiler = package.loaded["Profiler"]
	if oldProfiler and oldProfiler.Unload then
		oldProfiler.Unload()
	end
end

-- Load the bundled Profiler library
local Profiler = require("Profiler")

-- Enable the profiler with optimal settings for Lmaobox
Profiler.SetVisible(true)
Profiler.SetSortMode("size") -- Show biggest components first
Profiler.SetWindowSize(60) -- Average over 60 frames for smooth data

print("✅ Lmaobox Profiler enabled! Memory and performance monitoring active.")

--[[
    PROFILER USAGE PATTERNS:
    
    1. System + Components (Organized):
       Profiler.StartSystem("mysystem")
           Profiler.StartComponent("task1")
           -- code --
           Profiler.EndComponent("task1")
       Profiler.EndSystem("mysystem")
    
    2. Component Only (Auto-assigns to "misc" system):
       Profiler.StartComponent("standalone_task")
       -- code --
       Profiler.EndComponent("standalone_task")
       
    The profiler will automatically show individual component memory usage
    and time (when >= 0.01ms with red background) for debugging purposes.
]]

-- Create fonts for our example scripts (like the community examples)
local consolas = draw.CreateFont("Consolas", 17, 500)
local verdana = draw.CreateFont("Verdana", 16, 800)

-- Variables for our example features
local current_fps = 0
local damage_events = {}

-- FPS Counter (based on x6h's example) - Profiled version
local function ProfiledFPSCounter()
	-- This will automatically be assigned to "misc" system since no system is active
	Profiler.StartComponent("fps_counter")

	draw.SetFont(consolas)
	draw.Color(255, 255, 255, 255)

	-- Update fps every 100 frames (expensive operation)
	if globals.FrameCount() % 100 == 0 then
		current_fps = math.floor(1 / globals.FrameTime())
	end

	draw.Text(5, 5, "[lmaobox | fps: " .. tostring(current_fps) .. " | profiler: ON]")

	Profiler.EndComponent("fps_counter")
end

-- Basic Player ESP (based on community example) - Profiled version
local function ProfiledPlayerESP()
	Profiler.StartComponent("player_esp")

	if engine.Con_IsVisible() or engine.IsGameUIVisible() then
		Profiler.EndComponent("player_esp")
		return
	end

	-- This is expensive - finding all players every frame
	local players = entities.FindByClass("CTFPlayer")

	for i, p in ipairs(players) do
		if p:IsAlive() and not p:IsDormant() then
			local screenPos = client.WorldToScreen(p:GetAbsOrigin())
			if screenPos ~= nil then
				draw.SetFont(verdana)
				draw.Color(255, 255, 255, 255)
				draw.Text(screenPos[1], screenPos[2], p:GetName())
			end
		end
	end

	Profiler.EndComponent("player_esp")
end

-- Damage Logger (based on @RC's example) - Profiled version
local function ProfiledDamageLogger(event)
	Profiler.StartComponent("damage_logger")

	if event:GetName() == "player_hurt" then
		local localPlayer = entities.GetLocalPlayer()
		if not localPlayer then
			Profiler.EndComponent("damage_logger")
			return
		end

		local victim = entities.GetByUserID(event:GetInt("userid"))
		local health = event:GetInt("health")
		local attacker = entities.GetByUserID(event:GetInt("attacker"))
		local damage = event:GetInt("damageamount")

		if attacker and localPlayer:GetIndex() == attacker:GetIndex() then
			-- Store damage event (this uses memory)
			table.insert(damage_events, {
				victim = victim:GetName(),
				damage = damage,
				health = health,
				time = globals.RealTime(),
			})

			-- Keep only last 10 damage events to prevent memory bloat
			if #damage_events > 10 then
				table.remove(damage_events, 1)
			end

			print(
				"You hit "
					.. victim:GetName()
					.. " for "
					.. tostring(damage)
					.. "HP (health: "
					.. tostring(health)
					.. ")"
			)
		end
	end

	Profiler.EndComponent("damage_logger")
end

-- Example aimbot logic (expensive computation)
local function ProfiledAimbot(cmd)
	Profiler.StartComponent("aimbot")

	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer or not localPlayer:IsAlive() then
		Profiler.EndComponent("aimbot")
		return
	end

	-- Expensive: scan for enemies
	local players = entities.FindByClass("CTFPlayer")
	local bestTarget = nil
	local bestFOV = 180

	for i, player in ipairs(players) do
		if player:IsAlive() and not player:IsDormant() and player:GetTeamNumber() ~= localPlayer:GetTeamNumber() then
			-- Expensive: FOV calculation
			local fov = math.random() * 60 -- Simulate FOV calculation
			if fov < bestFOV then
				bestFOV = fov
				bestTarget = player
			end
		end
	end

	-- Simulate aim adjustment (expensive math)
	if bestTarget then
		local result = 0
		for i = 1, 100 do
			result = result + math.sin(i) * math.cos(i) -- Simulate heavy computation
		end
	end

	Profiler.EndComponent("aimbot")
end

-- Example movement assistance
local function ProfiledMovement(cmd)
	Profiler.StartComponent("movement")

	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer then
		Profiler.EndComponent("movement")
		return
	end

	-- Simulate strafe calculation (expensive)
	local velocity = localPlayer:EstimateAbsVelocity()
	if velocity then
		-- Heavy computation for movement
		for i = 1, 50 do
			math.sqrt(velocity:Length() + i)
		end
	end

	Profiler.EndComponent("movement")
end

-- Unregister any existing callbacks before registering new ones (safe unregister)
if callbacks.Unregister then
	local function SafeUnregister(event, id)
		local success, err = pcall(callbacks.Unregister, event, id)
		if not success then
			-- Callback didn't exist - this is fine on first load
			return false
		end
		return true
	end

	local unregistered = 0
	if SafeUnregister("CreateMove", "profiled_createmove") then
		unregistered = unregistered + 1
	end
	if SafeUnregister("Draw", "profiled_draw") then
		unregistered = unregistered + 1
	end
	if SafeUnregister("FireGameEvent", "profiled_events") then
		unregistered = unregistered + 1
	end
	if SafeUnregister("Think", "profiled_think") then
		unregistered = unregistered + 1
	end

	if unregistered > 0 then
		print("🔄 Unregistered " .. unregistered .. " existing Profiler callbacks")
	end
end

-- Remove SafeRegister helper and revert to direct registrations
-- CreateMove callback
callbacks.Register("CreateMove", "profiled_createmove", function(cmd)
	Profiler.StartSystem("oncreatemove")
	ProfiledAimbot(cmd)
	ProfiledMovement(cmd)
	Profiler.EndSystem("oncreatemove")
end)

-- Draw callback
callbacks.Register("Draw", "profiled_draw", function()
	Profiler.StartSystem("ondraw")
	ProfiledFPSCounter()
	ProfiledPlayerESP()
	Profiler.Draw()
	Profiler.EndSystem("ondraw")
end)

-- FireGameEvent callback
callbacks.Register("FireGameEvent", "profiled_events", function(event)
	Profiler.StartSystem("onevent")
	ProfiledDamageLogger(event)
	Profiler.EndSystem("onevent")
end)

-- Think callback
callbacks.Register("Think", "profiled_think", function()
	Profiler.StartSystem("onthink")
	Profiler.StartComponent("misc_features")
	local result = 0
	for i = 1, 20 do
		result = result + math.random() * 100
	end
	Profiler.EndComponent("misc_features")
	Profiler.StartComponent("config_check")
	local cfg = math.random() * 50
	Profiler.EndComponent("config_check")
	Profiler.EndSystem("onthink")
end)

--[[
    HOW TO USE THIS EXAMPLE:
    
    1. Save this as example.lua in your %localappdata% folder
    2. In TF2 with Lmaobox loaded, type: lua_load example.lua
    3. The profiler will immediately show performance data for:
       - CreateMove: aimbot and movement calculations
       - Draw: FPS counter and player ESP rendering  
       - FireGameEvent: damage logging
       - Think: misc background tasks
    
    WHAT YOU'LL SEE:
    - Systems stacked from bottom of screen upward
    - Components within each system from left to right
    - Time and memory usage for each component
    - Color-coded components for easy identification
    - Real-time performance monitoring
    
    MEMORY MONITORING:
    The profiler tracks memory allocation for:
    - Table creation (damage_events)
    - String operations (player names, formatting)
    - Mathematical calculations (FOV, movement)
    - Drawing operations (fonts, text rendering)
    
    PERFORMANCE INSIGHTS:
    - Player ESP is typically the most expensive (entities.FindByClass every frame)
    - Aimbot calculations vary based on player count
    - Drawing operations have consistent but measurable cost
    - Event handling spikes during combat
]]
