project("pdfpc" C)
cmake_minimum_required(VERSION 3.0)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

find_package(Vala "0.34" REQUIRED)
include(${VALA_USE_FILE})

include(GNUInstallDirs)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

option(MOVIES "Compile support for movie playback (requires gdk-x11)" ON)

add_subdirectory(src)
add_subdirectory(icons)
add_subdirectory(man)
add_subdirectory(rc)
