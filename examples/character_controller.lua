-- Example 1: Character Controller
-- Focus: how the player MOVES. Run/jump/fall over a level that exercises
-- gaps, walls, ledges (coyote time) and a one-way platform. The camera here
-- is intentionally minimal so all the interest is in the controller.
--
-- See lib/player.lua for the tunable feel parameters.
local Tilemap = require("lib.tilemap")
local Player  = require("lib.player")
local Camera  = require("lib.camera")
local Grid    = require("lib.level")

local M = {
    name  = "1. Character Controller",
    blurb = "Run, accelerate, variable-height jump, coyote time, one-way platforms.",
    help  = "Move:  Left/Right  or  A/D\n"
         .. "Jump:  Space / Z / Up  (hold for higher)\n"
         .. "Drop through  =  platform:\n"
         .. "   hold Down + Jump\n"
         .. "R: reset position",
}

local TS = 16

local function buildLevel()
    local g = Grid.new(50, 18, ".")
    -- floor with a gap to jump across
    g:rect(1, 16, 18, 16, "#"):rect(1, 17, 18, 18, "D")
    g:rect(22, 16, 50, 16, "#"):rect(22, 17, 50, 18, "D")
    -- left/right edge tiles where ground meets the gap (cosmetic edges)
    g:set(18, 16, ">"):set(22, 16, "<")
    -- a wall to bump into / wall-stop test
    g:rect(27, 12, 27, 15, "S"):rect(28, 12, 28, 15, "S")
    -- staircase up to a ledge on the right
    g:rect(38, 15, 39, 15, "#"):rect(40, 14, 41, 14, "#"):rect(42, 13, 50, 13, "#")
    g:set(42, 13, "<")
    -- a one-way platform to hop up through
    g:rect(8, 12, 13, 12, "=")
    g:rect(15, 9, 19, 9, "=")
    return g
end

function M:load()
    self.map = Tilemap.new(buildLevel():rows(), TS)
    self.spawnX, self.spawnY = 4 * TS, 13 * TS
    self.player = Player.new(self.spawnX, self.spawnY)
    self.cam = Camera.new(2)
    self.cam:setBounds(0, 0, self.map:pixelWidth(), self.map:pixelHeight())
    local cx, cy = self.player:center()
    self.cam:snapTo(cx, cy)
end

function M:keypressed(key)
    if key == "r" then
        self.player:setPosition(self.spawnX, self.spawnY)
    else
        self.player:keypressed(key)
    end
end

function M:keyreleased(key) self.player:keyreleased(key) end

function M:update(dt)
    self.player:update(dt, self.map)
    -- fell off the world? respawn
    if self.player.box.y > self.map:pixelHeight() + 40 then
        self.player:setPosition(self.spawnX, self.spawnY)
    end
    local cx, cy = self.player:center()
    self.cam:follow({ x = cx, y = cy, facing = self.player.facing }, dt)
end

function M:draw()
    love.graphics.setColor(0.55, 0.78, 0.95)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1)

    self.cam:attach()
    self.map:draw(self.cam)
    self.player:draw()
    self.cam:detach()

    -- live readout of the controller state (screen space)
    love.graphics.setColor(1, 1, 1, 0.85)
    local p = self.player
    love.graphics.print(string.format(
        "vx % 6.1f   vy % 6.1f   onGround %s   coyote %.2f",
        p.vx, p.vy, tostring(p.onGround), p.coyote),
        12, love.graphics.getHeight() - 24)
end

return M
