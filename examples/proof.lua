--[[
    Verify timing_collector.exe is running (one Draw probe).
    Double-click timing_collector\run\timing_collector.exe first.
]]

local TAG = "profiler_proof"
local LOAD_KEY = "profiler.proof.v1"

if package.loaded[LOAD_KEY] then
	print("[proof] Already loaded.")
	return
end
package.loaded[LOAD_KEY] = true

callbacks.Register("Draw", TAG, function()
	if package.loaded[LOAD_KEY .. ".done"] then
		return
	end
	package.loaded[LOAD_KEY .. ".done"] = true

	local ok, response = pcall(http.Get, "http://127.0.0.1:9876/now")
	if ok and response and tonumber(response) then
		print("[proof] Collector OK — run: lua_load simple_test")
	else
		print("[proof] FAILED — double-click timing_collector\\run\\timing_collector.exe")
	end
end)

print("[proof] Waiting for one Draw...")
