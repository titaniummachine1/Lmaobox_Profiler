--[[
    Shared runtime state for Profiler (session metadata only).
]]

local Shared = {
	ActiveScriptName = nil,
	BoundScriptName = nil,
	SessionID = nil,
	CollectorAvailable = nil,
	Enabled = true,
	SessionEnding = false,
	LastError = nil,
	LastExportSessionID = nil,
}

return Shared
