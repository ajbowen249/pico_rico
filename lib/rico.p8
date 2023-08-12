pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

local rico_mass_to_area = pi * (2.5 * 2.5)
function calculate_rico_radius(mass)
  local area = mass * rico_mass_to_area
  return sqrt(area / pi)
end

function new_rico(mass, location, color)
  return {
    mass = mass,
    radius = calculate_rico_radius(mass),
    location = location,
    velocity = new_point(0, 0),
    color = color,
    contact = nil,
    rotation = 0,
    set_mass = function(self, new_mass)
      self.mass = new_mass
      self.radius = calculate_rico_radius(new_mass)
    end,
    update = function(self, window)
      local previous_contact = self.contact
      local next_velocity = new_point(self.velocity.x, self.velocity.y - gravity)
      local next_speed = next_velocity:len()
      if next_speed > rico_max_speed then
        next_velocity = next_velocity:normal():mul(rico_max_speed)
      end

      -- start out assuming we will be able to happily translate forward. this collider is everything we could be in the next frame
      local collider = make_moving_circle_collider(self.location, self.radius, next_velocity)
      local colliding_segments = {}
      for _, seg in ipairs(get_segments_colliding_with_circle(collider.circle1.center, self.radius, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_circle(collider.circle2.center, self.radius, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_segment(collider.seg1.p1, collider.seg1.p2, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      for _, seg in ipairs(get_segments_colliding_with_segment(collider.seg2.p1, collider.seg2.p2, window)) do
        colliding_segments[#colliding_segments + 1] = seg
      end

      -- for _, seg in ipairs(get_segments_colliding_with_moving_circle(collider.circle1.center, collider.circle2.center, self.radius, window)) do
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
            distance = get_point_distance(self.location, point) - self.radius,
          }
        end), get_dist)
      end), get_dist)

      -- local next_point = closest_hit.point
      local next_point = moving_circle_segment_intersect(collider.circle1.center, collider.circle2.center, self.radius, closest_hit.segment.p1, closest_hit.segment.p2)[1]

      if next_point == nil then
        cls()
        print("(" .. self.location.x .. ", " .. self.location.y .. ")\n")
        print("(" .. collider.circle2.center.x .. ", " .. collider.circle2.center.y .. ")\n")
        print("(" .. closest_hit.segment.p1.x .. ", " .. closest_hit.segment.p1.y .. ")\n")
        print("(" .. closest_hit.segment.p2.x .. ", " .. closest_hit.segment.p2.y .. ")\n")
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

      next_point = next_point:add(deflection)

      if previous_contact ~= nil and closest_hit ~= nil then
        local direction = next_point:sub(self.location)
        local distance = direction:len()
        direction = direction:normal()

        local perimeter = self.radius * 2 * pi
        -- angles in pico-8 are 0-1, so ratio of perimiter traveled is change in angle
        local angle_delta = distance / perimeter

        local plane_dir = closest_hit.segment.p2:sub(closest_hit.segment.p1):normal()
        local dot = plane_dir:dot(direction)

        if dot >= 0 then
          angle_delta *= -1
        end

        self.rotation += angle_delta
      end

      self.location = next_point
      self.contact = closest_hit
    end,
    draw = function(self, window)
      if not self.location:is_in_window(window) then
        return
      end

      local offset_location = self.location:sub(level_state.camera.location)

      -- draw body
      circfill(offset_location.x, offset_location.y, self.radius, self.color)

      local rotation_normal = new_point(1, 0):rotate(self.rotation)
      local rotation_line = rotation_normal:mul(self.radius):add(offset_location)

      -- debug line
      if true or debug_hud then
        line(offset_location.x, offset_location.y, rotation_line.x, rotation_line.y, 11)
      end
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
