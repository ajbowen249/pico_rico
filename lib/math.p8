pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

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
    to_string = function(self)
      return "(" .. self.x .. ", " .. self.y .. ")"
    end,
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
function line_line_intersect(_p1, _p2, _p3, _p4)
  -- we run out of cardinality and overflow from all this multiplication before point values even hit the thousands.
  -- offset everything relative to p1 to retain some space and shift back later

  local p1 = new_point(0, 0)
  local p2 = _p2:sub(_p1)
  local p3 = _p3:sub(_p1)
  local p4 = _p4:sub(_p1)

  local denominator = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  if denominator == 0 then
    return {}
  end

  local common_1 = (p1.x * p2.y) - (p1.y * p2.x)
  local common_2 = (p3.x * p4.y) - (p3.y * p4.x)

  return {
    new_point(
      ((common_1 * (p3.x - p4.x)) - ((p1.x - p2.x) * common_2)) / denominator,
      ((common_1 * (p3.y - p4.y)) - ((p1.y - p2.y) * common_2)) / denominator
    ):add(_p1)
  }
end

function segment_segment_intersect_(p1, p2, p3, p4)
  local infinite_hit = line_line_intersect(p1, p2, p3, p4)[1]
  if infinite_hit == nil then
    return {}
  end

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

  if infinite_hit:is_in_window(segment_1_window) and infinite_hit:is_in_window(segment_2_window) then
    return { infinite_hit }
  else
    return {}
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

  -- just a thought: cramming t and u into 0-1 is probably where this breaks down in fixed-point mode. that's probably why prescaling the values didn't work
  -- where we really lost cardinality is in the division...

  local tgtz = (tn > 0 and td > 0) or (tn < 0 and td < 0)
  local ugtz = (un > 0 and ud > 0) or (un < 0 and ud < 0)

  local tlto = abs(tn) < abs(td)
  local ulto = abs(un) < abs(ud)

  if tgtz and tlto then
    p = new_point(
      p1.x + ((tn * (p2.x - p1.x)) / td),
      p1.y + ((tn * (p2.y - p1.y)) / td)
    )
  elseif ugtz and ulto then
    p = new_point(
      p3.x + ((un * (p4.x - p3.x)) / ud),
      p3.y + ((un * (p4.y - p3.y)) / ud)
    )
  end

  -- if t >= 0 and t <= 1 then
  --   p = new_point(
  --     p1.x + (t * (p2.x - p1.x)),
  --     p1.y + (t * (p2.y - p1.y))
  --   )
  -- elseif u >= 0 and u <= 1 then
  --   p = new_point(
  --     p3.x + (u * (p4.x - p3.x)),
  --     p3.y + (u * (p4.y - p3.y))
  --   )
  -- end

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

  printh(seg_p1:to_string() .. " -- " .. seg_p2:to_string())
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
