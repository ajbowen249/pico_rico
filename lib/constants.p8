pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- constants
screen_size = 128

rico_size_min = 5
rico_size_max = 20

exclude_upper_y = { min_y = true } -- min_y because 0 is top

gravity = -.4
rico_max_speed = 4
max_rotation_angle = 30 / 360

-- game mode
gm_menu = 1
gm_loading_level = 2
gm_level = 3

-- improve: fixed-length sampling!
bezier_spline_sample_incr = .25

-- global state
game_mode = gm_menu

pi = 3.14159265

-- object types
-- terrain
ot_terrain_underfill = 1

-- pickups
ot_pickup_rico_bulb = 100

-- control objects
ot_level_spawn = 200
ot_level_end = 201

loading_level_state = nil

-- loading states
ls_init = 1
ls_load = 2
