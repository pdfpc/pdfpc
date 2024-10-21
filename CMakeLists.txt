cmake_minimum_required(VERSION 3.7)
project("pdfpc" C)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

find_package(Vala "0.48" REQUIRED)
include(${VALA_USE_FILE})

include(GNUInstallDirs)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

option(MOVIES "Compile support for movie playback (requires gstreamer)" ON)
option(MDVIEW "Enable viewing Markdown notes (requires webkit2gtk)" ON)
option(REST "Compile support for REST server (requires libsoup and libqrencode)" ON)

add_subdirectory(src)
add_subdirectory(icons)
add_subdirectory(man)
add_subdirectory(css)
add_subdirectory(rc)
