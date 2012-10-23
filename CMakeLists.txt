project("pdfpc" C)
cmake_minimum_required(VERSION 2.6)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Vala_CMake/vala)
include(ValaPrecompile)
include(ValaVersion)

find_package(Vala)

ensure_vala_version("0.16.0" MINIMUM)

set(SYSCONFDIR "${CMAKE_INSTALL_PREFIX}/etc" CACHE FILEPATH "sysconfdir")

add_subdirectory(src)
add_subdirectory(icons)
add_subdirectory(man)
add_subdirectory(rc)
