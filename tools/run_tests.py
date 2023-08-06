#!/usr/bin/python3

import os

test_executable = os.path.relpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../test/unit_tests.p8"))

base_command = "pico8.exe -x ./{test_executable}".format(test_executable = test_executable)
print(base_command)

os.system(base_command)
