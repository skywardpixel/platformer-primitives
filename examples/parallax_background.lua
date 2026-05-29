-- Example 3: Parallax Background
-- Focus: layered scrolling. Background layers move at fractions of the camera
-- speed (distant = slow), which reads as depth. Layers are drawn in SCREEN
-- space (outside the camera transform) and tiled horizontally so they repeat
-- forever.
--
-- Each assets/bg_*.png is 480x270 and tiles seamlessly left-to-right.
local Tilemap = require("lib.tilemap")
local Player  = require("lib.player")
local Camera  = require("lib.camera")
local Grid    = require("lib.level")
local Assets  = require("lib.assets")

local M = {
    name  = "3. Parallax Background",
    blurb = "Multi-layer scrolling backdrop that gives a sense of depth.",
    help  = "Move/Jump: arrows / WASD / Space\n"
         .. "Run far left/right to feel\n"
         .. "the layers separate.\n"
         .. "P: pause parallax (lock bg)\n"
         .. "R: reset position",
}

local TS = 16

-- layer image + horizontal & vertical scroll factors (0 = fixed, 1 = world).
local LAYERS = {
    { img = "assets/bg_sky.png",       fx = 0.00, fy = 0.00 },
    { img = "assets/bg_mountains.png", fx = 0.15, fy = 0.04 },
    { img = "assets/bg_hills.png",     fx = 0.35, fy = 0.06 },
    { img = "assets/bg_trees.png",     fx = 0.60, fy = 0.10 },
}

local function buildLevel()
    local g = Grid.new(120, 20, ".")
    g:rect(1, 17, 120, 17, "#"):rect(1, 18, 120, 20, "D")
    -- gentle terrain so the player has reasons to move and jump
    for i = 1, 11 do
        local x = i * 10
        g:rect(x, 14 - (i % 3), x + 4, 14 - (i % 3), "=")
    end
    g:rect(60, 12, 62, 16, "S")
    return g
end

function M:load()
    self.map = Tilemap.new(buildLevel():rows(), TS)
    self.spawnX, self.spawnY = 6 * TS, 14 * TS
    self.player = Player.new(self.spawnX, self.spawnY)
    self.cam = Camera.new(3)
    self.cam:setBounds(0, 0, self.map:pixelWidth(), self.map:pixelHeight())
    local cx, cy = self.player:center()
    self.cam:snapTo(cx, cy)
    self.bgRefY = self.cam.y    -- vertical anchor for the background layers
    self.paused = false
    for _, L in ipairs(LAYERS) do L.image = Assets.image(L.img) end
end

function M:keypressed(key)
    if key == "r" then self.player:setPosition(self.spawnX, self.spawnY)
    elseif key == "p" then
        self.paused = not self.paused
        -- freeze the layers at the camera's current position
        self.pauseX, self.pauseY = self.cam.x, self.cam.y
    else self.player:keypressed(key) end
end

function M:keyreleased(key) self.player:keyreleased(key) end

function M:update(dt)
    self.player:update(dt, self.map)
    if self.player.box.y > self.map:pixelHeight() + 40 then
        self.player:setPosition(self.spawnX, self.spawnY)
    end
    local cx, cy = self.player:center()
    self.cam:follow({ x = cx, y = cy, facing = self.player.facing }, dt)
end

-- Tile one layer across the screen at its scroll factor.
function M:drawLayer(L)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local img = L.image
    -- Scale the layer a bit taller than the window so a little vertical
    -- parallax never reveals a gap at the top or bottom.
    local s = (sh + 120) / img:getHeight()
    local iw = img:getWidth() * s
    local camx = self.paused and self.pauseX or self.cam.x
    local camy = self.paused and self.pauseY or self.cam.y

    -- horizontal: wrap the offset into [0, iw) and tile across + one extra
    local ox = (-camx * L.fx) % iw
    -- vertical: gentle parallax around the anchor row captured on load
    local oy = -60 + (self.bgRefY - camy) * L.fy

    love.graphics.setColor(1, 1, 1)
    local x = ox - iw
    while x < sw do
        love.graphics.draw(img, x, oy, 0, s, s)
        x = x + iw
    end
end

function M:draw()
    for _, L in ipairs(LAYERS) do self:drawLayer(L) end

    self.cam:attach()
    self.map:draw(self.cam)
    self.player:draw()
    self.cam:detach()

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(self.paused and "parallax PAUSED" or "parallax live",
        12, love.graphics.getHeight() - 24)
end

return M
