pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

test_state_not_started = 0
test_state_started = 1
test_state_passed = 2
test_state_failed = 3

registered_tests = {}

function new_test(description, func)
  return {
    description = description,
    func = func,
    state = test_state_not_started,
    errors = {},
    expect = function(self, value, message)
      if not value then
        self.state = test_state_failed
        self.errors[#self.errors + 1] = message
      end

      return value
    end,
    start = function(self)
      self.state = test_state_started
    end,
    end_test = function(self)
      if self.state == test_state_started then
        self.state = test_state_passed
      end
    end,
    run = function(self)
      self:start()
      self:func()
      self:end_test()
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

    if t.state ~= test_state_passed then
      all_passed = false
    end
  end
end

function print_test_report(p_func)
  if all_passed then
    color(11)
    p_func("passed!")
    return
  end

  color(8)
  p_func("failed!")

  for _, t in ipairs(registered_tests) do
    if t.state ~= test_state_passed then
      color(6)
      p_func(t.description)
      color(8)

      for _, error in ipairs(t.errors) do
        p_func("  " .. error)
      end
    end
  end
end
