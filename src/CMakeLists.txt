find_package(PkgConfig)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)
pkg_check_modules(GEE REQUIRED gee-0.8)
pkg_check_modules(POPPLER REQUIRED poppler-glib>=0.80)
pkg_check_modules(GTK REQUIRED gtk+-3.0>=3.22)
pkg_check_modules(JSON REQUIRED json-glib-1.0)
list (FIND GTK_STATIC_LIBRARIES "X11" _index)
if (${_index} GREATER -1)
    set(WITH_X11 1)
    message(STATUS "GTK is compiled with X11 -- enabling X11 support")
    pkg_check_modules(X11 REQUIRED x11)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D X11)
    set(X11_PACKAGE x11)
endif ()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
pkg_check_modules(PANGOCAIRO REQUIRED pangocairo)
if (MOVIES)
    pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0)
    pkg_check_modules(GSTBASE REQUIRED gstreamer-base-1.0)
    pkg_check_modules(GSTAUDIO REQUIRED gstreamer-audio-1.0)
    pkg_check_modules(GSTVIDEO REQUIRED gstreamer-video-1.0)
    set(MOVIE_PACKAGES
        gstreamer-1.0
        gstreamer-base-1.0
        gstreamer-audio-1.0
        gstreamer-video-1.0
    )
endif ()

if (MDVIEW OR REST)
    pkg_check_modules(MARKDOWN REQUIRED libmarkdown)
endif ()

if ("${MARKDOWN_VERSION}" VERSION_GREATER_EQUAL 3)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D MARKDOWN3)
endif ()

if (MDVIEW)
    pkg_check_modules(WEBKIT REQUIRED webkit2gtk-4.1)
    set(MDVIEW_PACKAGES webkit2gtk-4.1)
endif ()

if (REST)
    pkg_check_modules(SOUP REQUIRED libsoup-3.0)
    pkg_check_modules(QRENCODE REQUIRED libqrencode)
    set(REST_PACKAGES
        libsoup-3.0
    )

    if (${CMAKE_HOST_WIN32})
        # Needed for Posix.gethostname()
        set(WSOCK32_LIB wsock32)
    endif ()
endif ()

include_directories(
    ${GOBJECT_INCLUDE_DIRS}
    ${GIO_INCLUDE_DIRS}
    ${GEE_INCLUDE_DIRS}
    ${POPPLER_INCLUDE_DIRS}
    ${GTK_INCLUDE_DIRS}
    ${GTHREAD_INCLUDE_DIRS}
    ${PANGOCAIRO_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
    ${GSTINTERFACES_INCLUDE_DIRS}
    ${GSTVIDEO_INCLUDE_DIRS}
    ${WEBKIT_INCLUDE_DIRS}
    ${MARKDOWN_INCLUDE_DIRS}
    ${JSON_INCLUDE_DIRS}
    ${SOUP_INCLUDE_DIRS}
    ${QRENCODE_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

set(_link_directories 
    ${GOBJECT_LIBRARY_DIRS}
    ${GIO_LIBRARY_DIRS}
    ${GEE_LIBRARY_DIRS}
    ${POPPLER_LIBRARY_DIRS}
    ${GTK_LIBRARY_DIRS}
    ${GTHREAD_LIBRARY_DIRS}
    ${PANGOCAIRO_LIBRARY_DIRS}
    ${GSTREAMER_LIBRARY_DIRS}
    ${GSTINTERFACES_LIBRARY_DIRS}
    ${GSTVIDEO_LIBRARY_DIRS}
    ${WEBKIT_LIBRARY_DIRS}
    ${MARKDOWN_LIBRARY_DIRS}
    ${JSON_LIBRARY_DIRS}
    ${SOUP_LIBRARY_DIRS}
    ${QRENCODE_LIBRARY_DIRS}
)

link_directories(${_link_directories})

if(${WITH_X11})
    include_directories(${X11_INCLUDE_DIRS})
    link_directories(${X11_LIBRARY_DIRS})
    set(ADDITIONAL_LIBS ${X11_LIBRARIES})
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/release.vala.in ${CMAKE_CURRENT_SOURCE_DIR}/release.vala)

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/paths.in ${CMAKE_CURRENT_BINARY_DIR}/paths.vala)

file (GLOB_RECURSE C_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.c)
file (GLOB_RECURSE VALA_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.vala)

if (MOVIES)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D MOVIES)
else ()
    LIST(REMOVE_ITEM VALA_SRC classes/action/movie.vala)
