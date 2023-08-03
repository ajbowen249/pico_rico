pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

test("point: add", function(t)
  local p1 = new_point(10, 10)
  local p2 = new_point(3, -5)

  local p3 = p1:add(p2)

  t:expect_eq(13, p3.x, "added xs")
  t:expect_eq(5, p3.y, "added ys")
end)
