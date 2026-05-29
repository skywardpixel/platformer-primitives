-- Example 4: Map / Room Transition
-- Focus: moving between rooms like a Metroidvania. Two transition styles:
--   * EDGE SLIDE - walk off the side of a room; the old room slides out while
--     the new one slides in (the classic Metroid/Zelda feel). Gameplay pauses
--     briefly during the slide.
--   * DOOR FADE  - stand on a glowing door and press Up; the screen fades to
--     black, the room is swapped, then fades back in (good for warps / non-
--     adjacent rooms).
--
-- Rooms are snapshotted into canvases so the transition is just compositing two
-- still images - simple and robust.
local Tilemap = require("lib.tilemap")
local Player  = require("lib.player")
local Camera  = require("lib.camera")
local Grid    = require("lib.level")
local Assets  = require("lib.assets")

local M = {
    name  = "4. Map / Room Transition",
    blurb = "Walk off an edge to slide rooms; use a door to fade-warp.",
    help  = "Move/Jump: arrows / WASD / Space\n"
         .. "Walk off left/right edge:\n"
         .. "   slide to the next room\n"
         .. "Stand on a door + Up:\n"
         .. "   fade-warp\n"
         .. "R: back to room 1",
}

local TS = 16

-- ---------------------------------------------------------------------------
-- Room definitions. Each returns rows + metadata. Exits trigger when the
-- player walks past a side; spawns are floor tiles {tx, ty} the player lands on.
-- ---------------------------------------------------------------------------
local function room1()
    local g = Grid.new(26, 14, ".")
    g:rect(1, 12, 26, 12, "#"):rect(1, 13, 26, 14, "D")
    g:rect(8, 9, 11, 9, "="):rect(14, 7, 17, 7, "=")
    g:rect(20, 8, 21, 11, "S")
    return g:rows()
end

local function room2()
    local g = Grid.new(30, 14, ".")
    g:rect(1, 12, 30, 12, "#"):rect(1, 13, 30, 14, "D")
    -- a little pit with a one-way bridge
    g:rect(12, 12, 16, 14, ".")
    g:rect(12, 10, 16, 10, "=")
    g:rect(22, 9, 24, 11, "S")
    return g:rows()
end

local function room3()
    local g = Grid.new(22, 14, ".")
    g:rect(1, 12, 22, 12, "#"):rect(1, 13, 22, 14, "D")
    g:rect(6, 9, 9, 9, "="):rect(12, 7, 15, 7, "=")
    return g:rows()
end

-- rooms[i] = { build, exits = {side->{target, spawn}}, doors = {{tx,ty,target,spawn}} }
local ROOMS = {
    {
        build = room1,
        exits = { right = { target = 2, spawn = { 2, 12 } } },
        doors = { { tx = 24, ty = 11, target = 3, spawn = { 19, 12 } } },
    },
    {
        build = room2,
        exits = { left = { target = 1, spawn = { 24, 12 } },
                  right = { target = 3, spawn = { 2, 12 } } },
        doors = {},
    },
    {
        build = room3,
        exits = { left = { target = 2, spawn = { 28, 12 } } },
        doors = { { tx = 3, ty = 11, target = 1, spawn = { 4, 12 } } },
    },
}

function M:load()
    self.maps = {}
    for i, r in ipairs(ROOMS) do self.maps[i] = Tilemap.new(r.build(), TS) end
    self.door = Assets.image("assets/door.png")
    self.player = Player.new(0, 0)
    self.cam = Camera.new(3)
    self.trans = nil
    self:goToRoom(1, { 4, 12 })
end

-- Place player feet on floor tile {tx, ty} and reset the camera to the room.
function M:goToRoom(index, spawn)
    self.room = index
    self.map = self.maps[index]
    self.player:setPosition((spawn[1] - 1) * TS, (spawn[2] - 1) * TS - self.player.box.h)
    self.cam:setBounds(0, 0, self.map:pixelWidth(), self.map:pixelHeight())
    local cx, cy = self.player:center()
    self.cam:snapTo(cx, cy)