endif ()
if (REST)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D REST)
else ()
    LIST(REMOVE_ITEM VALA_SRC classes/rest_server.vala)
    LIST(REMOVE_ITEM VALA_SRC classes/window/qrcode.vala)
endif ()
if (MDVIEW)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D MDVIEW)
else ()
    LIST(REMOVE_ITEM VALA_SRC classes/view/markdown.vala)
endif ()
if (NOT MARKDOWN_FOUND)
    LIST(REMOVE_ITEM VALA_SRC classes/renderer/markdown.vala)
endif ()

# Check for some compiler flags to suppress excessive Vala-triggered warnings
# Since gcc >= 4.4 can silently ignore unrecognized -W-no* flags, we test
# for positive options instead.
include(CheckCCompilerFlag)
check_c_compiler_flag(-Wdiscarded-qualifiers CC_HAS_DISCARDED_QUALIFIERS)
if (CC_HAS_DISCARDED_QUALIFIERS)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-discarded-qualifiers")
endif()
check_c_compiler_flag(-Wincompatible-pointer-types CC_HAS_INCOMPATIBLE_POINTER_TYPES)
if (CC_HAS_INCOMPATIBLE_POINTER_TYPES)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-incompatible-pointer-types")
endif()
check_c_compiler_flag(-Wdeprecated-declarations CC_HAS_DEPRECATED_DECLARATIONS)
if (CC_HAS_DEPRECATED_DECLARATIONS)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-deprecated-declarations")
endif()
check_c_compiler_flag(-Wimplicit-function-declaration CC_HAS_IMPLICIT_FUNCTION_DECLARATION)
if (CC_HAS_IMPLICIT_FUNCTION_DECLARATION)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-implicit-function-declaration")
endif()

if(WIN32)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D WIN32)
endif()

vala_precompile(VALA_C
    ${VALA_SRC}
PACKAGES
    json-glib-1.0
    gio-2.0
    gee-0.8
    poppler-glib
    ${X11_PACKAGE}
    gtk+-3.0
    pangocairo
    posix
    ${MOVIE_PACKAGES}
    ${MDVIEW_PACKAGES}
    ${REST_PACKAGES}
OPTIONS
    --enable-experimental
    ${EXTRA_VALA_OPTIONS}
CUSTOM_VAPIS
    ${CMAKE_CURRENT_BINARY_DIR}/paths.vala
    ${CMAKE_CURRENT_SOURCE_DIR}/custom_binding.vapi
    ${CMAKE_CURRENT_SOURCE_DIR}/libmarkdown.vapi
    ${CMAKE_CURRENT_SOURCE_DIR}/libqrencode.vapi
)

add_executable(pdfpc
    ${VALA_C}
    ${C_SRC}
)

# explicitly add libraries (needed e.g. for Fedora 13+)
target_link_libraries(pdfpc
    m
    ${WSOCK32_LIB}
    ${GOBJECT_LIBRARIES}
    ${GIO_LIBRARIES}
    ${GEE_LIBRARIES}
    ${POPPLER_LIBRARIES}
    ${MARKDOWN_LIBRARIES}
    ${WEBKIT_LIBRARIES}
    ${JSON_LIBRARIES}
    ${SOUP_LIBRARIES}
    ${QRENCODE_LIBRARIES}
    ${GTK_LIBRARIES}
    ${GTHREAD_LIBRARIES}
    ${PANGOCAIRO_LIBRARIES}
    ${GSTREAMER_LIBRARIES}
    ${GSTINTERFACES_LIBRARIES}
    ${GSTVIDEO_LIBRARIES}
    ${ADDITIONAL_LIBS}
)

