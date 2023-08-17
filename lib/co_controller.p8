pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-- helper to extract coroutine boilerplate
-- have yet to decide whether this should be a singleton...
function new_co_controller()
  return {
    coroutines = {},
    add = function(self, func)
      self.coroutines[#self.coroutines + 1] = cocreate(func)
    end,
    process = function(self)
      for i, coroutine in ipairs(self.coroutines) do
        if costatus(coroutine) != 'dead' then
          coresume(coroutine)
        end

        if costatus(coroutine) == 'dead' then
          del(self.coroutines, coroutine)
        end
      end
    end,
  }
end
