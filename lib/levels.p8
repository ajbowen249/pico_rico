pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-->8
-- levels

function load_level(level)
  game_mode = gm_loading_level
  loading_level_state = {
    level = level,
    loading_object = 1,
    loading_state = ls_init,
  }

  level_state = {
    level = level,
    objects = {},
    initialized = false,
  }
end

function draw_loading_level()
  cls()
  local level = game_levels[loading_level_state.level]
  local object_def = level.objects[loading_level_state.loading_object]

  print("loading level " .. level.name, 0, 0, 6)
  print("object: " .. object_def.name, 0, 7, 6)
end

function update_loading_level()
  local level = game_levels[loading_level_state.level]
  if loading_level_state.loading_state == ls_init then
    loading_level_state.loading_state = ls_load
  elseif loading_level_state.loading_state == ls_load then
    local object_def = level.objects[loading_level_state.loading_object]
    local object = { type = object_def.type }

    if object_def.type == ot_terrain_underfill then
      object.color = object_def.color
      local spline = bez_spline_from_string(object_def.spline)
      object.points = spline:sample_with_fixed_length(bezier_spline_sample_incr)
      -- object.points = spline:sample(bezier_spline_sample_incr)
    elseif object_def.type == ot_pickup_rico_bulb then
      object = new_rico_bulb(object_def.location.x, object_def.location.y)
    end

    level_state.objects[#level_state.objects + 1] = object

    loading_level_state.loading_object += 1
    if loading_level_state.loading_object > #level.objects then
      begin_level(loading_level_state.level)
    end
  end
end
