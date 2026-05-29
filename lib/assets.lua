-- Tiny asset cache. Loads images once, with nearest-neighbour filtering so the
-- pixel art stays sharp when scaled up.
local Assets = { _images = {} }

function Assets.image(path)
    if not Assets._images[path] then
        local img = love.graphics.newImage(path)
        img:setFilter("nearest", "nearest")
        Assets._images[path] = img
    end
    return Assets._images[path]
end

return Assets
