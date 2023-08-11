pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function new_rico_bulb(x, y)
  return {
    type = ot_pickup_rico_bulb,
    location = new_point(x, y),
    radius = 4,
    draw = function(self)
      local p = self.location:sub(level_state.camera.location)
      spr(1, p.x - 4, p.y - 4);
    end,
    update = function(self)
      local touching_ricos = filter(level_state.ricos, function(rico)
        local distance = get_point_distance(rico.location, self.location)
        return distance <= rico.radius + self.radius
      end)

      if #touching_ricos == 0 then
        return
      end

      -- maybe this should be the closest, but, if they're all touching, does it really matter?
      local touching_rico = touching_ricos[1]

      touching_rico:set_mass(touching_rico.mass + 1)
      despawn(self)
    end,
  }
end
