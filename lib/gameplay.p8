pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-->8
-- gameplay

level_state = nil

function despawn(object)
  level_state.objects = filter(level_state.objects, function(obj)
    return obj ~= object
  end)
end

function new_camera(x, y)
  return {
    location = new_point(x, y),
    get_window = function(self)
      return new_window(
        self.location.x,
        self.location.y,
        self.location.x + (screen_size - 1),
        self.location.y + (screen_size - 1)
      )
    end,
  }
end

function get_segments_colliding_with_circle(location, size, window)
  local level = game_levels[level_state.level]
  local intersections = {}

  for object_i, object in ipairs(level_state.objects) do
    if object.type == ot_terrain_underfill then
      local points = get_points_in_window(object.points, window)

      for point_i, point in ipairs(points) do
        if point_i < #points then
          local next = points[point_i + 1]
          local intersecting_points = segment_circle_intersect(point, next, location, size)
          if #intersecting_points > 0 then
            intersections[#intersections + 1] = {
              points = intersecting_points,
              segment = { p1 = point, p2 = next },
            }
          end
        end
      end
    end
  end

  return intersections
end

function get_segments_colliding_with_segment(p1, p2, window)
  local level = game_levels[level_state.level]
  local intersections = {}

  for object_i, object in ipairs(level_state.objects) do
    if object.type == ot_terrain_underfill then
      local points = get_points_in_window(object.points, window)

      for point_i, point in ipairs(points) do
        if point_i < #points then
          local next = points[point_i + 1]
          local intersecting_points = segment_segment_intersect(p1, p2, point, next)
          if #intersecting_points > 0 then
            intersections[#intersections + 1] = {
              points = intersecting_points,
              segment = { p1 = point, p2 = next },
            }
          end
        end
      end
    end
  end

  return intersections
end

-- essentially makes the "smear" of a circle moving from one point to another. the smear is two circles, the start and end, connected with two line segments
-- parallel to the direction of travel tangent to each side of each circle
function make_moving_circle_collider(center, size, velocity)
  local circle1 = { center = center, size = size }
  local circle2 = { center = center:add(velocity), size = size }

  local dir = circle2.center:sub(circle1.center):normal()

  -- rotate 90 degrees counterclockwise to get to segment 1 and clockwise for 2, and project outward our radius
  local to_seg_1 = new_point(-1 * dir.y, dir.x):mul(size)
  local to_seg_2 = new_point(dir.y, -1 * dir.x):mul(size)

  return {
    circle1 = circle1,
    circle2 = circle2,
    seg1 = {
      p1 = circle1.center:add(to_seg_1),
      p2 = circle2.center:add(to_seg_1),
    },
    seg2 = {
      p1 = circle1.center:add(to_seg_2),
      p2 = circle2.center:add(to_seg_2),
    },
  }
end

function get_segments_colliding_with_moving_circle(c1, c2, size, window)
  local level = game_levels[level_state.level]
  local intersections = {}

  for object_i, object in ipairs(level_state.objects) do
    if object.type == ot_terrain_underfill then
      local points = get_points_in_window(object.points, window)

      for point_i, point in ipairs(points) do
        if point_i < #points then
          local next = points[point_i + 1]
          local intersecting_points = moving_circle_segment_intersect(c1, c2, size, point, next)
          if #intersecting_points > 0 then
            intersections[#intersections + 1] = {
              points = intersecting_points,
              segment = { p1 = point, p2 = next },
            }
          end
        end
      end
    end
  end

  return intersections
end

function init_level()
  local level = game_levels[level_state.level]
  level_state.camera = new_camera(-70, -70)
  level_state.initialized = true
  level_state.ricos = {
    new_rico(5, new_point(level.spawn.x, level.spawn.y), 9),
  }

  level_state.rotation = 0
end

function begin_level()
  game_mode = gm_level
end

function end_level_success(end_zone)
  init_level_end_state(end_zone)
  game_mode = gm_level_end
end

debug_hud = false

function get_total_ricos()
  return reduce(level_state.ricos, function(acc, rico)
    return acc + rico.mass
  end, 0)
end

function draw_hud()
  local total_ricos = get_total_ricos()

  -- circfill(6, 6, 3, 10)
  -- print("" .. total_ricos, 12, 4, 10)

  if debug_hud then
    print("" .. level_state.ricos[1].location.x .. ", " .. level_state.ricos[1].location.y, 0, 120)
  end
end

function draw_level()
  local level = game_levels[level_state.level]
  cls(level.background_color)

  if not level_state.initialized then
    return
  end

  local window = level_state.camera:get_window()

  for i, object in ipairs(level_state.objects) do
    if object.type == ot_terrain_underfill then
      local points = map(get_points_in_window(object.points, window, exclude_upper_y), function(point)
        return point:sub(level_state.camera.location)
      end)

      draw_underfill(points, screen_size - 1, object.color)
    elseif object.draw ~= nil then
      object:draw(window)
    end
  end

  for i, rico in ipairs(level_state.ricos) do
    rico:draw(window)
  end

  draw_hud()
end

function apply_level_rotation(rotation, center)
  local angle_diff = rotation - level_state.rotation
  local matrix = make_rotation_matrix(angle_diff)
  for i, object in ipairs(level_state.objects) do
    if object.points ~= nil then
      object.points = map(object.points, function(point)
        return mat21_to_point(mat22_mul_mat_21(matrix, point:sub(center):to_mat21())):add(center)
      end)
    elseif object.location ~= nil then
      object.location = mat21_to_point(mat22_mul_mat_21(matrix, object.location:sub(center):to_mat21())):add(center)
    end
  end

  level_state.rotation = rotation
end

function update_level()
  if not level_state.initialized then
    init_level()
    return
  end

  -- todo: base this on actual average when there is more than one
  local rico_center_of_mass = level_state.ricos[1].location

  level_state.camera.location.x = rico_center_of_mass.x - 64
  level_state.camera.location.y = rico_center_of_mass.y - 64

  local holding_left = btn(0)
  local holding_right = btn(1)

  local rotate_speed = .005
  local rotation = level_state.rotation
  local should_flick = false

  if holding_left and not holding_right then
    rotation += rotate_speed
  elseif holding_right and not holding_left then
    rotation -= rotate_speed
  elseif holding_left and holding_right then
    should_flick = true
  end

  if rotation > max_rotation_angle then
    rotation = max_rotation_angle
  elseif rotation < (max_rotation_angle * -1) then
    rotation = max_rotation_angle * -1
  end

  if rotation ~= level_state.rotation then
    apply_level_rotation(rotation, rico_center_of_mass)
  end

  local window = level_state.camera:get_window()

  local update_context = {
    rico_center_of_mass = rico_center_of_mass,
  }

  for i, rico in ipairs(level_state.ricos) do
    rico:update(window, update_context)
  end

  if should_flick then
    local world_plane_normal = mat21_to_point(mat22_mul_mat_21(make_rotation_matrix(rotation), new_point(1, 0):to_mat21()))

    for i, rico in ipairs(level_state.ricos) do
      rico:on_flick(world_plane_normal)
    end
  end

  for i, object in ipairs(level_state.objects) do
    if object.update ~= nil then
      object:update(window, update_context)
    end
  end
end
