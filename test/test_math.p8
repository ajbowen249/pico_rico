pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

test("point: add", function(t)
  local p1 = new_point(10, 10)
  local p2 = new_point(3, -5)

  local p3 = p1:add(p2)

  t:expect(p3.x == 13, "incorrect x: " .. p3.x)
  t:expect(p3.y == 5, "incorrect y: " .. p3.y)
end)
