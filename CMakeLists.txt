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

set(CPACK_VERBATIM_VARIABLES YES)
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packaged")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE.txt")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "PDF Presenter Console")
set(CPACK_PACKAGE_VENDOR "pdfpc")

# backslash is required for NSIS on Windows
set(CPACK_PACKAGE_ICON "${CMAKE_SOURCE_DIR}/icons\\pdfpc-presenter-small.bmp")
set(CPACK_CREATE_DESKTOP_LINKS pdfpc)
set(CPACK_PACKAGE_INSTALL_DIRECTORY pdfpc)

# Options specifically for the NSIS installer (Windows)
set(CPACK_NSIS_MUI_ICON "${CMAKE_SOURCE_DIR}/icons/pdfpc.ico")
set(CPACK_NSIS_MUI_UNIICON "${CMAKE_SOURCE_DIR}/icons/pdfpc.ico")
set(CPACK_NSIS_INSTALLED_ICON_NAME "$<TARGET_FILE:pdfpc>")
set(CPACK_NSIS_MODIFY_PATH On) # "Add pdfpc to PATH?"
set(CPACK_NSIS_CONTACT "https://github.com/pdfpc/pdfpc/issues")
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON) # ask about previously installed versions
set(CPACK_NSIS_DEFINES "RequestExecutionLevel user")

# File association
# See https://learn.microsoft.com/en-us/windows/win32/shell/fa-file-types
set (CPACK_NSIS_EXTRA_INSTALL_COMMANDS [[
    WriteRegStr SHCTX "Software\Classes\.pdf\OpenWithProgIds" "pdfpc.present" ""
    WriteRegStr SHCTX "Software\Classes\Applications\pdfpc.exe\SupportedTypes" ".pdf" ""

    WriteRegStr SHCTX "Software\Classes\pdfpc.present" "" "Present with pdfpc"
    WriteRegStr SHCTX "Software\Classes\pdfpc.present\DefaultIcon" "" '"$INSTDIR\bin\pdfpc.exe",0'
    WriteRegStr SHCTX "Software\Classes\pdfpc.present\shell" "" "open"
    WriteRegStr SHCTX "Software\Classes\pdfpc.present\shell\open\command" "" '"$INSTDIR\bin\pdfpc.exe" "%1"'
    System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
]])

set (CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS [[
    DeleteRegKey SHCTX "Software\Classes\pdfpc.present"
    System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
]])

add_subdirectory(src)
add_subdirectory(icons)
add_subdirectory(man)
add_subdirectory(css)
add_subdirectory(rc)

include(CPack)
