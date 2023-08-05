pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

registered_tests = {}

function new_test(description, func, tag)
  return {
    description = description,
    func = func,
    results = {},
    skipped = false,
    skip_message = "",
    tag = tag,
    skip = function(self, message)
      self.skipped = true
      self.skip_message = message
    end,
    expect_eq = function(self, expected, actual, message, margin)
      local passed = expected == actual
      if margin != nil then
        passed = actual >= (expected - margin) and actual <= (expected + margin)
      end

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
    expect_true = function(self, value, message)
      local passed = value == true
      local final_message = message

      if not passed then
        final_message = message .. ": value false"
      end

      self.results[#self.results + 1] = {
        passed = passed,
        message = final_message,
      }

      return passed
    end,
    expect_false = function(self, value, message)
      local passed = value ~= true
      local final_message = message

      if not passed then
        final_message = message .. ": value was true"
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

function test(description, func, tag)
  registered_tests[#registered_tests + 1] = new_test(description, func, tag)
end

some_failed = false

function run_all_tests(test_list)
  for _, t in ipairs(registered_tests) do
    if test_list == nil or some(test_list, function(t_name)
      return t_name == t.tag
    end) then
      t:run()

      if not t.passed and not t.skipped then
        some_failed = true
      end
    end
  end
end

function print_test_report(p_func)
  color(some_failed and 8 or 11)
  p_func(some_failed and "failed!" or "passed!")

  local total_run = 0
  local total_passed = 0
  local total_failed = 0
  local total_skipped = 0

  for _, t in ipairs(registered_tests) do
    color(6)
    p_func(t.description)

    for _, result in ipairs(t.results) do
      total_run += 1

      if result.passed then
        total_passed += 1
      elseif not t.skipped then
        total_failed += 1
      end

      color(result.passed and 11 or 8)
      p_func("  " .. result.message)
    end

    if t.skipped then
      color(10)
      p_func("skipped: " .. t.skip_message)
      total_skipped += 1
    end
  end

  color(some_failed and 8 or 11)

  p_func("total run:  " .. total_run)
  p_func("total skip: " .. total_skipped)
  p_func("total pass: " .. total_passed)
  p_func("total fail: " .. total_failed)
end
