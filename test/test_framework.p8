pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

registered_tests = {}

function new_test(description, func)
  return {
    description = description,
    func = func,
    results = {},
    expect_eq = function(self, expected, actual, message)
      local passed = expected == actual
      local final_message = message

      if not passed then
        final_message = message .. ": expected " .. expected .. ", got " .. actual
      end

      self.results[#self.results + 1] = {
        passed = passed,
        message = final_message,
      }

      return passed
    end,
    run = function(self)
      self:func()
      self.passed = reduce(self.results, function(acc, res)
        if not res.passed then
          acc = false
        end

        return acc
      end, true)
    end
  }
end

function test(description, func)
  registered_tests[#registered_tests + 1] = new_test(description, func)
end

all_passed = true

function run_all_tests()
  for _, t in ipairs(registered_tests) do
    t:run()

    if not t.passed then
      all_passed = false
    end
  end
end

function print_test_report(p_func)
  color(all_passed and 11 or 8)
  p_func(all_passed and "passed!" or "failed!")

  for _, t in ipairs(registered_tests) do
    color(6)
    p_func(t.description)
    color(8)

    for _, result in ipairs(t.results) do
      color(result.passed and 11 or 8)
      p_func("  " .. result.message)
    end
  end
end
