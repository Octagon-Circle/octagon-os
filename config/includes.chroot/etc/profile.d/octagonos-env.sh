#!/bin/bash
# OctagonOS Environment Configuration

# Enable Vulkan ICD auto-detection
export VK_ICD_FILENAMES=""

# Mesa shader cache
export MESA_SHADER_CACHE_MAX_SIZE=4G
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"

# GameMode integration
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

# Better font rendering
export FREETYPE_PROPERTIES="truetype:interpreter-version=40"
