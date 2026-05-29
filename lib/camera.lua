-- A 2D follow-camera tuned for platformers / Metroidvanias.
--
-- Key ideas demonstrated here:
--   * scale (zoom) so low-res pixel art fills the window
--   * smooth follow via exponential lerp (frame-rate independent)
--   * a dead-zone box: the camera only scrolls once the target leaves it
--   * look-ahead: the view leads in the direction the player faces
--   * level bounds clamping so you never see past the edge of the map
--
-- The camera position (self.x, self.y) is the WORLD point shown at the centre
-- of the screen.
local Camera = {}
Camera.__index = Camera

function Camera.new(scale)
    local self = setmetatable({}, Camera)
    self.x, self.y = 0, 0          -- world point at screen centre
    self.scale = scale or 2
    self.lookAhead = 0             -- current horizontal look-ahead offset (world px)
    -- tunables
    self.smooth = 8                -- higher = snappier follow
    self.deadzoneW = 40            -- half-width of dead-zone in world px
    self.deadzoneH = 30            -- half-height of dead-zone in world px
    self.lookAheadDist = 28        -- how far the camera leads the facing dir
    self.bounds = nil              -- {x, y, w, h} world rect, or nil for free
    return self
end

-- Frame-rate independent smoothing factor.
local function damp(current, target, smooth, dt)
    local t = 1 - math.exp(-smooth * dt)
    return current + (target - current) * t
end

function Camera:viewSize()
    return love.graphics.getWidth() / self.scale,
           love.graphics.getHeight() / self.scale
end

-- Snap instantly to a target (use on room load / teleport to avoid a pan).
function Camera:snapTo(tx, ty)
    self.x, self.y = tx, ty
    self.lookAhead = 0
    self:clamp()
end

-- target: { x, y, facing } (facing 1 / -1). Call every frame.
function Camera:follow(target, dt)
    -- look-ahead eases toward the side the player faces
    local desiredLook = (target.facing or 1) * self.lookAheadDist
    self.lookAhead = damp(self.lookAhead, desiredLook, 4, dt)

    local focusX = target.x + self.lookAhead
    local focusY = target.y

    -- Dead-zone: find where the camera WOULD need to be so the focus point
    -- sits just inside the box. If the focus is already inside, the goal is
    -- the current position (camera holds still).
    local goalX, goalY = self.x, self.y
    local dx = focusX - self.x
    if dx > self.deadzoneW then
        goalX = focusX - self.deadzoneW
    elseif dx < -self.deadzoneW then
        goalX = focusX + self.deadzoneW
    end
    local dy = focusY - self.y
    if dy > self.deadzoneH then
        goalY = focusY - self.deadzoneH
    elseif dy < -self.deadzoneH then
        goalY = focusY + self.deadzoneH
    end

    -- Then ease the camera toward that goal (smooth, frame-rate independent).
    self.x = damp(self.x, goalX, self.smooth, dt)
    self.y = damp(self.y, goalY, self.smooth, dt)
    self:clamp()
end

function Camera:setBounds(x, y, w, h)
    self.bounds = { x = x, y = y, w = w, h = h }
end

-- Keep the visible rectangle inside the level bounds.
function Camera:clamp()
    if not self.bounds then return end
    local vw, vh = self:viewSize()
    local b = self.bounds
    -- horizontal
    if b.w <= vw then
        self.x = b.x + b.w / 2                 -- level narrower than view: centre
    else
        self.x = math.max(b.x + vw / 2, math.min(self.x, b.x + b.w - vw / 2))
    end
    -- vertical
    if b.h <= vh then
        self.y = b.y + b.h / 2
    else
        self.y = math.max(b.y + vh / 2, math.min(self.y, b.y + b.h - vh / 2))
    end
end

-- Begin drawing in world space. Everything until :detach() is transformed.
function Camera:attach()
    local vw, vh = self:viewSize()
    love.graphics.push()
    love.graphics.scale(self.scale, self.scale)
    -- floor the translation so pixels land on integer screen coords (crisp art)
    love.graphics.translate(math.floor(vw / 2 - self.x + 0.5),
                            math.floor(vh / 2 - self.y + 0.5))
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:screenToWorld(sx, sy)
    local vw, vh = self:viewSize()
    return sx / self.scale - vw / 2 + self.x,
           sy / self.scale - vh / 2 + self.y
end

return Camera
