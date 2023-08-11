pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function new_level_end(def)
    return {
        name = def.name,
        type = ot_level_end,
        location = new_point(def.location.x, def.location.y),
        ricos_required = ricos_required,
        radius = radius,
        update = function()
        end,
        draw = function()
        end,
    }
end
