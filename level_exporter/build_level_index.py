import sys
import os
import argparse

PICO8_HEADER = '''pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate the level index file')
    parser.add_argument('level_files', type=str, nargs='+', help='the level files to index')
    parser.add_argument('-o', dest = 'out_path', type=str, help='where to save the output file')

    args = parser.parse_args()
    print(args)

    with open(args.out_path, "w") as out_file:
        out_file.write(PICO8_HEADER)
        out_file.write("\n\ngame_levels = {\n")
        for level_file_path in args.level_files:
            filename = os.path.basename(level_file_path)
            relative_path = "./levels/{filename}".format(filename = filename)
            out_file.write("  game_level_{name},\n".format(name = filename.replace('.p8', '')))

        out_file.write("}\n")
