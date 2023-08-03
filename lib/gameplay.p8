pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

-->8
-- gameplay

level_state = nil

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

  for asset_i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[asset_i]
    if asset_def.type == at_underfill then
      local points = get_points_in_window(asset.points, window)

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

  for asset_i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[asset_i]
    if asset_def.type == at_underfill then
      local points = get_points_in_window(asset.points, window)

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

-- note: returns center of circle where it intersects, not the point of intersection!
function moving_circle_segment_intersect(c1, c2, size, p1, p2)
  local plane_normal = p2:sub(p1):normal()

  -- big problem with the assumption i'm about to make when using this for full collision detection:
  -- when transitioning from one segment to another, if the slope goes up or down and the player is going slower than their size, the projected-out segment may
  -- go past the postition segment entirely.

  -- screw, it; right-hand rule. hope i stick to that in level design
  -- by that, i mean if it's possible to hit something from above, it better be going left to right, and right to left for hitting from below
  -- that means the direction to project from is just 90deg counter-clockwize
  -- but i'm actually going to rotate clockwise here because y is flipped from my usual thinking
  local project_direction = new_point(plane_normal.y, -1 * plane_normal.x)

  local max_dist = get_point_distance(c1, c2)
  -- fudge it a little, see above
  max_dist += size

  local project_vector = project_direction:mul(size)

  -- add project_vector to go toward circle
  -- add along plane normal to lengthen by size
  local seg_p1 = p1:add(project_vector):add(plane_normal:mul(size * -1))
  local seg_p2 = p2:add(project_vector):add(plane_normal:mul(size))
  -- return segment_segment_intersect(seg_p1, seg_p2, c1, c2)

  local infinite_hit = line_line_intersect(c1, c2, seg_p1, seg_p2)[1]
  if infinite_hit == nil then
    return {}
  end

  local segment_window = new_window(
    min(seg_p1.x, seg_p2.x),
    min(seg_p1.y, seg_p2.y),
    max(seg_p1.x, seg_p2.x),
    max(seg_p1.y, seg_p2.y)
  )

  if (get_point_distance(c1, infinite_hit) > max_dist and get_point_distance(c2, infinite_hit) > max_dist) or not infinite_hit:is_in_window(segment_window) then
    return {}
  end

  -- printh("d: " .. max_dist .. " d2: " .. get_point_distance(c1, infinite_hit) .. " " .. infinite_hit:to_string() .. " " .. c1:to_string() .. " " .. c2:to_string() .. "\n" .. p1:to_string() .. " " .. p2:to_string() .. " " .. seg_p1:to_string() .. " " .. seg_p2:to_string())
  return { infinite_hit }
end

function get_segments_colliding_with_moving_circle(c1, c2, size, window)
  local level = game_levels[level_state.level]
  local intersections = {}

  for asset_i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[asset_i]
    if asset_def.type == at_underfill then
      local points = get_points_in_window(asset.points, window)

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


