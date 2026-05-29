-- A platformer character controller with the little tricks that make a
-- Metroidvania feel good to control:
--
--   * acceleration + friction (not instant velocity) for weighty but snappy run
--   * gravity with a capped fall speed
--   * variable jump height: tap = short hop, hold = full jump
--   * coyote time: you may still jump for a few ms after walking off a ledge
--   * jump buffering: a jump pressed just before landing still fires
--   * one-way platform drop-through (hold Down + jump)
--
-- Collision is delegated to Tilemap:moveActor (axis-separated AABB).
local Assets = require("lib.assets")
local Anim = require("lib.anim")

local Player = {}
Player.__index = Player

-- All values are in world pixels / seconds (internal resolution is 480x270).
local TUNING = {
    gravity     = 900,
    maxFall     = 520,
    runSpeed    = 110,
    accel       = 1000,   -- how fast we reach runSpeed
    friction    = 1200,   -- ground deceleration when no input
    airControl  = 0.6,    -- fraction of accel/friction applied in the air
    jumpSpeed   = 380,    -- initial upward velocity (~5 tiles / 80px high)
    jumpCut     = 0.45,   -- velocity kept when jump released early
    coyoteTime  = 0.08,
    jumpBuffer  = 0.10,
}

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.box = { x = x, y = y, w = 8, h = 20 }
    self.vx, self.vy = 0, 0
    self.facing = 1
    self.onGround = false
    self.coyote = 0      -- time left during which a jump is still allowed
    self.buffer = 0      -- time left on a buffered jump press
    self.jumpHeld = false
    self.cutApplied = true  -- has the variable-height cut been applied this jump?
    self.wantDrop = false
    self.t = TUNING

    local img = Assets.image("assets/player.png")
    self.anims = {
        idle = Anim.new(img, 16, 24, { 0, 1 }, 3),
        run  = Anim.new(img, 16, 24, { 2, 3, 4, 5 }, 12),
        jump = Anim.new(img, 16, 24, { 6 }, 1),
        fall = Anim.new(img, 16, 24, { 7 }, 1),
    }
    self.anim = self.anims.idle
    return self
end

-- centre point, handy for the camera to follow
function Player:center()
    return self.box.x + self.box.w / 2, self.box.y + self.box.h / 2
end

function Player:setPosition(x, y)
    self.box.x, self.box.y = x, y
    self.vx, self.vy = 0, 0
end

-- Call from love.keypressed.
function Player:keypressed(key)
    if key == "space" or key == "z" or key == "up" or key == "w" then
        if self.onGround and love.keyboard.isDown("down", "s") then
            -- Down + jump while grounded: drop through a one-way platform
            -- instead of jumping. (On solid ground this does nothing useful
            -- and is cleared again as soon as we re-land.)
            self.wantDrop = true
        else
            self.buffer = self.t.jumpBuffer
            self.jumpHeld = true
            self.cutApplied = false
        end
    end
end

-- Call from love.keyreleased.
function Player:keyreleased(key)
    if key == "space" or key == "z" or key == "up" or key == "w" then
        self.jumpHeld = false
    end
end

function Player:update(dt, map)
    local t = self.t

    -- ---- horizontal input ----
    local dir = 0
    if love.keyboard.isDown("left", "a")  then dir = dir - 1 end
    if love.keyboard.isDown("right", "d") then dir = dir + 1 end
    if dir ~= 0 then self.facing = dir end

    local control = self.onGround and 1 or t.airControl
    if dir ~= 0 then
        local target = dir * t.runSpeed
        local rate = t.accel * control * dt
        if self.vx < target then
            self.vx = math.min(self.vx + rate, target)
        elseif self.vx > target then
            self.vx = math.max(self.vx - rate, target)
        end
    else
        -- friction toward zero
        local rate = t.friction * control * dt
        if self.vx > 0 then self.vx = math.max(0, self.vx - rate)
        elseif self.vx < 0 then self.vx = math.min(0, self.vx + rate) end
    end

    -- ---- timers ----
    self.coyote = math.max(0, self.coyote - dt)
    self.buffer = math.max(0, self.buffer - dt)

    -- ---- jump (buffered + coyote) ----
    if self.buffer > 0 and self.coyote > 0 then
        self.vy = -t.jumpSpeed
        self.buffer = 0
        self.coyote = 0
        self.onGround = false
    end
    -- variable height: releasing the button early (while still rising) cuts the
    -- upward velocity once, so a tap becomes a short hop.
    if not self.jumpHeld and not self.cutApplied and self.vy < 0 then
        self.vy = self.vy * t.jumpCut
        self.cutApplied = true
    end

    -- ---- gravity ----
    self.vy = math.min(self.vy + t.gravity * dt, t.maxFall)

    -- ---- move + collide ----
    local hit = map:moveActor(self.box, self.vx * dt, self.vy * dt, self.wantDrop)
    if hit.left or hit.right then self.vx = 0 end
    if hit.top and self.vy < 0 then self.vy = 0 end
    if hit.bottom then
        self.vy = 0
        self.onGround = true
        self.coyote = t.coyoteTime
        self.wantDrop = false
    else
        self.onGround = false
    end

    -- ---- pick animation ----
    local a
    if not self.onGround then
        a = self.vy < 0 and self.anims.jump or self.anims.fall
    elseif math.abs(self.vx) > 5 then
        a = self.anims.run
    else
        a = self.anims.idle
    end
    if a ~= self.anim then self.anim = a; a:reset() end
    self.anim:update(dt)
end

function Player:draw()
    -- feet at box bottom, centred horizontally on the box
    self.anim:draw(self.box.x + self.box.w / 2, self.box.y + self.box.h,
        self.facing, 1, 1)
end

return Player
