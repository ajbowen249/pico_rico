pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function new_rico_bulb(x, y)
  return {
    type = ot_pickup_rico_bulb,
    location = new_point(x, y),
    radius = 4,
    co_controller = new_co_controller(),
    was_touched = false,
    draw = function(self)
      local p = self.location:sub(level_state.camera.location)
      spr(self.was_touched and 2 or 1, p.x - 4, p.y - 4);
    end,
    update = function(self)
      if self.was_touched then
        self.co_controller:process()
        return
      end

      local touching_ricos = filter(level_state.ricos, function(rico)
        local distance = get_point_distance(rico.location, self.location)
        return distance <= rico.radius + self.radius
      end)

      if #touching_ricos == 0 then
        return
      end

      -- maybe this should be the closest, but, if they're all touching, does it really matter?
      self:on_touch(touching_ricos[1])
    end,
    on_touch = function(self, touched_rico)
      self.was_touched = true
      self.co_controller:add(function()
        local anim_frames = 5

        for frame_count = 1, anim_frames do
          local t = frame_count / anim_frames
          self.location = lerp_2d(self.location, touched_rico.location, t)
          yield()
        end

        touched_rico:set_mass(touched_rico.mass + 1)
        despawn(self)
      end)
    end,
  }
end
