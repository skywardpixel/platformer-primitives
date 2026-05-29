-- Platformer Primitives
-- A menu of small, self-contained Love2D examples that teach the building
-- blocks of a Metroidvania: character control, camera, parallax, transitions.
--
-- Each example lives in examples/<name>.lua and returns a table with:
--   .name, .blurb, .help   (strings shown in the UI)
--   :load()                (called every time the example is entered)
--   :update(dt) :draw()    (the usual loop)
--   :keypressed(k) :keyreleased(k)   (optional)

---@class Example          A playable example module (see examples/*.lua)
---@field name string
---@field blurb string
---@field help string
---@field load fun(self: Example)
---@field update? fun(self: Example, dt: number)
---@field draw? fun(self: Example)
---@field keypressed? fun(self: Example, key: string)
---@field keyreleased? fun(self: Example, key: string)
---@field startSlide? fun(self: Example, side: string, target: integer, spawn: integer[])
---@field startFade? fun(self: Example, target: integer, spawn: integer[])

---@type Example[]
local examples = {
    require("examples.character_controller"),
    require("examples.camera_controller"),
    require("examples.parallax_background"),
    require("examples.map_transition"),
}

local state = "menu"   -- "menu" | "scene"
---@type Example?
local current = nil
local selected = 1
local showHelp = true
local fontSmall, fontBig
local drawMenu, drawHUD  -- forward declarations (defined below)

-- Development smoke test (see love.load). Drives each example through enough
-- frames and inputs to hit the interesting code paths, then quits.
local function saveShot(name)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local cv = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.07, 0.08, 0.12, 1)
    if current then current:draw(); drawHUD() else drawMenu() end
    love.graphics.setCanvas()
    cv:newImageData():encode("png", name)
    print("  shot -> " .. love.filesystem.getSaveDirectory() .. "/" .. name)
end

function runSmokeTest(capture)
    print("== smoke test ==")
    local keys = { "right", "space", "up", "left", "down", "o", "l", "]", "[", "=", "-", "p", "r" }
    state = "menu"; current = nil
    if capture then saveShot("shot_0_menu.png") end
    for i, ex in ipairs(examples) do
        current = ex
        ex:load()
        -- let physics settle, then capture the "clean" view of the example
        for frame = 1, 120 do
            if ex.update then ex:update(1 / 60) end
        end
        ex:draw()
        if capture then saveShot(string.format("shot_%d.png", i)) end
        -- now exercise every key binding for crash coverage
        for _, k in ipairs(keys) do
            if ex.keypressed then ex:keypressed(k) end
        end
        for frame = 1, 60 do
            if ex.update then ex:update(1 / 60) end
        end
        if ex.keyreleased then ex:keyreleased("space") end
        ex:draw()
        -- map_transition: force both a slide and a fade
        if ex.startSlide then ex:startSlide("right", 2, { 2, 12 }) end
        for frame = 1, 12 do ex:update(1 / 60) end
        ex:draw()
        if capture then saveShot("shot_4_slide.png") end
        if ex.startFade then ex:startFade(3, { 19, 12 }) end
        for frame = 1, 18 do ex:update(1 / 60) end
        ex:draw()
        if capture then saveShot("shot_4_fade.png") end
        print(string.format("  [%d] %s ... ok", i, ex.name))
    end
    print("== all examples ran without error ==")
    love.event.quit(0)
end

function love.load(args)
    love.graphics.setDefaultFilter("nearest", "nearest")
    fontSmall = love.graphics.newFont(13)
    fontBig = love.graphics.newFont(22)
    love.graphics.setBackgroundColor(0.07, 0.08, 0.12)

    -- Headless-ish smoke test: `love . --test` runs every example through a
    -- few frames (with some fake input) and quits. Used during development.
    for _, a in ipairs(args or {}) do
        if a == "--test" then runSmokeTest(false) end
        if a == "--shots" then runSmokeTest(true) end
    end
end

local function enter(index)
    current = examples[index]
    current:load()
    state = "scene"
    showHelp = true
end

function love.update(dt)
    dt = math.min(dt, 1 / 30)  -- clamp big hitches (e.g. window drag) for stable physics
    if state == "scene" and current and current.update then current:update(dt) end
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------
function drawMenu()
    local w = love.graphics.getWidth()
    love.graphics.setFont(fontBig)
    love.graphics.setColor(0.9, 0.95, 1)
    love.graphics.printf("Platformer Primitives", 0, 40, w, "center")
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.6, 0.7, 0.85)
    love.graphics.printf("Metroidvania building blocks  -  Love2D", 0, 74, w, "center")

    local y = 130
    for i, ex in ipairs(examples) do
        local sel = (i == selected)
        if sel then
            love.graphics.setColor(0.2, 0.5, 0.9, 0.5)
            love.graphics.rectangle("fill", w / 2 - 230, y - 4, 460, 52, 6, 6)
        end
        love.graphics.setColor(sel and 1 or 0.85, sel and 1 or 0.85, 1)
        love.graphics.setFont(fontBig)
        love.graphics.printf(ex.name, w / 2 - 215, y, 430, "left")
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.6, 0.7, 0.82)
        love.graphics.printf(ex.blurb, w / 2 - 215, y + 26, 430, "left")
        y = y + 64
    end

    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.setFont(fontSmall)
    love.graphics.printf("Up/Down to choose, Enter or 1-4 to open.  Esc quits.",
        0, love.graphics.getHeight() - 36, w, "center")
end

-- ---------------------------------------------------------------------------
-- In-scene HUD
-- ---------------------------------------------------------------------------
function drawHUD()
    if not current then return end
    local w = love.graphics.getWidth()
    -- top bar
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, 26)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.9, 0.95, 1)
    love.graphics.print(current.name, 10, 6)
    love.graphics.setColor(0.55, 0.62, 0.72)
    love.graphics.printf("Esc: menu    H: toggle help", -10, 6, w, "right")

    if showHelp and current.help then
        local lines = current.help
        local _, count = lines:gsub("\n", "\n")
        local boxH = (count + 1) * 16 + 16
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 8, 34, 300, boxH, 4, 4)
        love.graphics.setColor(0.85, 0.92, 1)
        love.graphics.print(lines, 16, 42)
    end
end

function love.draw()
    if state == "menu" then
        drawMenu()
    else
        if current and current.draw then current:draw() end
        drawHUD()
    end
end

-- ---------------------------------------------------------------------------
-- Input routing
-- ---------------------------------------------------------------------------
function love.keypressed(key)
    if state == "menu" then
        if key == "escape" then love.event.quit()
        elseif key == "up" then selected = (selected - 2) % #examples + 1
        elseif key == "down" then selected = selected % #examples + 1
        elseif key == "return" or key == "kpenter" then enter(selected)
        elseif tonumber(key) and examples[tonumber(key)] then enter(tonumber(key)) end
    else
        if key == "escape" then state = "menu"
        elseif key == "h" then showHelp = not showHelp
        elseif current and current.keypressed then current:keypressed(key) end
    end
end

function love.keyreleased(key)
    if state == "scene" and current and current.keyreleased then current:keyreleased(key) end
end
