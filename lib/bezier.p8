pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

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
      local target_dist = 15
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
