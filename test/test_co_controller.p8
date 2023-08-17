pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

test("co_controller: happy path", function(t)
  local controller = new_co_controller()
  local total = 0
  controller:add(function()
    total += 1
  end)

  controller:add(function()
    total += 1
    yield()
    total += 1
  end)

  controller:add(function()
    total += 1
    yield()
    total += 1
    yield()
    total += 1
  end)

  while #controller.coroutines > 0 do
    controller:process()
  end

  t:expect_eq(6, total, "expected total to reach 6")
end)
