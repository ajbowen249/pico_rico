pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-->8
-- drawing

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
