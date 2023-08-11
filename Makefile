BLENDER = blender.exe
PYTHON = python3
EXPORT_LEVEL = ./level_exporter/export.py
BUILD_LEVEL_INDEX = ./level_exporter/build_level_index.py
BUILD_DIR = ./build
ASSETS_DIR = ./assets
LEVELS_DIR = $(ASSETS_DIR)/levels

LEVELS_OUT_DIR = $(BUILD_DIR)/levels

LEVEL_BLENDER_FILES := $(wildcard $(LEVELS_DIR)/*.blend)
LEVEL_PICO8_FILES := $(patsubst $(LEVELS_DIR)/%, $(LEVELS_OUT_DIR)/%, $(LEVEL_BLENDER_FILES:.blend=.p8))

$(info LEVELS_OUT_DIR: ${LEVELS_OUT_DIR})
$(info LEVEL_BLENDER_FILES: ${LEVEL_BLENDER_FILES})
$(info LEVEL_PICO8_FILES: ${LEVEL_PICO8_FILES})

.PHONY: all

levels: $(LEVEL_PICO8_FILES)
all: $(LEVEL_PICO8_FILES)

$(LEVELS_OUT_DIR)/%.p8: $(LEVELS_DIR)/%.blend
	@mkdir -p $(LEVELS_OUT_DIR)
	$(info exporting blender file: $^)
# note: order here matters. If you put the filename after the --python argument, it runs the script before the file is loaded
	$(BLENDER) $^ --background --python $(EXPORT_LEVEL) -- ./$@

clean:
	@rm -rfv $(BUILD_DIR)
