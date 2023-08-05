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
  t:expect_eq(72.8834, intersection.y, "y == 72.8834", .5)
end)
