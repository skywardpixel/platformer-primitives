-- A small tile map: storage, rendering (with camera culling) and AABB tile
-- collision. Maps are written as a list of strings so they read like the level
-- looks. Legend:
--
--   '.'  empty
--   '#'  solid grass-topped ground
--   'D'  solid dirt
--   'S'  solid stone
--   '='  one-way platform (you can jump up through it, land on top)
--   '<'  solid, grass left edge
--   '>'  solid, grass right edge
--
-- Tile ids index into tiles.png (one row of 16x16 tiles):
--   0 grass-top, 1 dirt, 2 stone, 3 platform, 4 grass-left, 5 grass-right
local Assets = require("lib.assets")

local Tilemap = {}
Tilemap.__index = Tilemap

-- character -> { quad index, solid, oneway }
local LEGEND = {
    ["."] = nil,
    ["#"] = { 0, solid = true },
    ["D"] = { 1, solid = true },
    ["S"] = { 2, solid = true },
    ["="] = { 3, oneway = true },
    ["<"] = { 4, solid = true },
    [">"] = { 5, solid = true },
}

function Tilemap.new(rows, tileSize)
    local self = setmetatable({}, Tilemap)
    self.tileSize = tileSize or 16
    self.rows = rows
    self.h = #rows
    self.w = 0
    for _, r in ipairs(rows) do self.w = math.max(self.w, #r) end

    self.image = Assets.image("assets/tiles.png")
    local ts = self.tileSize
    self.quads = {}
    local cols = math.floor(self.image:getWidth() / ts)
    for i = 0, cols - 1 do
        self.quads[i] = love.graphics.newQuad(i * ts, 0, ts, ts,
            self.image:getWidth(), self.image:getHeight())
    end
    return self
end

function Tilemap:pixelWidth()  return self.w * self.tileSize end
function Tilemap:pixelHeight() return self.h * self.tileSize end

-- Look up the tile definition at tile coords (1-based). nil if empty/outside.
function Tilemap:tileAt(tx, ty)
    if ty < 1 or ty > self.h then return nil end
    local row = self.rows[ty]
    if tx < 1 or tx > #row then return nil end
    return LEGEND[row:sub(tx, tx)]
end

function Tilemap:isSolid(tx, ty)
    local t = self:tileAt(tx, ty)
    return t ~= nil and t.solid == true
end

function Tilemap:isOneWay(tx, ty)
    local t = self:tileAt(tx, ty)
    return t ~= nil and t.oneway == true
end

-- Draw only the tiles visible through the camera (simple culling).
function Tilemap:draw(camera)
    local ts = self.tileSize
    local x0, y0, x1, y1 = 1, 1, self.w, self.h
    if camera then
        local vw, vh = camera:viewSize()
        x0 = math.max(1, math.floor((camera.x - vw / 2) / ts))
        y0 = math.max(1, math.floor((camera.y - vh / 2) / ts))
        x1 = math.min(self.w, math.ceil((camera.x + vw / 2) / ts) + 1)
        y1 = math.min(self.h, math.ceil((camera.y + vh / 2) / ts) + 1)
    end
    for ty = y0, y1 do
        local row = self.rows[ty]
        for tx = x0, x1 do
            local def = LEGEND[row:sub(tx, tx)]
            if def then
                love.graphics.draw(self.image, self.quads[def[1]],
                    (tx - 1) * ts, (ty - 1) * ts)
            end
        end
    end
end

-- AABB-vs-tilemap movement, resolved one axis at a time. This is the classic,
-- robust approach for platformers: move on X and push out of solids, then move
-- on Y and push out. `box` = {x, y, w, h} (top-left). Returns a table of
-- contact flags so the caller can react (e.g. set onGround, kill velocity).
--
-- `dropThrough` lets the player fall through one-way platforms on demand.
function Tilemap:moveActor(box, dx, dy, dropThrough)
    local ts = self.tileSize
    local hit = { left = false, right = false, top = false, bottom = false }

    -- ---- horizontal ----
    box.x = box.x + dx
    if dx ~= 0 then
        local ty0 = math.floor(box.y / ts) + 1
        local ty1 = math.floor((box.y + box.h - 1) / ts) + 1
        if dx > 0 then
            -- probe the leading (right) edge itself, NOT edge-1: when resting
            -- flush against a wall, edge-1 lands in the empty tile to the left
            -- and the collision flickers.
            local tx = math.floor((box.x + box.w) / ts) + 1
            for ty = ty0, ty1 do
                if self:isSolid(tx, ty) then
                    box.x = (tx - 1) * ts - box.w
                    hit.right = true
                    break
                end
            end
        else
            local tx = math.floor(box.x / ts) + 1
            for ty = ty0, ty1 do
                if self:isSolid(tx, ty) then
                    box.x = tx * ts
                    hit.left = true
                    break
                end
            end
        end
    end

    -- ---- vertical ----
    local prevBottom = box.y + box.h
    box.y = box.y + dy
    if dy ~= 0 then
        local tx0 = math.floor(box.x / ts) + 1
        local tx1 = math.floor((box.x + box.w - 1) / ts) + 1
        if dy > 0 then
            -- probe the leading (bottom) edge itself. Using edge-1 here put the
            -- sample in the empty tile above the ground once the player snapped
            -- to rest, so the ground was lost every other frame -> the twitch.
            local ty = math.floor((box.y + box.h) / ts) + 1
            for tx = tx0, tx1 do
                local landed = self:isSolid(tx, ty)
                -- one-way: only land if we were fully above the platform top
                if not landed and not dropThrough and self:isOneWay(tx, ty) then
                    local platTop = (ty - 1) * ts
                    if prevBottom <= platTop + 1 then landed = true end
                end
                if landed then
                    box.y = (ty - 1) * ts - box.h
                    hit.bottom = true
                    break
                end
            end
        else
            local ty = math.floor(box.y / ts) + 1
            for tx = tx0, tx1 do
                if self:isSolid(tx, ty) then
                    box.y = ty * ts
                    hit.top = true
                    break
                end
            end
        end
    end

    return hit
end

return Tilemap
