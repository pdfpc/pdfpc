project("pdfpc" C)
cmake_minimum_required(VERSION 2.6)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Vala_CMake/vala)

find_package(Vala "0.26" REQUIRED)
include(${VALA_USE_FILE})

set(SYSCONFDIR "${CMAKE_INSTALL_PREFIX}/etc" CACHE FILEPATH "sysconfdir")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(src)
add_subdirectory(icons)
add_subdirectory(man)
add_subdirectory(rc)
