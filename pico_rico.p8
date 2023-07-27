pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- constants
screen_size = 128

rico_size_min = 5
rico_size_max = 20

exclude_upper_y = { min_y = true } -- min_y because 0 is top

gravity = -.4
rico_max_speed = 3

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
    local value = getter != nil and getter(v) or v
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
      return ((exclude != nil and exclude.min_x == true) or self.x >= window.min_x) and
             ((exclude != nil and exclude.max_x == true) or self.x <= window.max_x) and
             ((exclude != nil and exclude.min_y == true) or self.y >= window.min_y) and
             ((exclude != nil and exclude.max_y == true) or self.y <= window.max_y)
    end,
  }
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

  if p != nil and p:is_in_window(segment_1_window) and p:is_in_window(segment_2_window) then
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
  local d = p2:sub(p1)
  return sqrt((d.x * d.x) + (d.y * d.y))
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

  if #tokens != num_segments * 8 then
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

      -- amendment 2 (todo): the starting assumption is bad thanks to accrued error. let's check if there are any first-circle (current location) hits first and
      -- translate ourselves out of whatever we've sunken into

      local closest_hit = min_in(map(colliding_segments, function(seg)
        return min_in(map(seg.points, function(point)
          return {
            point = point,
            segment = seg.segment,
            distance = get_point_distance(self.location, point) - self.size,
          }
        end), function(pair)
          return pair.distance
        end)
      end), function(pair)
        return pair.distance
      end)

      local to_hit = closest_hit.point:sub(self.location)
      local total_distance = collider.circle2.center:sub(collider.circle1.center)

      local hit_on_total = project_vectors(to_hit, total_distance)
      local distance_ratio = hit_on_total:len() / get_point_distance(self.location, collider.circle2.center)

      -- cls()
      -- print("ratio: " .. distance_ratio .. "\n")
      -- print("len: " .. hit_on_total:len() .. "\n")
      -- print("total: " .. get_point_distance(self.location, collider.circle2.center) .. "\n")
      -- print("start: (" .. self.location.x .. ", " .. self.location.y .. ")\n")
      -- print("hit: (" .. closest_hit.point.x .. ", " .. closest_hit.point.y .. ")\n")
      -- print("on: (" .. hit_on_total.x .. ", " .. hit_on_total.y .. ")\n")
      -- stop()

      -- next step: deflection. could it be as simple as reflecting velocity noramal against the segment we hit and giving 1-ratio along that to velocity?

      local deflection = reflect_vector_against(
        -- negating velocity because we're thinking of it as the point hovering above the plane rather than the direction we're pointing
        next_velocity:normal():mul(-1),
        closest_hit.segment.p2:sub(closest_hit.segment.p1):normal()
      ):normal():mul(1 - distance_ratio)

      next_velocity = next_velocity:mul(distance_ratio):add(deflection)
      self.location = self.location:add(next_velocity)
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
  }
end

function init_level()
  level_state.camera = new_camera(-70, -70)
  level_state.initialized = true
  level_state.ricos = {
    new_rico(5, new_point(-50, -60), 9),
  }
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
end

function update_level()
  if not level_state.initialized then
    init_level()
    return
  end

  local move_camera_speed = 1

  if btn(0) then
    level_state.camera.location.x -= move_camera_speed
    -- level_state.ricos[1].location.x -= move_camera_speed
  end

  if btn(1) then
    level_state.camera.location.x += move_camera_speed
    -- level_state.ricos[1].location.x += move_camera_speed
  end

  if btn(2) then
    level_state.camera.location.y -= move_camera_speed
    -- level_state.ricos[1].location.y -= move_camera_speed
  end

  if btn(3) then
    level_state.camera.location.y += move_camera_speed
    -- level_state.ricos[1].location.y += move_camera_speed
  end

  local window = level_state.camera:get_window()

  for i, rico in ipairs(level_state.ricos) do
    rico:update(window)
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
        spline = " 14,-166.72409057617188,-0.7519989013671875,-157.89453125,-0.725616455078125,-110.53113555908203,-0.828155517578125,-85.0422592163086,-0.7519989013671875,-85.0422592163086,-0.7519989013671875,-76.21269989013672,-0.725616455078125,-48.19500732421875,11.183868408203125,-42.68403625488281,26.55957794189453,-42.68403625488281,26.55957794189453,-39.70491027832031,34.87139129638672,-27.018783569335938,61.58518981933594,-18.024826049804688,75.21943664550781,-18.024826049804688,75.21943664550781,-15.631082534790039,78.84819412231445,-2.7071070671081543,78.0,-2.0,78.0,-2.0,78.0,-2.384185791015625e-07,78.0,72.05933380126953,77.66058731079102,73.0,78.0,73.0,78.0,84.69535827636719,82.21993637084961,85.0,94.0,93.0,98.0,93.0,98.0,93.8944320678711,98.44721603393555,96.35372161865234,100.69100952148438,105.0,98.0,105.0,98.0,114.99388885498047,94.88956832885742,116.94491577148438,94.07145690917969,126.0,94.0,126.0,94.0,139.993896484375,93.88956832885742,143.33071899414062,95.6159896850586,152.0,93.0,152.0,93.0,158.993896484375,90.88956451416016,157.97784423828125,90.2248764038086,167.0,91.0,167.0,91.0,188.993896484375,92.88956832885742,222.94473266601562,93.04546737670898,232.0,93.0,232.0,93.0,253.993896484375,92.88956832885742,271.2315979003906,69.4482650756836,287.0601501464844,57.60420227050781,287.0601501464844,57.60420227050781,304.66998291015625,44.42726135253906,335.00909423828125,2.512054443359375,354.13739013671875,-2.48126220703125,354.13739013671875,-2.48126220703125,382.01641845703125,-9.758895874023438,484.676513671875,-25.236495971679688,521.0657348632812,-22.801071166992188",
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
      asset.points = spline:sample(bezier_spline_sample_incr)
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
  if last_update_mode != game_mode then
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
