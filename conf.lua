-- Love2D configuration. Runs before main.lua.
-- Internal art is 480x270 pixels; we open a 2x window (960x540) and let the
-- examples scale the world up with nearest-neighbour filtering for crisp pixels.
function love.conf(t)
    t.window.title = "Platformer Primitives - Metroidvania building blocks"
    t.window.width = 960
    t.window.height = 540
    t.window.resizable = true
    t.window.minwidth = 480
    t.window.minheight = 270
    t.window.vsync = 1
    t.console = false
end
