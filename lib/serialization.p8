pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

-->8
-- serlialization

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

  if #tokens ~= num_segments * 8 then
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
