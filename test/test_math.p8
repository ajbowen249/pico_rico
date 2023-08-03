pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

test("point: equals", function(t)
  local p1 = new_point(23, 85)
  local p2 = new_point(23, 85)

  t:expect_true(p1:equals(p2), "points should be equal")
  t:expect_true(p2:equals(p1), "points should be equal")
end)

test("point: not equal", function(t)
  local p1 = new_point(1, 2)
  local p2 = new_point(3, 4)

  t:expect_false(p1:equals(p2), "points should not be equal")
  t:expect_false(p2:equals(p1), "points should not be equal")
end)

test("point: add", function(t)
  local p1 = new_point(10, 10)
  local p2 = new_point(3, -5)

  local p3 = p1:add(p2)

  t:expect_eq(13, p3.x, "added xs")
  t:expect_eq(5, p3.y, "added ys")
end)

test("point: sub", function(t)
  local p1 = new_point(23, 85)
  local p2 = new_point(-2, 14)

  local p3 = p1:sub(p2)

  t:expect_eq(25, p3.x, "subtracted xs")
  t:expect_eq(71, p3.y, "subtracted ys")
end)

test("point: mul", function(t)
  local p1 = new_point(4, 9)
  local p2 = p1:mul(2)

  t:expect_eq(8, p2.x, "multiplied x by scaler")
  t:expect_eq(18, p2.y, "multiplied y by scaler")
end)
