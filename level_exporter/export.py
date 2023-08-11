import bpy
import json
import re
import sys
import os
from enum import Enum

PICO8_HEADER = '''pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

'''

# Handy-dandy Blender-specific debug line. Paste this to pause with an interactive shell.
# It's not a function because you want it to pause in the scope of whatever you're debugging.
# __import__('code').interact(local=dict(globals(), **locals()))

ot_terrain_underfill = 1

class ObjectTypes(Enum):
    level_props = -1
    terrain_underfill = 1
    rico_bulb = 100

class Props(Enum):
    object_type = "prp_object_type"
    color = "prp_color"
    title = "prp_title"
    background_color = "prp_background_color"

def get_args():
    argv = sys.argv
    return argv[argv.index("--") + 1:]

def convert_y(y):
    return 128 - y

def json_line_to_lua_line(line):
    decl_res = re.search(r'( +)"(.*?)" = (.*)', line)
    if decl_res:
        groups = decl_res.groups()
        val = groups[2]
        if val == "[":
            val = "{"

        return "{indent}{key} = {val}".format(indent = groups[0], key = groups[1], val = val)

    end_list_res = re.search(r'( +)\]', line)
    if end_list_res:
        groups = end_list_res.groups()
        return "{indent}}}".format(indent = groups[0])
    return line

def obj_to_lua(obj):
    json_value = json.dumps(obj, indent = 2, separators = (',', ' = '))
    lines = json_value.split('\n')
    return "\n".join(map(json_line_to_lua_line, lines))

class Underfill:
    def __init__(self, obj):
        if obj.type != "CURVE":
            raise "Expected underfill object to be CURVE"

        self.name = obj.name
        self.color = obj[Props.color.value]

        if len(obj.data.splines) != 1:
            raise "Expected 1 spline in underfill curve"

        spline = obj.data.splines[0]

        out_values = []
        points = spline.bezier_points
        num_points = len(points)
        if num_points < 2:
            raise 'Curve not long enough!'

        # number of segments
        out_values.append(num_points - 1)
        # -1 because we're doing segment point pairs
        for point_index in range(0, num_points - 1):
            start = points[point_index]

            out_values.append(start.co.x)
            out_values.append(convert_y(start.co.y))
            out_values.append(start.handle_right.x)
            out_values.append(convert_y(start.handle_right.y))

            end = points[point_index + 1]
            out_values.append(end.handle_left.x)
            out_values.append(convert_y(end.handle_left.y))
            out_values.append(end.co.x)
            out_values.append(convert_y(end.co.y))

        self.out_values = out_values

    def to_pico8_value(self):
        return {
            "name": self.name,
            "type": ObjectTypes.terrain_underfill.value,
            "color": self.color,
            "spline": ",".join(["{:.4f}".format(val) for val in self.out_values])
        }

class RicoBulb:
    def __init__(self, obj):
        self.name = obj.name
        self.location = {
            "x": obj.location[0],
            "y": convert_y(obj.location[1]),
        }

    def to_pico8_value(self):
        return {
            "name": self.name,
            "type": ObjectTypes.rico_bulb.value,
            "location": self.location,
        }

class PicoRicoLevel:
    def __init__(self, name):
        self.name = name
        self.objects = []

    def add_object(self, object):
        self.objects.append(object)

    def consume_props_object(self, obj):
        self.title = obj[Props.title.value]
        self.background_color = obj[Props.background_color.value]

    def to_dict(self):
        return {
            "name": self.name,
            "title": self.title,
            "background_color": self.background_color,
            "objects": [ obj.to_pico8_value() for obj in self.objects]
        }

def build_level(name):
    level = PicoRicoLevel(name)
    bpy.ops.object.mode_set(mode='OBJECT')

    for obj in bpy.context.scene.objects:
        if not Props.object_type.value in obj or obj.name.startswith("dummy_"):
            continue

        object_type = obj[Props.object_type.value]

        if object_type == ObjectTypes.terrain_underfill.name:
            level.add_object(Underfill(obj))
        elif object_type == ObjectTypes.level_props.name:
            level.consume_props_object(obj)
        elif object_type == ObjectTypes.rico_bulb.name:
            level.add_object(RicoBulb(obj))

    return level

if __name__ == '__main__':
    out_filename = get_args()[0]
    level_rawname = os.path.basename(out_filename).replace('.p8', '')

    level = build_level(level_rawname)
    res = obj_to_lua(level.to_dict())

    with open(out_filename, "w") as out_file:
        out_file.write(PICO8_HEADER)
        out_file.write("local game_level_{name} = ".format(name = level_rawname))
        out_file.write(res)
        out_file.write("\n")
