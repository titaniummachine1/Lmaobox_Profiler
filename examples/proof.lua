--[[
    Verify timing_collector is running (Draw callback hits /now once).
]]

local TAG = "profiler_proof"
local tested = false

callbacks.Unregister("Draw", TAG)

callbacks.Register("Draw", TAG, function()
	if tested then
		return
	end
	tested = true

	local ok, response = pcall(function()
		return http.Get("http://127.0.0.1:9876/now")
	end)
	if ok and response and tonumber(response) then
		print("[proof] Collector OK — /now = " .. response .. " ns")
		print("[proof] Now run: lua_load test_flamegraphs")
	else
		print("[proof] FAILED — start timing_collector.exe first")
	end
end)

print("[proof] Waiting for one Draw to probe collector...")
