pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- constants
screen_size = 128

rico_size_min = 5
rico_size_max = 20

exclude_upper_y = { min_y = true } -- min_y because 0 is top

gravity = -.4
rico_max_speed = 4
max_rotation_angle = 30 / 360

-- game mode
gm_menu = 1
gm_loading_level = 2
gm_level = 3

-- improve: fixed-length sampling!
bezier_spline_sample_incr = .25

-- global state
game_mode = gm_menu

function set_game_mode(mode)
  game_mode = mode
end

-->8
-- library functions

function map(array, func)
  local out = {}
  for i, v in ipairs(array) do
    out[i] = func(v, i)
  end

  return out
end

function filter(array, func)
  local filtered = {}
  for i, v in ipairs(array) do
    if func(v, i) then
      filtered[#filtered + 1] = v
    end
  end

  return filtered
end

function reduce(array, func, acc_init)
  local acc = acc_init
  for i, v in ipairs(array) do
    if func(v, i) then
      acc = func(acc, v)
    end
  end

  return acc
end

function count_ex(array, func)
  local c = 0
  for _, v in ipairs(array) do
    if func(v) then
      c = c + 1
    end
  end
  return c
end

function some(array, func)
  for _, v in ipairs(array) do
    if func(v) then
      return true
    end
  end

  return false
end

function all_t(array, func)
  for _, v in ipairs(array) do
    if not func(v) then
      return false
    end
  end

  return true
end

function min_in(array, getter)
  local smallest_value = nil
  local smallest_element

  for _, v in ipairs(array) do
    local value = getter ~= nil and getter(v) or v
    if smallest_value == nil or value < smallest_value then
      smallest_value = value
      smallest_element = v
    end
  end

  return smallest_element
end

-->8
-- math functions
function sign_of(val)
  return val < 0 and -1 or 1
end

function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
end

function new_point(x, y)
  return {
    x = x,
    y = y,
    equals = function(self, p2)
      return self.x == p2.x and self.y == p2.y
    end,
    add = function(self, p2)
      return new_point(self.x + p2.x, self.y + p2.y)
    end,
    sub = function(self, p2)
      return new_point(self.x - p2.x, self.y - p2.y)
    end,
    mul = function(self, scaler)
      return new_point(self.x * scaler, self.y * scaler)
    end,
    div = function(self, scaler)
      return new_point(self.x / scaler, self.y / scaler)
    end,
    len = function(self)
      return sqrt(((self.x) * (self.x)) + (self.y * self.y))
    end,
    normal = function(self)
      return self:div(self:len())
    end,
    dot = function(self, p2)
      return (self.x * p2.x) + (self.y * p2.y)
    end,
    is_in_window = function(self, window, exclude)
      return ((exclude ~= nil and exclude.min_x == true) or self.x >= window.min_x) and
             ((exclude ~= nil and exclude.max_x == true) or self.x <= window.max_x) and
             ((exclude ~= nil and exclude.min_y == true) or self.y >= window.min_y) and
             ((exclude ~= nil and exclude.max_y == true) or self.y <= window.max_y)
    end,
    to_mat21 = function(self)
      return {
        { self.x },
        { self.y },
      }
    end
  }
end

function mat21_to_point(mat21)
  return new_point(mat21[1][1], mat21[2][1])
end

-- takes points. from a data persepctive points and vectors are the same thing \_(ツ)_/
-- for convention, i guess let's start using letters for vectors and pn for points
function project_vectors(a, b)
  local blen = b:len()
  local scaler = a:dot(b) / (blen * blen)
  return b:mul(scaler)
end

function reflect_vector_against(a, n)
  return a:sub(n:mul(2 * a:dot(n)))
end

-- https://mathworld.wolfram.com/circle-lineintersection.html
function segment_circle_intersect(_p1, _p2, c, r)
  -- this formula is for a circle at (0, 0), so we need to offset the points going in
  local p1 = _p1:sub(c)
  local p2 = _p2:sub(c)
  local _d = p2:sub(p1)
  local dr = _d:len()
  local d = (p1.x * p2.y) - (p2.x * p1.y)

  local r2 = r * r
  local dr2 = dr * dr
  local discriminant = (r2 * dr2) - (d * d)
  local common = sqrt(discriminant)

  -- there could be up to two intersection points
  function get_x(sign)
    return ((d * _d.y) + (sign_of(_d.y) * _d.x * common * sign)) / dr2
  end

  function get_y(sign)
    return ((-1 * d * _d.x) + (abs(_d.y) * common * sign)) / dr2
  end

  -- not totally sure what to do about the 4 solutions to the quadratic equation. initially thought it would be that they paired two solutions, one where we add
  -- to get (x1, y1) and subtract to get (x2, y2). doesn't seem to be the case. current guess is there are 2-4 extraneous solutions and anything farther away
  -- than r is extraneous

  local segment_window = new_window(
    min(_p1.x, _p2.x),
    min(_p1.y, _p2.y),
    max(_p1.x, _p2.x),
    max(_p1.y, _p2.y)
  )

  local solutions = filter({
    -- adding because we initially subtracted to offset
    new_point(get_x(1), get_y(1)):add(c),
    new_point(get_x(-1), get_y(-1)):add(c),
    new_point(get_x(1), get_y(-1)):add(c),
    new_point(get_x(-1), get_y(1)):add(c),
  }, function(p)
    return p:is_in_window(segment_window) and get_point_distance(p, c) <= r
  end)

  if discriminant < 0 then
    return {}
  elseif discriminant == 0 then
    return { solutions[1] }
  elseif discriminant > 0 then
    return solutions
  end
end

--https://en.wikipedia.org/wiki/line%e2%80%93line_intersection#given_two_points_on_each_line
function line_line_intersect(p1, p2, p3, p4)
  local denominator = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  if denominator == 0 then
    return {}
  end

  local common_1 = (p1.x * p2.y) - (p1.y * p2.x)
  local common_2 = (p3.x * p4.y) - (p3.y * p4.x)

  return {
    new_point(
      (common_1 * (p3.x - p4.x) - (p1.x - p2.x) * common_2) / denominator,
      (common_1 * (p3.y - p4.y) - (p1.y - p2.y) * common_2) / denominator
    )
  }
end

--https://en.wikipedia.org/wiki/line%e2%80%93line_intersection#given_two_points_on_each_line_segment
function segment_segment_intersect(p1, p2, p3, p4)
  local tn = ((p1.x - p3.x) * (p3.y - p4.y)) - ((p1.y - p3.y) * (p3.x - p4.x))
  local td = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  local t = tn / td

  local un = ((p1.x - p3.x) * (p1.y - p2.y)) - ((p1.y - p3.y) * (p1.x - p2.x))
  local ud = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  local u = un / ud

  local segment_1_window = new_window(
    min(p1.x, p2.x),
    min(p1.y, p2.y),
    max(p1.x, p2.x),
    max(p1.y, p2.y)
  )

  local segment_2_window = new_window(
    min(p3.x, p4.x),
    min(p3.y, p4.y),
    max(p3.x, p4.x),
    max(p3.y, p4.y)
  )

  local p = nil

  if t >= 0 and t <= 1 then
    p = new_point(
      p1.x + (t * (p2.x - p1.x)),
      p1.y + (t * (p2.y - p1.y))
    )
  elseif u >= 0 and u <= 1 then
    p = new_point(
      p3.x + (u * (p4.x - p3.x)),
      p3.y + (u * (p4.y - p3.y))
    )
  end

  if p ~= nil and p:is_in_window(segment_1_window) and p:is_in_window(segment_2_window) then
    return { p }
  else
    return {}
  end
end

function contains_point(array, p)
  return some(array, function(v)
    return p:equals(v)
  end)
end

function lerp_2d(p0, p1, t)
  return new_point(
    lerp(p0.x, p1.x, t),
    lerp(p0.y, p1.y, t)
  )
end

function mat22_mul_mat_21(mat22, mat21)
  return {
    { (mat22[1][1] * mat21[1][1]) + (mat22[1][2] * mat21[2][1]) },
    { (mat22[2][1] * mat21[1][1]) + (mat22[2][2] * mat21[2][1]) },
  }
end

function make_rotation_matrix(angle)
  return {
    { cos(angle), -1 * sin(angle) },
    { sin(angle),      cos(angle) },
  }
end

function new_window(min_x, min_y, max_x, max_y)
  return {
   min_x = min_x,
   min_y = min_y,
   max_x = max_x,
   max_y = max_y,
  }
end

-- improve: should optimize this with some kind of caching
function get_points_in_window(points, window, exclude)
  return filter(points, function(point, i)
    return point:is_in_window(window, exclude) or
      (i > 1 and points[i - 1]:is_in_window(window, exclude)) or
      (i < #points and points[i + 1]:is_in_window(window, exclude))
  end)
end

function get_point_distance(p1, p2)
  return p2:sub(p1):len()
end

-->8
-- bezier functions

function new_cubic_bezier(p1, p2, p3, p4)
  return {
    p1 = p1,
    p2 = p2,
    p3 = p3,
    p4 = p4,
    get_point = function(self, index)
      if index == 1 then
        return self.p1
      elseif index == 2 then
        return self.p2
      elseif index == 3 then
        return self.p3
      else
        return self.p4
      end
    end,
  }
end

function new_cubic_bezier_spline(...)
  return {
    curves = { ... },
    sample = function(self, incr)
      -- improve: still using lerp form. could be polynomial...

      local points = {}
      for _, curve in ipairs(self.curves) do
        local t = 0
        while (t <= 1) do
          if t > 1 then
            t = 1
          end

          local q0 = lerp_2d(
            curve.p1,
            curve.p2,
            t
          )

          local q1 = lerp_2d(
            curve.p2,
            curve.p3,
            t
          )

          local q2 = lerp_2d(
            curve.p3,
            curve.p4,
            t
          )

          local r0 = lerp_2d(q0, q1, t)
          local r1 = lerp_2d(q1, q2, t)

          local b = lerp_2d(r0, r1, t)

          if #points == 0 or not b:equals(points[#points]) then
            points[#points + 1] = b
          end

          t = t + incr
        end
      end

      return points
    end,
    sample_with_fixed_length = function(self)
      -- improve: this is hacked into place to see if long segments are part of the physics issues
      local incr = 0.01
      local target_dist = 50
      local points = {}
      for _, curve in ipairs(self.curves) do
        local t = 0
        while (t <= 1) do
          if t > 1 then
            t = 1
          end

          local q0 = lerp_2d(
            curve.p1,
            curve.p2,
            t
          )

          local q1 = lerp_2d(
            curve.p2,
            curve.p3,
            t
          )

          local q2 = lerp_2d(
            curve.p3,
            curve.p4,
            t
          )

          local r0 = lerp_2d(q0, q1, t)
          local r1 = lerp_2d(q1, q2, t)

          local b = lerp_2d(r0, r1, t)

          local at_distance = #points == 0 or get_point_distance(b, points[#points]) >= target_dist

          if at_distance and (#points == 0 or not b:equals(points[#points])) then
            points[#points + 1] = b
          end

          t = t + incr
        end
      end

      return points
    end,
  }
end

-->8
-- general drawing functions

function draw_underfill(points, to_y, col)
  for i, p in ipairs(points) do
    if i < #points then
      local next = points[i + 1]

      -- this may lead to back-draw, but that's fine. this is what it is and the curves need to deal
      -- some playing around suggests having a color generator could even make that a feature...
      local rise = next.y - p.y
      local run = next.x - p.x
      local slope = rise / run

      local drawing_point = new_point(p.x, p.y)
      while drawing_point.x <= next.x do
        rect(drawing_point.x, drawing_point.y, drawing_point.x, to_y, col)
        drawing_point.x += 1
        drawing_point.y += slope
      end
    end
  end
end

-->8
-- serlialization functions
function bez_spline_to_string(spline)
  local str = ""

  str = str .. #spline.curves .. ","

  for curve_i,curve in ipairs(spline.curves) do
    for i = 1, 4, 1 do
      local p = curve:get_point(i)
      str = str .. p.x .. "," .. p.y
      if i < 4 then
        str = str .. ","
      end
    end

    if curve_i < #spline.curves then
      str = str .. ","
    end
  end

  return str
end

function bez_spline_from_string(str)
  local tokens = split(str)
  function next_token()
    return tonum(deli(tokens, 1))
  end

  local num_segments = next_token()
  local curves = {}

  if #tokens ~= num_segments * 8 then
    stop("expected " .. num_segments * 8 .. " more numbers. got " .. #tokens)
  end

  for i = 1, num_segments, 1 do
    curves[i] = new_cubic_bezier(
      new_point(next_token(), next_token()),
      new_point(next_token(), next_token()),
      new_point(next_token(), next_token()),
      new_point(next_token(), next_token())
    )
  end

  return new_cubic_bezier_spline(unpack(curves))
end


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

function new_rico(size, location, color)
  return {
    size = size,
    location = location,
    velocity = new_point(0, 0),
    color = color,
    contact = nil,
    draw_coll = function(self, window)
      -- line(self.location.x - 5, self.location.y - 5, self.location.x + 5, self.location.y + 5, 14)
      -- local colliding_segments = get_segments_colliding_with_segment(self.location:sub(new_point(5, 5)), self.location:add(new_point(5, 5)), window)
      local colliding_segments = get_segments_colliding_with_circle(self.location, self.size, window)
      if #colliding_segments > 0 then
        for _, seg in ipairs(colliding_segments) do
          line(seg.segment.p1.x + window.min_x, seg.segment.p1.y + window.min_y, seg.segment.p2.x + window.min_x, seg.segment.p2.y + window.min_y, 14)

          for __, col_point in ipairs(seg.points) do
            pset(col_point.x, col_point.y, 11)
          end
        end
      end
    end,
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

      local plane_normal = closest_hit.segment.p2:sub(closest_hit.segment.p1):normal()

      -- screw, it; right-hand rule. hope i stick to that in level design
      -- by that, i mean if it's possible to hit something from above, it better be going left to right, and right to left for hitting from below
      -- that means the direction to project from is just 90deg counter-clockwize
      -- but i'm actually going to rotate clockwise here because y is flipped from my usual thinking
      local project_direction = new_point(plane_normal.y, -1 * plane_normal.x)
      local project_vector = project_direction:mul(self.size)

      local seg_p1 = closest_hit.segment.p1:add(project_vector)
      local seg_p2 = closest_hit.segment.p2:add(project_vector)
      local new_point = line_line_intersect(seg_p1, seg_p2, self.location, collider.circle2.center)[1]

      if new_point == nil then
        cls()
        print("(" .. self.location.x .. ", " .. self.location.y .. ")\n")
        print("(" .. closest_hit.segment.p1.x .. ", " .. closest_hit.segment.p1.y .. ")\n")
        print("(" .. closest_hit.segment.p2.x .. ", " .. closest_hit.segment.p2.y .. ")\n")
        print("(" .. plane_normal.x .. ", " .. plane_normal.y .. ")\n")
        print("(" .. project_direction.x .. ", " .. project_direction.y .. ")\n")
        print("(" .. project_direction:mul(self.size).x .. ", " .. project_direction:mul(self.size).y .. ")\n")
        print("(" .. collider.circle2.center.x .. ", " .. collider.circle2.center.y .. ")\n")
        stop()
      end

      local distance_ratio = get_point_distance(new_point, self.location) / get_point_distance(collider.circle2.center, self.location)

      local deflection = reflect_vector_against(
        -- negating velocity because we're thinking of it as the point hovering above the plane rather than the direction we're pointing
        next_velocity:normal():mul(-1),
        closest_hit.segment.p2:sub(closest_hit.segment.p1):normal()
      ):normal():mul(1 - distance_ratio)

      next_velocity = next_velocity:mul(distance_ratio):add(deflection)
      self.location = new_point:add(deflection)
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

      self:draw_coll(window)
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
    new_rico(5, new_point(50, -40), 9),
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
  for i, asset in ipairs(level_state.assets) do
    asset.points = map(asset.points, function(point)
      return mat21_to_point(mat22_mul_mat_21(make_rotation_matrix(angle_diff), point:sub(center):to_mat21())):add(center)
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

-->8
-- levels

-- asset types
at_underfill = 1

game_levels = {
  {
    name = "level 1",
    background_color = 12,
    assets = {
      {
        name = "level_floor",
        type = at_underfill,
        spline = "37,-166.72409057617188,-0.7519989013671875,-157.89453125,-0.725616455078125,-110.53113555908203,-0.828155517578125,-85.0422592163086,-0.7519989013671875,-85.0422592163086,-0.7519989013671875,-76.21269989013672,-0.725616455078125,-48.19500732421875,11.183868408203125,-42.68403625488281,26.55957794189453,-42.68403625488281,26.55957794189453,-39.70491027832031,34.87139129638672,-27.018783569335938,61.58518981933594,-18.024826049804688,75.21943664550781,-18.024826049804688,75.21943664550781,-15.631082534790039,78.84819412231445,-2.7071070671081543,78.0,-2.0,78.0,-2.0,78.0,-2.384185791015625e-07,78.0,72.05933380126953,77.66058731079102,73.0,78.0,73.0,78.0,84.69535827636719,82.21993637084961,85.0,94.0,93.0,98.0,93.0,98.0,93.8944320678711,98.44721603393555,96.35372161865234,100.69100952148438,105.0,98.0,105.0,98.0,114.99388885498047,94.88956832885742,116.94491577148438,94.07145690917969,126.0,94.0,126.0,94.0,139.993896484375,93.88956832885742,143.33071899414062,95.6159896850586,152.0,93.0,152.0,93.0,158.993896484375,90.88956451416016,157.97784423828125,90.2248764038086,167.0,91.0,167.0,91.0,188.993896484375,92.88956832885742,222.94473266601562,93.04546737670898,232.0,93.0,232.0,93.0,253.993896484375,92.88956832885742,271.2315979003906,69.4482650756836,287.0601501464844,57.60420227050781,287.0601501464844,57.60420227050781,304.66998291015625,44.42726135253906,335.00909423828125,2.5120620727539062,354.13739013671875,-2.48126220703125,354.13739013671875,-2.48126220703125,368.076904296875,-6.120086669921875,400.711669921875,-11.80889892578125,434.41021728515625,-16.2835693359375,434.41021728515625,-16.2835693359375,468.1087951660156,-20.75823974609375,502.8711242675781,-24.018783569335938,521.0657348632812,-22.801071166992188,521.0657348632812,-22.801071166992188,535.440185546875,-21.839035034179688,556.3289794921875,-22.850830078125,578.01513671875,-22.6602783203125,578.01513671875,-22.6602783203125,599.7012329101562,-22.4697265625,622.1847534179688,-21.076797485351562,639.748779296875,-15.3052978515625,639.748779296875,-15.3052978515625,653.4354248046875,-10.807891845703125,748.0767211914062,-21.465774536132812,846.5719604492188,-22.69158935546875,846.5719604492188,-22.69158935546875,945.0671997070312,-23.917404174804688,1047.4163818359375,-15.711166381835938,1076.5189208984375,26.51453399658203,1076.5189208984375,26.51453399658203,1111.9345703125,77.90015029907227,1117.1243896484375,100.69615745544434,1127.9586181640625,119.95756149291992,1127.9586181640625,119.95756149291992,1138.7928466796875,139.2189655303955,1155.271484375,154.94579315185547,1213.2646484375,192.19313049316406,1213.2646484375,192.19313049316406,1234.25146484375,205.67235565185547,1264.820556640625,230.87466430664062,1317.1585693359375,252.13462829589844,1317.1585693359375,252.13462829589844,1369.49658203125,273.39459228515625,1443.603759765625,290.71221923828125,1551.666748046875,288.4220275878906,1551.666748046875,288.4220275878906,1610.892333984375,287.16685485839844,1672.107666015625,280.4671936035156,1738.6260986328125,261.0617980957031,1738.6260986328125,261.0617980957031,1805.14453125,241.65640258789062,1876.966064453125,209.54523468017578,1957.4041748046875,157.467041015625,1957.4041748046875,157.467041015625,1978.244140625,143.97458267211914,1987.241455078125,117.75905990600586,2022.78759765625,83.33960723876953,2022.78759765625,83.33960723876953,2058.333740234375,48.92015838623047,2120.4287109375,6.296775817871094,2247.463623046875,-40.01139831542969,2247.463623046875,-40.01139831542969,2375.70849609375,-86.76063537597656,2496.8779296875,-119.14553833007812,2642.87548828125,-141.63467407226562,2642.87548828125,-141.63467407226562,2788.873046875,-164.12380981445312,2959.698486328125,-176.71710205078125,3187.255126953125,-183.88287353515625,3187.255126953125,-183.88287353515625,3512.40869140625,-194.12197875976562,3604.80078125,-196.91949462890625,3652.53173828125,-196.799560546875,3652.53173828125,-196.799560546875,3700.262939453125,-196.67962646484375,3703.3330078125,-193.64224243164062,3849.841796875,-192.21148681640625,3849.841796875,-192.21148681640625,4051.4111328125,-190.2430419921875,4134.6943359375,-190.95840454101562,4204.21240234375,-191.8082275390625,4204.21240234375,-191.8082275390625,4273.73046875,-192.65805053710938,4329.4833984375,-193.64224243164062,4475.9921875,-192.21148681640625,4475.9921875,-192.21148681640625,4677.5615234375,-190.2430419921875,4833.42431640625,-185.83511352539062,4949.818359375,-198.3079833984375,4949.818359375,-198.3079833984375,5066.21240234375,-210.78085327148438,5143.1376953125,-240.134521484375,5186.83203125,-305.689208984375,5186.83203125,-305.689208984375,5257.33984375,-411.4725341796875,5332.48583984375,-561.9086303710938,5397.6923828125,-702.6862182617188,5397.6923828125,-702.6862182617188,5462.89892578125,-843.4638061523438,5518.166015625,-974.5830078125,5548.916015625,-1041.732666015625",
        color = 2,
      },
    },
  }
}

loading_level_state = nil

-- loading states
ls_init = 1
ls_load = 2

function load_level(level)
  game_mode = gm_loading_level
  loading_level_state = {
    level = level,
    loading_asset = 1,
    loading_state = ls_init,
  }

  level_state = {
    level = level,
    assets = {},
    initialized = false,
  }
end

function draw_loading_level()
  cls()
  local level = game_levels[loading_level_state.level]
  local asset_def = level.assets[loading_level_state.loading_asset]

  print("loading level " .. level.name, 0, 0, 6)
  print("asset: " .. asset_def.name, 0, 7, 6)
end

function update_loading_level()
  local level = game_levels[loading_level_state.level]
  if loading_level_state.loading_state == ls_init then
    loading_level_state.loading_state = ls_load
  elseif loading_level_state.loading_state == ls_load then
    local asset_def = level.assets[loading_level_state.loading_asset]
    local asset = { }

    if asset_def.type == at_underfill then
      asset.color = asset_def.color
      local spline = bez_spline_from_string(asset_def.spline)
      asset.points = spline:sample_with_fixed_length(bezier_spline_sample_incr)
      -- asset.points = spline:sample(bezier_spline_sample_incr)
    end

    level_state.assets[#level_state.assets + 1] = asset

    loading_level_state.loading_asset += 1
    if loading_level_state.loading_asset > #level.assets then
      begin_level(loading_level_state.level)
    end
  end
end

-->8
-- main menu

-- screens
main_menu_state = nil
mms_main = 1
mms_level_select = 2

main_menu_screens = {
  {
    name = "main menu",
    options = {
      {
        name = "level select",
        action = function()
          main_menu_state.screen = mms_level_select
        end,
      },
      {
        name = "quit",
        action = function()
          cls()
          stop()
        end,
      },
    }
  },
  {
    name = "level select",
    previous = mms_main,
    options = {
      {
        name = "test level",
        action = function()
          load_level(1)
        end,
      },
    }
  },
}

function new_main_menu()
  return {
    screen = 1,
    selected_option = 1,
  }
end

function draw_main_menu()
  cls()
  local screen = main_menu_screens[main_menu_state.screen]
  print(screen.name, 0, 0, 6)

  for i, v in ipairs(screen.options) do
    local y = (i + 1) * 7
    print(v.name, 0, y, main_menu_state.selected_option == i and 11 or 6)
  end
end

function update_main_menu()
  if main_menu_state == nil then
    main_menu_state = new_main_menu()
  end

  local screen = main_menu_screens[main_menu_state.screen]

  local changed_selection = false
  if btnp(2) then
    changed_selection = true
    main_menu_state.selected_option -= 1
  end

  if btnp(3) then
    changed_selection = true
    main_menu_state.selected_option += 1
  end

  if changed_selection then
    if main_menu_state.selected_option <= 1 then
      main_menu_state.selected_option = 1
    elseif main_menu_state.selected_option > #screen.options then
      main_menu_state.selected_option = #screen.options
    end
  end

  if btnp(5) then
    screen.options[main_menu_state.selected_option].action()
  end

  if btnp(4) and screen.previous then
    main_menu_state.screen = screen.previous
  end
end

-->8
-- root hooks

draw_map = {
  draw_main_menu,
  draw_loading_level,
  draw_level,
}

update_map = {
  update_main_menu,
  update_loading_level,
  update_level,
}

last_update_mode = 0

function _draw()
  if last_update_mode ~= game_mode then
    return
  end

  draw_map[game_mode]()
end

function _update()
  update_map[game_mode]()
  last_update_mode = game_mode
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
