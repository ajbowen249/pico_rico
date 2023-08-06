#!/usr/bin/python3

import os
import sys

path = os.path

test_executable = path.relpath(path.join(path.dirname(path.abspath(__file__)), "../test/unit_tests.p8"))

base_command = "pico8.exe -x ./{test_executable}".format(test_executable = test_executable)
command = base_command

if len(sys.argv) > 1:
    command = "{base_command} -p {tag_list}".format(base_command = base_command, tag_list = " ".join(sys.argv[1:]))

os.system(command)
