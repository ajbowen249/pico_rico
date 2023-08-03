pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

-->8
-- library functions

function set_game_mode(mode)
  game_mode = mode
end

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

function reduce(array, func, acc_init)
  local acc = acc_init
  for i, v in ipairs(array) do
    if func(v, i) then
      acc = func(acc, v)
    end
  end

  return acc
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

function min_in(array, getter)
  local smallest_value = nil
  local smallest_element

  for _, v in ipairs(array) do
    local value = getter ~= nil and getter(v) or v
    if smallest_value == nil or value < smallest_value then
      smallest_value = value
      smallest_element = v
    end
  end

  return smallest_element
end