function new_rico(size, location, color)
  return {
    size = size,
    location = location,
    velocity = new_point(0, 0),
    color = color,
    contact = nil,
    update = function(self, window)
      local next_velocity = new_point(self.velocity.x, self.velocity.y - gravity)
      local next_speed = next_velocity:len()
      if next_speed > rico_max_speed then
        next_velocity = next_velocity:normal():mul(rico_max_speed)
      end

      -- start out assuming we will be able to happily translate forward. this collider is everything we could be in the next frame
      local collider = make_moving_circle_collider(self.location, self.size, next_velocity)
      local colliding_segments = {}
      for _, seg in ipairs(get_segments_colliding_with_circle(collider.circle1.center, self.size, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_circle(collider.circle2.center, self.size, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_segment(collider.seg1.p1, collider.seg1.p2, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_segment(collider.seg2.p1, collider.seg2.p2, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      -- for _, seg in ipairs(get_segments_colliding_with_moving_circle(collider.circle1.center, collider.circle2.center, self.size, window)) do
      --   colliding_segments[#colliding_segments + 1] = seg
      -- end

      if #colliding_segments == 0 then
        self.location = collider.circle2.center
        self.velocity = next_velocity
        self.contact = nil
        return
      end

      -- "2d hits are like clipping a movement vector or something" -john carmack, i think

      -- assume we were not already partway through something in the previous frame. from here, the collider is probing the level geometry and we want to know
      -- the closest hit. the total distance we could have traveled is the distance between the center points of the two circles. take the point we left
      -- from (which is the point at the tip of the circle in our direction of travel in this case, not the center!) and make a vector to the hit point.
      -- project that vector onto the vector of travel. divide the distance from start point by the total potential distance, and that ratio can be back-applied
      -- to our velocity vector to get our final point. i suspect that does not accurately capture the curvature of the edges of the circles, but we shall see

      -- this is pretty wrong...
      -- i don't even really know how it stops the ball...
      -- second frame, i guess?

      -- problem is if you hit far from the start point without having traveled far, like this:
      --
      --  \  / \
      --   \x\_/
      --    \
      --
      -- start point is bottom of the ball, but hit is on left edge. if it was going slow, the distance halfway around the ball is definitely farther than total
      -- potential travel, so the ratio ends up above 1

      -- amendment 1 per above: distance is from center point, then subtract the radius instead of picking a "start point". also project from center point to hit
      -- point instead of from the old "start point." this at least stopped the first observed >1 ratio. unsure if more cases exist

      -- amendment 2: this is still wrong. new plan: project the segment we intersected out perpendicular to itself by our radius. the intersection of that
      -- segment and the ray of our start position and velocity is the new center point

      -- amendment 3 (todo): the starting assumption is bad thanks to accrued error. let's check if there are any first-circle (current location) hits first and
      -- translate ourselves out of whatever we've sunken into

      function get_dist(pair)
        return pair.distance
      end

      local closest_hit = min_in(map(colliding_segments, function(seg)
        return min_in(map(seg.points, function(point)
          return {
            point = point,
            segment = seg.segment,
            distance = get_point_distance(self.location, point) - self.size,
          }
        end), get_dist)
      end), get_dist)

      -- local next_point = closest_hit.point
      local next_point = moving_circle_segment_intersect(collider.circle1.center, collider.circle2.center, self.size, closest_hit.segment.p1, closest_hit.segment.p2)[1]

      if next_point == nil then
        cls()
        print("(" .. self.location.x .. ", " .. self.location.y .. ")\n")
        print("(" .. closest_hit.segment.p1.x .. ", " .. closest_hit.segment.p1.y .. ")\n")
        print("(" .. closest_hit.segment.p2.x .. ", " .. closest_hit.segment.p2.y .. ")\n")
        print("(" .. collider.circle2.center.x .. ", " .. collider.circle2.center.y .. ")\n")
        stop()
      end

      if next_point == nil then
        next_point = collider.circle2.center
      end

      local distance_ratio = get_point_distance(next_point, self.location) / get_point_distance(collider.circle2.center, self.location)

      -- improve: whyyyyyyyyyyyyy
      if distance_ratio > 1 then
        distance_ratio = 1
      end

      local deflection = reflect_vector_against(
        -- negating velocity because we're thinking of it as the point hovering above the plane rather than the direction we're pointing
        next_velocity:normal():mul(-1),
        closest_hit.segment.p2:sub(closest_hit.segment.p1):normal()
      ):normal():mul(1 - distance_ratio)

      if deflection:len() > rico_max_speed then
        deflection = deflection:normal():mul(rico_max_speed)
      end

      next_velocity = next_velocity:mul(distance_ratio):add(deflection)

      -- if next_point:add(deflection).x < 0 then
      --   cls()
      --   print("(" .. self.location.x .. ", " .. self.location.y .. ")\n")
      --   print("(" .. collider.circle2.center.x .. ", " .. collider.circle2.center.y .. ")\n")
      --   print("(" .. next_point.x .. ", " .. next_point.y .. ")\n")
      --   print("(" .. next_point:add(deflection).x .. ", " .. next_point:add(deflection).y .. ")\n")
      --   print("" .. collider.circle2.center:sub(self.location):len() .. "\n")
      --   print("(" .. closest_hit.segment.p1.x .. ", " .. closest_hit.segment.p1.y .. ")\n")
      --   print("(" .. closest_hit.segment.p2.x .. ", " .. closest_hit.segment.p2.y .. ")\n")
      --   print("(" .. deflection.x .. ", " .. deflection.y .. ")\n")
      --   print("" .. distance_ratio .. "\n")
      --   stop()
      -- end

      self.location = next_point:add(deflection)
      self.contact = closest_hit
    end,
    draw = function(self, window)
      if not self.location:is_in_window(window) then
        return
      end

      circfill(
        self.location.x -
          level_state.camera.location.x,
        self.location.y - level_state.camera.location.y,
        self.size,
        self.color
      )
    end,
    on_flick = function(self, world_plane_normal)
      if self.contact == nil then
        return
      end

      -- local plane_normal = self.contact.segment.p2:sub(self.contact.segment.p1):normal()
      -- local flick_direction = new_point(plane_normal.y, -1 * plane_normal.x)
    local flick_direction = new_point(world_plane_normal.y, -1 * world_plane_normal.x)

      -- todo: base this on force applied to our mass
      self.velocity = self.velocity:add(flick_direction:mul(4))
    end
  }
end

function init_level()
  level_state.camera = new_camera(-70, -70)
  level_state.initialized = true
  level_state.ricos = {
    new_rico(5, new_point(-40, -70), 9),
  }

  level_state.rotation = 0
end

function begin_level()
  game_mode = gm_level
end

function draw_level()
  local level = game_levels[level_state.level]
  cls(level.background_color)

  if not level_state.initialized then
    return
  end

  local window = level_state.camera:get_window()

  for i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[i]
    if asset_def.type == at_underfill then
      local points = map(get_points_in_window(asset.points, window, exclude_upper_y), function(point)
        return new_point(
          point.x - level_state.camera.location.x,
          point.y - level_state.camera.location.y
        )
      end)

      draw_underfill(points, screen_size - 1, asset_def.color)
    end
  end

  for i, rico in ipairs(level_state.ricos) do
    rico:draw(window)
  end

  print("" .. level_state.ricos[1].location.x .. ", " .. level_state.ricos[1].location.y)
end

function apply_level_rotation(rotation, center)
  local angle_diff = rotation - level_state.rotation
  local matrix = make_rotation_matrix(angle_diff)
  for i, asset in ipairs(level_state.assets) do
    asset.points = map(asset.points, function(point)
      return mat21_to_point(mat22_mul_mat_21(matrix, point:sub(center):to_mat21())):add(center)
    end)
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

  for i, rico in ipairs(level_state.ricos) do
    rico:update(window)
  end

  if should_flick then
    local world_plane_normal = mat21_to_point(mat22_mul_mat_21(make_rotation_matrix(rotation), new_point(1, 0):to_mat21()))

    for i, rico in ipairs(level_state.ricos) do
      rico:on_flick(world_plane_normal)
    end
  end
end