if(WIN32)
    # Resources
    if(NOT PROJECT_VERSION_TWEAK)
        # Windows supports {major}.{minor}.{patch}.{tweak}
        set(PROJECT_VERSION_TWEAK 0)
    endif()
    set(_windows_rc "${CMAKE_BINARY_DIR}/resources/windows.rc")
    set(_windows_ico "${CMAKE_BINARY_DIR}/resources/pdfpc.ico")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/../icons/windows.rc.in" "${_windows_rc}" @ONLY)
    target_sources(pdfpc PRIVATE "${_windows_rc}")

    find_program(magick_exe 
        NAMES magick magick.exe
        REQUIRED
    )
    add_custom_command(
        OUTPUT "${_windows_ico}"
        COMMAND "${magick_exe}" -background none "${CMAKE_SOURCE_DIR}/icons/pdfpc.svg" -geometry 64 "${_windows_ico}"
        DEPENDS "${CMAKE_SOURCE_DIR}/icons/pdfpc.svg"
    )
    set_property(SOURCE "${_windows_rc}" APPEND PROPERTY OBJECT_DEPENDS "${_windows_ico}")
endif()

if(MINGW)
    # Deployment of libraries for installation
    list(REMOVE_DUPLICATES _link_directories) # there should only be one directory here
    list(LENGTH _link_directories _len)
    if(_len EQUAL 1)
        # _link_directories is path/to/mingw64/lib
        cmake_path(SET _mingw_dir NORMALIZE "${_link_directories}/..")
    else()
        if(PDFPC_MINGW_ROOT_DIR)
            cmake_path(SET _mingw_dir NORMALIZE "${PDFPC_MINGW_ROOT_DIR}")
        else()
            message(FATAL_ERROR "The shared libraries come from different locations - set PDFPC_MINGW_ROOT_DIR")
        endif()
    endif()
    set(_mingw_bin "${_mingw_dir}/bin")
    set(_mingw_share "${_mingw_dir}/share")

    # install gdbus.exe and gspawn-win64-helper*.exe
    install(
        PROGRAMS
            "${_mingw_bin}/gdbus.exe"
            "${_mingw_bin}/gspawn-win64-helper.exe"
            "${_mingw_bin}/gspawn-win64-helper-console.exe"
        DESTINATION
            bin
    )

    # install mingw shared folders
    install(
        DIRECTORY
            "${_mingw_share}/icons"
            "${_mingw_share}/glib-2.0"
            "${_mingw_share}/poppler"
        DESTINATION
            share
    )
    
    # gdk-pixbuf
    # some loaders (such as the svg loader) have additional dependencies
    file(GLOB_RECURSE _additional_dlls "${_mingw_dir}/lib/gdk-pixbuf-2.0/**/*.dll")
    file(GLOB_RECURSE _gst_dlls "${_mingw_dir}/lib/gstreamer-1.0/*.dll")
    list(APPEND _additional_dlls ${_gst_dlls})
    set(_install_tmpl [[
        file(GET_RUNTIME_DEPENDENCIES
            RESOLVED_DEPENDENCIES_VAR _pixbuf_deps
            PRE_INCLUDE_REGEXES "^lib"
            PRE_EXCLUDE_REGEXES "api-ms-" "ext-ms-"
            POST_EXCLUDE_REGEXES ".*system32/.*\\.dll"
            DIRECTORIES "@_mingw_bin@"
            MODULES @_additional_dlls@
        )
        foreach(_dep IN LISTS _pixbuf_deps)
            file(INSTALL 
                DESTINATION "${CMAKE_INSTALL_PREFIX}/bin"
                TYPE SHARED_LIBRARY
                FILES ${_dep}
                FOLLOW_SYMLINK_CHAIN
            )
        endforeach()
    ]])
    string(CONFIGURE "${_install_tmpl}" _install_code @ONLY)
    install(CODE "${_install_code}")

    install(
        DIRECTORY
            "${_mingw_dir}/lib/gdk-pixbuf-2.0"
        DESTINATION
            lib
        PATTERN "*.a" EXCLUDE
    )
    install(
        DIRECTORY
            "${_mingw_dir}/lib/gstreamer-1.0"
        DESTINATION
            lib
    )

    # The actual executable
    install(TARGETS
            pdfpc
        RUNTIME_DEPENDENCIES
            PRE_INCLUDE_REGEXES "^lib"
            PRE_EXCLUDE_REGEXES "api-ms-" "ext-ms-" # System DLLs
            POST_EXCLUDE_REGEXES ".*system32/.*\\.dll"
            DIRECTORIES "${_mingw_bin}"
        RUNTIME
        DESTINATION
            bin
    )
else()
    install(TARGETS
            pdfpc
        RUNTIME
        DESTINATION
            bin
    )
endif()
