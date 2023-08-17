# Pico Rico

![demo](gh_media/gifs/game_demo_1.gif)

_Pico Rico_ is a [`PICO-8`](https://www.lexaloffle.com/pico-8.php) game that takes heavy inspiration from a certain PSP classic.

It's an "inspired by" rather than a, "demake," for a handful of reasons:

- That would get tedious
- I don't want to commit to remaking any specific level, mechanic, song, etc.
- Not planning on selling it, but nobody wants a cease-and-desist 🤷

## Building

Unlike a typical `PICO-8` cartridge, Pico Rico's levels are built using [Blender](https://www.blender.org/). Attempting to run the cart file without building first will lead to an error.

The following executables are assumed to be in your PATH:

- `make` (GNU Make 4.2.1)
- `blender.exe` (3.4.1)
- `python3` (3.8.2)

Running `make` will export each `.blend` file under `assets/levels` to a `.p8` file under `build/levels`. The set of levels shipped in the final cartridge is declared in `lib/level_index.p8`.

## Unit Tests

The unit tests can currently be run via the script at `tools\run_tests.py` (`make test` coming _Soon™_).

Tests are defined under the `test` folder. The `unit_tests.p8` cart is the "main" file that imports and executes the tests. `framework.p8` contains the test library itself, and `test_*.p8` files are tests.

Test files are regular `PICO-8` cartridges that assume `framework.p8` was included. To add a test, call the `test` function with a name and a callback function to declare the test body. The callback is passed a `t` parameter that allows typicl unit-test expectations. For example:

```lua
test("point: equals", function(t)
  local p1 = new_point(23, 85)
  local p2 = new_point(23, 85)

  t:expect_true(p1:equals(p2), "points should be equal")
end)
```
