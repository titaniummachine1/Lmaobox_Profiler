--[[
    Draw Wrapper - Enforces integer pixel coordinates for all draw calls
    Prevents drawing outside visible bounds
]]

local DrawWrapper = {}

-- Clamp and convert to integer
local function toInt(value)
	if not value or value ~= value then
		return 0
	end -- NaN
	if value == math.huge or value == -math.huge then
		return 0
	end -- Infinity
	return math.floor(value + 0.5)
end

-- Clip rectangle to visible bounds
local function clipRect(x1, y1, x2, y2, minX, minY, maxX, maxY)
	x1 = math.max(x1, minX)
	y1 = math.max(y1, minY)
	x2 = math.min(x2, maxX)
	y2 = math.min(y2, maxY)

	-- Return nil if completely clipped
	if x1 >= x2 or y1 >= y2 then
		return nil
	end

	return x1, y1, x2, y2
end

-- Safe draw functions (all enforce integer coordinates)
function DrawWrapper.SafeLine(draw, x1, y1, x2, y2, clipMinY, clipMaxY)
	if not draw or not draw.Line then
		return
	end

	x1, y1, x2, y2 = toInt(x1), toInt(y1), toInt(x2), toInt(y2)

	-- Clip vertically if bounds provided
	if clipMinY and y1 < clipMinY and y2 < clipMinY then
		return
	end
	if clipMaxY and y1 > clipMaxY and y2 > clipMaxY then
		return
	end

	draw.Line(x1, y1, x2, y2)
end

function DrawWrapper.SafeFilledRect(draw, x1, y1, x2, y2, clipMinY, clipMaxY)
	if not draw or not draw.FilledRect then
		return
	end

	x1, y1, x2, y2 = toInt(x1), toInt(y1), toInt(x2), toInt(y2)

	-- Clip if bounds provided
	if clipMinY and clipMaxY then
		local clipped = clipRect(x1, y1, x2, y2, -100000, clipMinY, 100000, clipMaxY)
		if not clipped then
			return
		end
		x1, y1, x2, y2 = clipped, select(2, clipped), select(3, clipped), select(4, clipped)
	end

	-- Ensure valid rect
	if x1 >= x2 or y1 >= y2 then
		return
	end

	draw.FilledRect(x1, y1, x2, y2)
end

function DrawWrapper.SafeOutlinedRect(draw, x1, y1, x2, y2, clipMinY, clipMaxY)
	if not draw or not draw.OutlinedRect then
		return
	end

	x1, y1, x2, y2 = toInt(x1), toInt(y1), toInt(x2), toInt(y2)

	-- Clip if bounds provided
	if clipMinY and y1 > clipMaxY then
		return
	end -- Completely below
	if clipMaxY and y2 < clipMinY then
		return
	end -- Completely above

	-- Ensure valid rect
	if x1 >= x2 or y1 >= y2 then
		return
	end

	draw.OutlinedRect(x1, y1, x2, y2)
end

function DrawWrapper.SafeText(draw, x, y, text, clipMinY, clipMaxY)
	if not draw or not draw.Text or not text then
		return
	end

	x, y = toInt(x), toInt(y)

	-- Clip if bounds provided
	if clipMinY and y < clipMinY then
		return
	end
	if clipMaxY and y > clipMaxY then
		return
	end

	draw.Text(x, y, text)
end

return DrawWrapper
