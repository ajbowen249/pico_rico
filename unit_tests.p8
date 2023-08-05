pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

#include ./lib/constants.p8
#include ./lib/library.p8
#include ./lib/math.p8
#include ./lib/bezier.p8
#include ./lib/drawing.p8
#include ./lib/serialization.p8
#include ./lib/gameplay.p8
#include ./lib/main_menu.p8
#include ./lib/levels.p8

#include ./test/framework.p8

#include ./test/test_math.p8
#include ./test/test_math_intersection.p8

function print_line(msg)
  print(msg .. "\n")
end

cls()
run_all_tests()
print_test_report(print_line)
print_test_report(printh)
