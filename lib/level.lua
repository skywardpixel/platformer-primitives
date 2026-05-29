-- A tiny grid builder so examples can describe a level with code
-- (fill / rect / row stamps) instead of hand-counting long strings.
-- Coordinates are 1-based tile coords. Produces the array-of-strings that
-- Tilemap.new expects.
local Grid = {}
Grid.__index = Grid

function Grid.new(w, h, fill)
    local self = setmetatable({}, Grid)
    self.w, self.h = w, h
    self.cells = {}
    fill = fill or "."
    for y = 1, h do
        self.cells[y] = {}
        for x = 1, w do self.cells[y][x] = fill end
    end
    return self
end

function Grid:set(x, y, ch)
    if x >= 1 and x <= self.w and y >= 1 and y <= self.h then
        self.cells[y][x] = ch
    end
    return self
end

-- Fill an inclusive rectangle of tiles.
function Grid:rect(x0, y0, x1, y1, ch)
    for y = math.max(1, y0), math.min(self.h, y1) do
        for x = math.max(1, x0), math.min(self.w, x1) do
            self.cells[y][x] = ch
        end
    end
    return self
end

-- Horizontal run of tiles at row y from x0..x1.
function Grid:hline(x0, x1, y, ch)
    return self:rect(x0, y, x1, y, ch)
end

function Grid:rows()
    local out = {}
    for y = 1, self.h do out[y] = table.concat(self.cells[y]) end
    return out
end

return Grid
