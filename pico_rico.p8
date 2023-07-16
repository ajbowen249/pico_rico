pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- constants
-- game mode
gm_menu = 1
gm_loading_level = 2
gm_level = 3

-- global state
game_mode = gm_menu

function set_game_mode(mode)
  game_mode = mode
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

game_levels = {
  {
    name = "level 1"
  }
}


loading_level_state = nil

function load_level(level)
  game_mode = gm_loading_level
  loading_level_state = {
    level = level,
    countdown = 50
  }

  level_state = {
    level = level,
  }
end

function draw_loading_level()
  cls()
  print("loading level " .. game_levels[loading_level_state.level].name, 0, 0, 8)
end

function update_loading_level()
  loading_level_state.countdown = loading_level_state.countdown - 1
  if loading_level_state.countdown <= 0 then
    begin_level()
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
