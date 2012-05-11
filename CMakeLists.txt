project("pdfpc" C)
cmake_minimum_required(VERSION 2.6)

# Uncomment this section if you want to compile from vala sources

#list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Vala_CMake/vala)
#include(ValaPrecompile)
#include(ValaVersion)
#
#find_package(Vala)
#
#ensure_vala_version("0.16.0" MINIMUM)
#
#add_subdirectory(src)

# ...and comment the following line
add_subdirectory(c-src)

add_subdirectory(icons)
add_subdirectory(man)
