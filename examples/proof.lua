--[[
    Verify timing_collector.exe is running (one Draw probe).
    Double-click timing_collector\run\timing_collector.exe first.
]]

local TAG = "profiler_proof"
local done = false

local function onDraw()
	if done then
		return
	end
	done = true

	local ok, response = pcall(http.Get, "http://127.0.0.1:9876/now")
	if ok and response and tonumber(response) then
		print("[proof] Collector OK — run: lua_load simple_test")
	else
		print("[proof] FAILED — double-click timing_collector\\run\\timing_collector.exe")
	end
end

callbacks.Unregister("Draw", TAG)
callbacks.Register("Draw", TAG, onDraw)

print("[proof] Waiting for one Draw...")
