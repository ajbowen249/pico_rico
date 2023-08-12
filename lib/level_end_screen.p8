pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

level_end_state = {}

function init_level_end_state(end_zone)
  level_end_state.end_zone = end_zone
  level_end_state.total_ricos = get_total_ricos()
  level_end_state.flag_exit = false
  level_end_state.ticks_since_flag = 0

  level_state.camera.location.x = 0
  level_state.camera.location.y = 0
end

function update_level_end_screen()
  if btnp(4) or btnp(5) then
    level_end_state.flag_exit = true
  end

  if level_end_state.flag_exit then
    level_end_state.ticks_since_flag += 1
  end

  if level_end_state.ticks_since_flag >= 15 then
    game_mode = gm_menu
  end
end

function draw_level_end_screen()
  local level = game_levels[level_state.level]
  cls(level.background_color)

  print("success!", 0, 0, 3)

  local fake_rico = new_rico(level_end_state.total_ricos, new_point(0, 0), 9)
  fake_rico.location.x = fake_rico.radius + 5
  fake_rico.location.y = fake_rico.radius + 25

  local window = new_window(0, 0, 128, 128)

  fake_rico:draw(window)

  local total_location = fake_rico.location:add(new_point(fake_rico.radius + 10, -4))
  print("" .. level_end_state.total_ricos, total_location.x, total_location.y, 11)

  print("press 🅾️/❎ to continue...", 0, 120, level_end_state.flag_exit and 6 or 3)
end
