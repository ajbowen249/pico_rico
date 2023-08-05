pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

-- note: specific numbers in here are likely going to change slightly as algorithms are tweaked
-- whether or not an intersection is detected is the more important part, and the numbers just need to stay reasonable

test("intersect: two segments 1", function(t)
  local p1 = new_point(0, 0)
  local p2 = new_point(10, 10)

  local p3 = new_point(0, 10)
  local p4 = new_point(10, 0)

  local intersections = segment_segment_intersect(p1, p2, p3, p4)
  if not t:expect_eq(1, #intersections, "exactly one intersection") then
    return
  end

  local intersection = intersections[1]
  t:expect_eq(5, intersection.x, "x == 5")
  t:expect_eq(5, intersection.y, "y == 5")
end)

test("intersect: two segments 2", function(t)
  t:skip("works with infinite lines and in javascript, not yet with fixed point math and segments, though.")
  local p1 = new_point(2.5677, 72.9829);
  local p2 = new_point(52.876, 72.8492);

  local p3 = new_point(40, 69.9997);
  local p4 = new_point(40, 73.9997);

  local intersections = segment_segment_intersect(p1, p2, p3, p4)
  if not t:expect_eq(1, #intersections, "exactly one intersection") then
    return
  end

  local intersection = intersections[1]
  t:expect_eq(40, intersection.x, "x == 40")
  t:expect_eq(72.8834, intersection.y, "y == 72.8834", .01)
end)

test("intersect: two infinite lines", function(t)
  -- these are the same coordinates as the skipped segment test above
  local p1 = new_point(2.5677, 72.9829);
  local p2 = new_point(52.876, 72.8492);

  local p3 = new_point(40, 69.9997);
  local p4 = new_point(40, 73.9997);

  local intersections = line_line_intersect(p1, p2, p3, p4)
  if not t:expect_eq(1, #intersections, "exactly one intersection") then
    return
  end

  local intersection = intersections[1]
  t:expect_eq(40, intersection.x, "x == 40")
  t:expect_eq(72.8834, intersection.y, "y == 72.8834", .01)
end)

test("intersect: two segments 3", function(t)
  local p1 = new_point(912.3442, 500.6497)
  local p2 = new_point(915.0197, 503.6231)

  local p3 = new_point(896.7417, 492.9106)
  local p4 = new_point(920.830, 505.3188)

  local intersections = segment_segment_intersect(p1, p2, p3, p4)
  if not t:expect_eq(1, #intersections, "exactly one intersection") then
    return
  end

  local intersection = intersections[1]
  t:expect_eq(912.844, intersection.x, "x == 912.844", .01)
  t:expect_eq(501.205, intersection.y, "y == 501.205", .01)
end)

test("intersect: two infinite lines 2", function(t)
  -- fascinating...the segment-segment intersect algorithem works fine with these values, but this one was broken!
  -- x is coming back as -792.667
  -- confirmed working in javascript
  -- fixed by offsetting points relative to p1 before calculating the intersection, then offset back when returned
  local p1 = new_point(912.3442, 500.6497)
  local p2 = new_point(915.0197, 503.6231)

  local p3 = new_point(896.7417, 492.9106)
  local p4 = new_point(920.830, 505.3188)

  local intersections = line_line_intersect(p1, p2, p3, p4)
  if not t:expect_eq(1, #intersections, "exactly one intersection") then
    return
  end

  local intersection = intersections[1]
  t:expect_eq(912.844, intersection.x, "x == 912.844", .01)
  t:expect_eq(501.205, intersection.y, "y == 501.205", .01)
end, "bad_infinite_line")
