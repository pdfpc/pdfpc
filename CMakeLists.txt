project("pdf-presenter-console" C)
cmake_minimum_required(VERSION 2.6)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Vala_CMake/vala)
include(ValaPrecompile)
include(ValaVersion)

find_package(Vala)

ensure_vala_version("0.11.0" MINIMUM)

add_subdirectory(src)
