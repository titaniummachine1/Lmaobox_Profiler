local Shared = require("Profiler.Shared")

local UIWarning = {}

local lastCheckTime = 0
local warningVisible = false

function UIWarning.Draw()
	local currentTime = os.clock()

	if currentTime - lastCheckTime > 1 then
		lastCheckTime = currentTime
		warningVisible = Shared.TimingServerAvailable == false
	end

	if not warningVisible then
		return
	end

	local screenW, screenH = draw.GetScreenSize()

	local message = "⚠ Run timing_server.exe for nanosecond precision (fallback: os.clock)"
	local fontSize = 24

	local textW, textH = draw.GetTextSize(message)

	local padding = 20
	local boxW = textW + padding * 2
	local boxH = textH + padding * 2

	local boxX = (screenW - boxW) / 2
	local boxY = screenH - boxH - 20

	draw.Color(200, 50, 50, 180)
	draw.FilledRect(boxX, boxY, boxX + boxW, boxY + boxH)

	draw.Color(255, 255, 255, 255)
	draw.Text(boxX + padding, boxY + padding, message)
end

return UIWarning
