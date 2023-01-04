find_package(PkgConfig)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)
pkg_check_modules(GEE REQUIRED gee-0.8)
pkg_check_modules(POPPLER REQUIRED poppler-glib>=0.22)
pkg_check_modules(GTK REQUIRED gtk+-3.0>=3.22)
pkg_check_modules(MARKDOWN REQUIRED libmarkdown)
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

if (MDVIEW)
    pkg_check_modules(WEBKIT REQUIRED webkit2gtk-4.0)
    set(MDVIEW_PACKAGES webkit2gtk-4.0)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D MDVIEW)
endif ()

if (REST)
    pkg_check_modules(SOUP REQUIRED libsoup-2.4)
    pkg_check_modules(QRENCODE REQUIRED libqrencode)
    set(REST_PACKAGES
        libsoup-2.4
    )

    if (${CMAKE_HOST_WIN32})
        # Needed for Posix.gethostname()
        set(WSOCK32_LIB wsock32)
    endif ()
endif ()

if ("${POPPLER_VERSION}" VERSION_GREATER_EQUAL 0.80 AND "${VALA_VERSION}" VERSION_GREATER 0.48.0)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D NEW_POPPLER)
endif()

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

link_directories(
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

if(${WITH_X11})
    include_directories(${X11_INCLUDE_DIRS})
    link_directories(${X11_LIBRARY_DIRS})
    set(ADDITIONAL_LIBS ${X11_LIBRARIES})
endif()

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/paths.in ${CMAKE_CURRENT_BINARY_DIR}/paths.vala)

file (GLOB_RECURSE C_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.c)
file (GLOB_RECURSE VALA_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.vala)
list(REMOVE_ITEM VALA_SRC paths.vala)
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

# Check for some compiler flags to suppress excessive Vala-triggered warnings
# Since gcc >= 4.4 can silently ignore unrecognized -W-no* flags, we test
# for positive options instead.
include(CheckCCompilerFlag)
check_c_compiler_flag(-Wdiscarded-qualifiers CC_HAS_DISCARDED_QUALIFIERS)
if (CC_HAS_DISCARDED_QUALIFIERS)
    add_definitions("-Wno-discarded-qualifiers")
endif()
check_c_compiler_flag(-Wincompatible-pointer-types CC_HAS_INCOMPATIBLE_POINTER_TYPES)
if (CC_HAS_INCOMPATIBLE_POINTER_TYPES)
    add_definitions("-Wno-incompatible-pointer-types")
endif()
check_c_compiler_flag(-Wdeprecated-declarations CC_HAS_DEPRECATED_DECLARATIONS)
if (CC_HAS_DEPRECATED_DECLARATIONS)
    add_definitions("-Wno-deprecated-declarations")
endif()
check_c_compiler_flag(-Wimplicit-function-declaration CC_HAS_IMPLICIT_FUNCTION_DECLARATION)
if (CC_HAS_IMPLICIT_FUNCTION_DECLARATION)
    add_definitions("-Wno-implicit-function-declaration")
endif()

vala_precompile(VALA_C
    ${VALA_SRC}
PACKAGES
    webkit2gtk-4.0
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

install(TARGETS
    pdfpc
RUNTIME
DESTINATION
    bin
)
