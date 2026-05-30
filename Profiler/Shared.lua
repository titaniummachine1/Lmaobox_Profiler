--[[
    Shared runtime state for Profiler (session metadata only).
]]

local Shared = {
	ActiveScriptName = nil,
	SessionID = nil,
	CollectorAvailable = nil,
	Enabled = true,
	UnloadCallbackTag = "lmaobox_profiler_unload",
}

return Shared
