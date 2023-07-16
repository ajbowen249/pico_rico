pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- constants
-- game mode
gm_menu = 1
gm_loading_level = 2
gm_level = 3

-- improve: fixed-length sampling!
bezier_spline_sample_incr = 0.1

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
    out[i] = func(v)
  end

  return out
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


-->8
-- math functions
function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
end

function points_equal(self, p2)
  return self.x == p2.x and self.y == p2.y
end

function new_point(x, y)
  return {
    x = x,
    y = y,
    equals = points_equal
  }
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

-->8
-- bezier functions

function get_bezier_point(self, index)
  if index == 1 then
    return self.p1
  elseif index == 2 then
    return self.p2
  elseif index == 3 then
    return self.p3
  else
    return self.p4
  end
end

function new_cubic_bezier(p1, p2, p3, p4)
  return {
    p1 = p1,
    p2 = p2,
    p3 = p3,
    p4 = p4,
    get_point = get_bezier_point,
  }
end

function sample_bezier_spline(self, incr)
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
end

function new_cubic_bezier_spline(...)
  return {
    curves = { ... },
    sample = sample_bezier_spline,
  }
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

function begin_level()
  game_mode = gm_level
end

function draw_level()
  cls()
  print("running level " .. game_levels[level_state.level].name, 0, 0, 11)
end

function update_level()
end

-->8
-- levels

-- asset types
at_underfill = 1

game_levels = {
  {
    name = "level 1",
    assets = {
      {
        name = "level_floor",
        type = at_underfill,
        spline = "7,-2.0,78.0,-2.384185791015625e-07,78.0,72.05933380126953,77.66058731079102,73.0,78.0,73.0,78.0,84.69535827636719,82.21993637084961,85.0,94.0,93.0,98.0,93.0,98.0,93.8944320678711,98.44721603393555,96.35372161865234,100.69100952148438,105.0,98.0,105.0,98.0,114.99388885498047,94.88956832885742,116.94491577148438,94.07145690917969,126.0,94.0,126.0,94.0,139.993896484375,93.88956832885742,143.33071899414062,95.6159896850586,152.0,93.0,152.0,93.0,158.993896484375,90.88956451416016,157.97784423828125,90.2248764038086,167.0,91.0,167.0,91.0,188.993896484375,92.88956832885742,222.94473266601562,93.04546737670898,232.0,93.0",
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
  }
end

function draw_loading_level()
  cls()
  local level = game_levels[loading_level_state.level]
  local asset_def = level.assets[loading_level_state.loading_asset]

  print("loading level " .. level.name, 0, 0, 8)
  print("asset: " .. asset_def.name, 0, 7, 8)
end

function update_loading_level()
  local level = game_levels[loading_level_state.level]
  if loading_level_state.loading_state == ls_init then
    loading_level_state.loading_state = ls_load
  elseif loading_level_state.loading_state == ls_load then
    local asset_def = level.assets[loading_level_state.loading_asset]
    local asset = {
      name = asset_def.name,
      type = asset_def.type,
    }

    if asset_def.type == at_underfill then
      asset.color = asset_def.color
      local spline = bez_spline_from_string(asset_def.spline)
      asset.points = spline:sample(bezier_spline_sample_incr)
    end

    level_state.assets[#level_state.assets] = asset

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
