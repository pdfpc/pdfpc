project("pdf-presenter-console" C)
cmake_minimum_required(VERSION 2.6)

enable_testing()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/conf)

find_package(Vala)

message(STATUS "Checking for Vala version 0.7.8 or greater")
if(${VALA_VERSION} VERSION_LESS "0.7.8")
	message(FATAL_ERROR "Vala version 0.7.8 or greater is required.")
endif(${VALA_VERSION} VERSION_LESS "0.7.8")

add_subdirectory(src)
add_subdirectory(tests)
