pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function new_level_end(def)
  local ticks_to_ui = 30
  local ticks_to_end = 90
  local ui_pop_frames = 3

  return {
    name = def.name,
    type = ot_level_end,
    location = new_point(def.location.x, def.location.y),
    ricos_required = def.ricos_required,
    radius = def.radius,
    player_in_area = false,
    has_enough_ricos = false,
    ticks_in_area = 0,
    update = function(self, window, context)
      player_in_area = get_point_distance(self.location, context.rico_center_of_mass) <= self.radius
      self.has_enough_ricos = get_total_ricos() >= self.ricos_required

      if player_in_area and self.player_in_area then
        self.ticks_in_area += 1
      else
        self.ticks_in_area = 0
      end

      if not self.has_enough_ricos and self.ticks_in_area > ticks_to_ui + ui_pop_frames then
        self.ticks_in_area = ticks_to_ui + ui_pop_frames
      end

      self.player_in_area = player_in_area

      if self.has_enough_ricos and self.ticks_in_area >= ticks_to_end then
        end_level_success()
      end
    end,
    draw = function(self, window, context)
      if not self.location:is_in_window(window) or self.ticks_in_area < ticks_to_ui then
        return
      end

      local pop_anim_frame = self.ticks_in_area - ticks_to_ui
      local color = self.has_enough_ricos and 11 or 8
      local anim_point_offset = new_point(0, 0)

      if pop_anim_frame < ui_pop_frames then
        color = 4 - pop_anim_frame
        anim_point_offset.y = pop_anim_frame
      end

      local offset_point = self.location:sub(level_state.camera.location):add(anim_point_offset)
      local start_point = offset_point:add(new_point(-10, 0))
      circfill(start_point.x, start_point.y, 3, color)

      local required_point = start_point:add(new_point(6, -2))
      print("" .. self.ricos_required, required_point.x, required_point.y, color)
    end
  }
end
