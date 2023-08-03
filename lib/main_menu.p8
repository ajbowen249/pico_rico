pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

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
