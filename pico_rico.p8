pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- constants
screen_size = 128

rico_size_min = 5
rico_size_max = 20

exclude_upper_y = { min_y = true } -- min_y because 0 is top

gravity = -.2
rico_max_speed = 3

-- game mode
gm_menu = 1
gm_loading_level = 2
gm_level = 3

-- improve: fixed-length sampling!
bezier_spline_sample_incr = .25

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
    out[i] = func(v, i)
  end

  return out
end

function filter(array, func)
  local filtered = {}
  for i, v in ipairs(array) do
    if func(v, i) then
      filtered[#filtered + 1] = v
    end
  end

  return filtered
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

function new_point(x, y)
  return {
    x = x,
    y = y,
    equals = function(self, p2)
      return self.x == p2.x and self.y == p2.y
    end,
    add = function(self, p2)
      return new_point(self.x + p2.x, self.y + p2.y)
    end,
    sub = function(self, p2)
      return new_point(self.x - p2.x, self.y - p2.y)
    end,
    is_in_window = function(self, window, exclude)
      return ((exclude != nil and exclude.min_x == true) or self.x >= window.min_x) and
             ((exclude != nil and exclude.max_x == true) or self.x <= window.max_x) and
             ((exclude != nil and exclude.min_y == true) or self.y >= window.min_y) and
             ((exclude != nil and exclude.max_y == true) or self.y <= window.max_y)
    end,
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

function get_point_distance(a, b)
  local ab = b:sub(a)
  return sqrt((ab.x * ab.x) + (ab.y * ab.y))
end

-- improve: this is way slower than it needs to be...
-- tried to pull one off of rosettacode and it was very cryptic with issues. would break even when ricos were moving less than one size per frame
-- the fact that we already rasterize the line at draw time could come in handy here, though...
-- ... but, then, tying physics to drawing routines sounds bad
function line_circle_intersect(p1, p2, center, radius)
    local rise = p2.y - p1.y
    local run = p2.x - p1.x
    local slope = rise / run

    local intersecting_points = {}

    local drawing_point = new_point(p1.x, p1.y)
    while drawing_point.x <= p2.x do
      local distance = get_point_distance(center, drawing_point)
      if distance <= radius then
        intersecting_points[#intersecting_points + 1] = new_point(drawing_point.x, drawing_point.y)
      end
      drawing_point.x += 1
      drawing_point.y += slope
    end

    if #intersecting_points <= 2 then
      return intersecting_points
    else
      return {
        intersecting_points[1],
        intersecting_points[#intersecting_points],
      }
    end
end

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
  }
end

-->8
-- general drawing functions

function draw_underfill(points, to_y, col)
  for i, p in ipairs(points) do
    if i < #points then
      local next = points[i + 1]

      -- this may lead to back-draw, but that's fine. this is what it is and the curves need to deal
      -- some playing around suggests having a color generator could even make that a feature...
      local rise = next.y - p.y
      local run = next.x - p.x
      local slope = rise / run

      local drawing_point = new_point(p.x, p.y)
      while drawing_point.x <= next.x do
        rect(drawing_point.x, drawing_point.y, drawing_point.x, to_y, col)
        drawing_point.x += 1
        drawing_point.y += slope
      end
    end
  end
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

function new_camera()
  return {
    location = new_point(0, 0),
    get_window = function(self)
      return new_window(
        self.location.x,
        self.location.y,
        self.location.x + (screen_size - 1),
        self.location.y + (screen_size - 1)
      )
    end,
  }
end

function get_colliding_segments(location, size, window)
  local level = game_levels[level_state.level]
  local intersections = {}

  for asset_i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[asset_i]
    if asset_def.type == at_underfill then
      local points = get_points_in_window(asset.points, window)

      for point_i, point in ipairs(points) do
        if point_i < #points then
          local next = points[point_i + 1]
          local intersecting_points = line_circle_intersect(point, next, location, size)
          if #intersecting_points > 0 then
            intersections[#intersections + 1] = {
              points = intersecting_points
            }
          end
        end
      end
    end
  end

  return intersections
end

function new_rico(size, location, color)
  return {
    size = size,
    location = location,
    velocity = new_point(0, 0),
    color = color,
    update = function(self, window)
      local next_velocity = new_point(self.velocity.x, self.velocity.y)

      local next_point = new_point(
        self.location.x + next_velocity.x,
        self.location.y + next_velocity.y
      )

      local colliding_segments = get_colliding_segments(next_point, self.size, window)
      if #colliding_segments > 0 then
        next_point = self.location
        next_velocity.y = 0
      else
        next_velocity.y -= gravity
      end

      local next_speed = sqrt((next_velocity.x * next_velocity.x) + (next_velocity.y * next_velocity.y))
      if next_speed > rico_max_speed then
        next_velocity = new_point(
          (next_velocity.x / next_speed) * rico_max_speed,
          (next_velocity.y / next_speed) * rico_max_speed
        )
      end

      self.location = next_point
      self.velocity = next_velocity
    end,
    draw = function(self, window)
      if not self.location:is_in_window(window) then
        return
      end

      circfill(
        self.location.x -
          level_state.camera.location.x,
        self.location.y - level_state.camera.location.y,
        self.size,
        self.color
      )
    end,
  }
end

function init_level()
  level_state.camera = new_camera()
  level_state.initialized = true
  level_state.ricos = {
    new_rico(5, new_point(64, 30), 9),
  }
end

function begin_level()
  game_mode = gm_level
end

function draw_level()
  local level = game_levels[level_state.level]
  cls(level.background_color)

  if not level_state.initialized then
    return
  end

  local window = level_state.camera:get_window()

  for i, asset in ipairs(level_state.assets) do
    local asset_def = level.assets[i]
    if asset_def.type == at_underfill then
      local points = map(get_points_in_window(asset.points, window, exclude_upper_y), function(point)
        return new_point(
          point.x - level_state.camera.location.x,
          point.y - level_state.camera.location.y
        )
      end)

      draw_underfill(points, screen_size - 1, asset_def.color)
    end
  end

  for i, rico in ipairs(level_state.ricos) do
    rico:draw(window)
  end
end

function update_level()
  if not level_state.initialized then
    init_level()
    return
  end

  local move_camera_speed = 1

  if btn(0) then
    level_state.camera.location.x -= move_camera_speed
  end

  if btn(1) then
    level_state.camera.location.x += move_camera_speed
  end

  if btn(2) then
    level_state.camera.location.y -= move_camera_speed
  end

  if btn(3) then
    level_state.camera.location.y += move_camera_speed
  end

  local window = level_state.camera:get_window()

  for i, rico in ipairs(level_state.ricos) do
    rico:update(window)
  end
end

-->8
-- levels

-- asset types
at_underfill = 1

game_levels = {
  {
    name = "level 1",
    background_color = 12,
    assets = {
      {
        name = "level_floor",
        type = at_underfill,
        spline = " 14,-166.72409057617188,-0.7519989013671875,-157.89453125,-0.725616455078125,-110.53113555908203,-0.828155517578125,-85.0422592163086,-0.7519989013671875,-85.0422592163086,-0.7519989013671875,-76.21269989013672,-0.725616455078125,-48.19500732421875,11.183868408203125,-42.68403625488281,26.55957794189453,-42.68403625488281,26.55957794189453,-39.70491027832031,34.87139129638672,-27.018783569335938,61.58518981933594,-18.024826049804688,75.21943664550781,-18.024826049804688,75.21943664550781,-15.631082534790039,78.84819412231445,-2.7071070671081543,78.0,-2.0,78.0,-2.0,78.0,-2.384185791015625e-07,78.0,72.05933380126953,77.66058731079102,73.0,78.0,73.0,78.0,84.69535827636719,82.21993637084961,85.0,94.0,93.0,98.0,93.0,98.0,93.8944320678711,98.44721603393555,96.35372161865234,100.69100952148438,105.0,98.0,105.0,98.0,114.99388885498047,94.88956832885742,116.94491577148438,94.07145690917969,126.0,94.0,126.0,94.0,139.993896484375,93.88956832885742,143.33071899414062,95.6159896850586,152.0,93.0,152.0,93.0,158.993896484375,90.88956451416016,157.97784423828125,90.2248764038086,167.0,91.0,167.0,91.0,188.993896484375,92.88956832885742,222.94473266601562,93.04546737670898,232.0,93.0,232.0,93.0,253.993896484375,92.88956832885742,271.2315979003906,69.4482650756836,287.0601501464844,57.60420227050781,287.0601501464844,57.60420227050781,304.66998291015625,44.42726135253906,335.00909423828125,2.512054443359375,354.13739013671875,-2.48126220703125,354.13739013671875,-2.48126220703125,382.01641845703125,-9.758895874023438,484.676513671875,-25.236495971679688,521.0657348632812,-22.801071166992188",
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
    initialized = false,
  }
end

function draw_loading_level()
  cls()
  local level = game_levels[loading_level_state.level]
  local asset_def = level.assets[loading_level_state.loading_asset]

  print("loading level " .. level.name, 0, 0, 6)
  print("asset: " .. asset_def.name, 0, 7, 6)
end

function update_loading_level()
  local level = game_levels[loading_level_state.level]
  if loading_level_state.loading_state == ls_init then
    loading_level_state.loading_state = ls_load
  elseif loading_level_state.loading_state == ls_load then
    local asset_def = level.assets[loading_level_state.loading_asset]
    local asset = { }

    if asset_def.type == at_underfill then
      asset.color = asset_def.color
      local spline = bez_spline_from_string(asset_def.spline)
      asset.points = spline:sample(bezier_spline_sample_incr)
    end

    level_state.assets[#level_state.assets + 1] = asset

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