end

-- ---------------------------------------------------------------------------
-- Drawing one room (no HUD) - used live and for canvas snapshots.
-- ---------------------------------------------------------------------------
function M:drawScene()
    love.graphics.setColor(0.30, 0.26, 0.40)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1)
    self.cam:attach()
    self.map:draw(self.cam)
    -- doors
    for _, dr in ipairs(ROOMS[self.room].doors) do
        local dx = (dr.tx - 1) * TS + TS / 2 - self.door:getWidth() / 2
        local dy = dr.ty * TS - self.door:getHeight()
        love.graphics.draw(self.door, dx, dy)
    end
    self.player:draw()
    self.cam:detach()
end

local function snapshot(self)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local cv = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(cv)
    love.graphics.clear()
    self:drawScene()
    love.graphics.setCanvas()
    return cv
end

-- ---------------------------------------------------------------------------
-- Transitions
-- ---------------------------------------------------------------------------
function M:startSlide(side, target, spawn)
    local old = snapshot(self)
    self:goToRoom(target, spawn)
    local new = snapshot(self)
    self.trans = { kind = "slide", side = side, t = 0, dur = 0.45,
                   old = old, new = new }
end

function M:startFade(target, spawn)
    self.trans = { kind = "fade", t = 0, dur = 0.6, target = target,
                   spawn = spawn, switched = false }
end

function M:update(dt)
    if self.trans then
        local tr = self.trans
        tr.t = tr.t + dt
        if tr.kind == "fade" then
            if not tr.switched and tr.t >= tr.dur / 2 then
                self:goToRoom(tr.target, tr.spawn)
                tr.switched = true
            end
            if tr.t >= tr.dur then self.trans = nil end
        else -- slide finishes on its own
            if tr.t >= tr.dur then self.trans = nil end
        end
        return -- gameplay is paused during a transition
    end

    self.player:update(dt, self.map)
    local cx, cy = self.player:center()
    self.cam:follow({ x = cx, y = cy, facing = self.player.facing }, dt)

    -- edge exits: did the player's centre leave the room sideways?
    local exits = ROOMS[self.room].exits
    if cx < 0 and exits.left then
        self:startSlide("left", exits.left.target, exits.left.spawn)
    elseif cx > self.map:pixelWidth() and exits.right then
        self:startSlide("right", exits.right.target, exits.right.spawn)
    end
end

function M:keypressed(key)
    if key == "r" then
        self.trans = nil
        self:goToRoom(1, { 4, 12 })
        return
    end
    if self.trans then return end
    if key == "up" or key == "w" then
        -- on a door? fade-warp
        local px, py = self.player:center()
        for _, dr in ipairs(ROOMS[self.room].doors) do
            local doorX = (dr.tx - 1) * TS + TS / 2
            local doorY = dr.ty * TS
            if math.abs(px - doorX) < 14 and math.abs(py - (doorY - 12)) < 24 then
                self:startFade(dr.target, dr.spawn)
                return
            end
        end
    end
    self.player:keypressed(key)
end

function M:keyreleased(key) self.player:keyreleased(key) end

function M:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if self.trans and self.trans.kind == "slide" then
        local tr = self.trans
        local p = tr.t / tr.dur
        -- ease in-out
        p = p < 0.5 and 2 * p * p or 1 - (-2 * p + 2) ^ 2 / 2
        local dir = (tr.side == "right") and -1 or 1
        love.graphics.setColor(1, 1, 1)
        -- old room slides off, new room slides in from the opposite side
        love.graphics.draw(tr.old, dir * p * w, 0)
        love.graphics.draw(tr.new, dir * p * w - dir * w, 0)
    else
        self:drawScene()
        if self.trans and self.trans.kind == "fade" then
            local p = self.trans.t / self.trans.dur
            local a = 1 - math.abs(p - 0.5) * 2 -- 0 -> 1 -> 0
            love.graphics.setColor(0, 0, 0, a)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Room " .. self.room .. " / " .. #ROOMS,
        12, h - 24)
end

return M
