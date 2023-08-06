pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

#include ../lib/constants.p8
#include ../lib/library.p8
#include ../lib/math.p8
#include ../lib/bezier.p8
#include ../lib/drawing.p8
#include ../lib/serialization.p8
#include ../lib/gameplay.p8
#include ../lib/main_menu.p8
#include ../lib/levels.p8

#include ./framework.p8

#include ./test_math.p8
#include ./test_math_intersection.p8

function print_line(msg)
  print(msg .. "\n")
end

local args = stat(6)
local test_list = nil
if args != nil and args != "" then
  test_list = split(args)
end

cls()
run_all_tests(test_list)
print_test_report(print_line)
print_test_report(printh)
