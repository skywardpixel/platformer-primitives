-- Example 2: Camera Controller
-- Focus: how the VIEW follows the player. Same controller as example 1, but a
-- big level and an on-screen overlay that visualises the camera internals:
--   * the dead-zone box (camera holds still while the player stays inside)
--   * the focus point (player + look-ahead) the camera chases
--   * bounds clamping at the level edges
--
-- Toggle the overlay and tweak the camera live to feel the difference.
local Tilemap = require("lib.tilemap")
local Player  = require("lib.player")
local Camera  = require("lib.camera")
local Grid    = require("lib.level")

local M = {
    name  = "2. Camera Controller",
    blurb = "Follow camera: smoothing, dead-zone, look-ahead, level-bounds clamp.",
    help  = "Move/Jump: arrows / WASD / Space\n"
         .. "O : toggle overlay\n"
         .. "L : toggle look-ahead\n"
         .. "[ / ] : zoom out / in\n"
         .. "- / = : dead-zone smaller/larger\n"
         .. "R: reset position",
}

local TS = 16

local function buildLevel()
    -- wide AND tall so we can show clamping on every edge
    local g = Grid.new(90, 40, ".")
    -- big floor near the bottom
    g:rect(1, 37, 90, 37, "#"):rect(1, 38, 90, 40, "D")
    -- some platforms climbing up to show vertical follow + clamp
    g:rect(10, 33, 16, 33, "#"):rect(10, 34, 16, 34, "D")
    g:rect(22, 29, 28, 29, "#"):rect(22, 30, 28, 30, "D")
    g:rect(34, 25, 40, 25, "#"):rect(34, 26, 40, 26, "D")
    g:rect(46, 21, 52, 21, "#"):rect(46, 22, 52, 22, "D")
    g:rect(58, 17, 66, 17, "#"):rect(58, 18, 66, 18, "D")
    -- a tall pillar on the right edge and a pit, to push the camera around
    g:rect(80, 12, 82, 37, "S")
    g:rect(86, 33, 90, 33, "#"):rect(86, 34, 90, 34, "D")
    -- one-way ledges scattered for climbing
    g:rect(70, 28, 74, 28, "="):rect(74, 22, 78, 22, "=")
    return g
end

function M:load()
    self.map = Tilemap.new(buildLevel():rows(), TS)
    self.spawnX, self.spawnY = 4 * TS, 33 * TS
    self.player = Player.new(self.spawnX, self.spawnY)
    self.cam = Camera.new(3)
    self.cam:setBounds(0, 0, self.map:pixelWidth(), self.map:pixelHeight())
    local cx, cy = self.player:center()
    self.cam:snapTo(cx, cy)
    self.overlay = true
    self.lookAheadOn = true
end

function M:keypressed(key)
    if key == "r" then
        self.player:setPosition(self.spawnX, self.spawnY)
    elseif key == "o" then
        self.overlay = not self.overlay
    elseif key == "l" then
        self.lookAheadOn = not self.lookAheadOn
        self.cam.lookAheadDist = self.lookAheadOn and 28 or 0
    elseif key == "]" then
        self.cam.scale = math.min(5, self.cam.scale + 1)
    elseif key == "[" then
        self.cam.scale = math.max(2, self.cam.scale - 1)
    elseif key == "=" then
        self.cam.deadzoneW = math.min(140, self.cam.deadzoneW + 10)
        self.cam.deadzoneH = math.min(100, self.cam.deadzoneH + 8)
    elseif key == "-" then
        self.cam.deadzoneW = math.max(0, self.cam.deadzoneW - 10)
        self.cam.deadzoneH = math.max(0, self.cam.deadzoneH - 8)
    else
        self.player:keypressed(key)
    end
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

function M:draw()
    love.graphics.setColor(0.45, 0.62, 0.82)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1)

    self.cam:attach()
    self.map:draw(self.cam)
    self.player:draw()
    self.cam:detach()

    if self.overlay then self:drawOverlay() end
end

-- Draw the camera's internals in SCREEN space (after detach).
function M:drawOverlay()
    local scale = self.cam.scale
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ccx, ccy = sw / 2, sh / 2

    -- dead-zone box (world units -> screen via scale, centred on screen centre)
    love.graphics.setColor(1, 0.85, 0.2, 0.9)
    love.graphics.rectangle("line",
        ccx - self.cam.deadzoneW * scale, ccy - self.cam.deadzoneH * scale,
        self.cam.deadzoneW * 2 * scale, self.cam.deadzoneH * 2 * scale)
    love.graphics.print("dead-zone", ccx - self.cam.deadzoneW * scale + 4,
        ccy - self.cam.deadzoneH * scale + 2)

    -- focus point (player centre + look-ahead) projected to screen
    local px, py = self.player:center()
    local fx = px + self.cam.lookAhead
    local sx = (fx - self.cam.x) * scale + ccx
    local sy = (py - self.cam.y) * scale + ccy
    love.graphics.setColor(0.3, 1, 0.5, 1)
    love.graphics.circle("line", sx, sy, 6)
    love.graphics.line(ccx + (px - self.cam.x) * scale, sy, sx, sy)

    -- crosshair at exact screen centre (where camera.x/y maps to)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.line(ccx - 6, ccy, ccx + 6, ccy)
    love.graphics.line(ccx, ccy - 6, ccx, ccy + 6)

    -- readout
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(string.format(
        "zoom x%d   dead-zone %dx%d   look-ahead %s",
        scale, self.cam.deadzoneW, self.cam.deadzoneH,
        self.lookAheadOn and "on" or "off"),
        12, sh - 24)
end

return M
