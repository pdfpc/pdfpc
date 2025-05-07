cmake_minimum_required(VERSION 3.7...3.20)

file(STRINGS src/pdfpc.version PDFPC_RELEASE_DATA)
list(GET PDFPC_RELEASE_DATA 0 PDFPC_VERSION_STRING)
list(GET PDFPC_RELEASE_DATA 1 PDFPC_VERSION_YEAR)
string(REGEX MATCH "^v(.+)$" _version "${PDFPC_VERSION_STRING}")

project("pdfpc" 
    VERSION ${CMAKE_MATCH_1}
    LANGUAGES C
    HOMEPAGE_URL "https://pdfpc.github.io"
)

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
