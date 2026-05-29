-- Minimal sprite-sheet animation helper.
--
-- A sheet is a single image laid out as a horizontal strip of equal-size
-- frames. You build an Animation from a list of frame indices (0-based) and a
-- frames-per-second value. Quads are cached per sheet so it's cheap to make
-- many animations from the same image.
local Anim = {}
Anim.__index = Anim

local quadCache = setmetatable({}, { __mode = "k" }) -- weak per-image cache

local function quadsFor(image, fw, fh)
    if not quadCache[image] then
        local quads = {}
        local cols = math.floor(image:getWidth() / fw)
        for i = 0, cols - 1 do
            quads[i] = love.graphics.newQuad(i * fw, 0, fw, fh,
                image:getWidth(), image:getHeight())
        end
        quadCache[image] = quads
    end
    return quadCache[image]
end

-- frames: list of 0-based frame indices, e.g. {2,3,4,5} for a run cycle.
-- fps: playback speed. looping defaults to true.
function Anim.new(image, fw, fh, frames, fps, looping)
    local self = setmetatable({}, Anim)
    self.image = image
    self.fw, self.fh = fw, fh
    self.quads = quadsFor(image, fw, fh)
    self.frames = frames
    self.frameTime = 1 / (fps or 8)
    self.looping = looping ~= false
    self.timer = 0
    self.index = 1
    self.done = false
    return self
end

function Anim:reset()
    self.timer, self.index, self.done = 0, 1, false
end

function Anim:update(dt)
    if self.done then return end
    self.timer = self.timer + dt
    while self.timer >= self.frameTime do
        self.timer = self.timer - self.frameTime
        self.index = self.index + 1
        if self.index > #self.frames then
            if self.looping then
                self.index = 1
            else
                self.index = #self.frames
                self.done = true
            end
        end
    end
end

-- Draw centred on (x, y) at the bottom (feet) of the sprite.
-- facing -1 flips horizontally. sx/sy are extra scale factors.
function Anim:draw(x, y, facing, sx, sy)
    sx = sx or 1
    sy = sy or 1
    local quad = self.quads[self.frames[self.index]]
    local ox, oy = self.fw / 2, self.fh
    love.graphics.draw(self.image, quad, x, y, 0,
        (facing or 1) * sx, sy, ox, oy)
end

return Anim
