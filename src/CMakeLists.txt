find_package(PkgConfig)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)
pkg_check_modules(GEE REQUIRED gee-0.8)
pkg_check_modules(POPPLER REQUIRED poppler-glib)
pkg_check_modules(GTK REQUIRED gtk+-3.0>=3.10)
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
pkg_check_modules(PANGOCAIRO REQUIRED pangocairo)
if (MOVIES)
    pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0)
    pkg_check_modules(GSTBASE REQUIRED gstreamer-base-1.0)
    pkg_check_modules(GSTAUDIO REQUIRED gstreamer-audio-1.0)
    pkg_check_modules(GSTVIDEO REQUIRED gstreamer-video-1.0)
    pkg_check_modules(GDKX11 REQUIRED gdk-x11-3.0)
    set(MOVIE_PACKAGES
        gstreamer-1.0
        gstreamer-base-1.0
        gstreamer-audio-1.0
        gstreamer-video-1.0
        gdk-x11-3.0
    )
endif ()

if ("${GTK_VERSION}" LESS 3.18 OR "${VALA_VERSION}" LESS 0.30)
    message(WARNING "Using legacy GTK API")
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D GTK_LEGACY)
endif ()

set(CFLAGS
    ${GOBJECT_CFLAGS} ${GOBJECT_CFLAGS_OTHER}
    ${GIO_CFLAGS} ${GIO_CFLAGS_OTHER}
    ${GEE_CFLAGS} ${GEE_CFLAGS_OTHER}
    ${POPPLER_CFLAGS} ${POPPLER_CFLAGS_OTHER}
    ${GTK_CFLAGS} ${GTK_CFLAGS_OTHER}
    ${GTHREAD_CFLAGS} ${GTHREAD_CFLAGS_OTHER}
    ${PANGOCAIRO_CFLAGS} ${PANGOCAIRO_CFLAGS_OTHER}
    ${GSTREAMER_CFLAGS} ${GSTREAMER_CFLAGS_OTHER}
    ${GSTINTERFACES_CFLAGS} ${GSTINTERFACES_CFLAGS_OTHER}
    ${GSTVIDEO_CFLAGS} ${GSTVIDEO_CFLAGS_OTHER}
    ${GDKX11_CFLAGS} ${GDKX11_CFLAGS_OTHER}
)
add_definitions(${CFLAGS})

set(LIBS
    ${GOBJECT_LIBRARIES}
    ${GIO_LIBRARIES}
    ${GEE_LIBRARIES}
    ${POPPLER_LIBRARIES}
    ${GTK_LIBRARIES}
    ${GTHREAD_LIBRARIES}
    ${PANGOCAIRO_LIBRARIES}
    ${GSTREAMER_LIBRARIES}
    ${GSTINTERFACES_LIBRARIES}
    ${GSTVIDEO_LIBRARIES}
    ${GDKX11_LIBRARIES}
)
link_libraries(${LIBS})

set(LIB_PATHS
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
    ${GDKX11_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/paths.in ${CMAKE_CURRENT_SOURCE_DIR}/paths.vala)

file (GLOB_RECURSE VALA_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.vala)
if (MOVIES)
    set(EXTRA_VALA_OPTIONS ${EXTRA_VALA_OPTIONS} -D MOVIES)
else ()
    LIST(REMOVE_ITEM VALA_SRC classes/action/movie.vala)
endif ()

vala_precompile(VALA_C
    ${VALA_SRC}
PACKAGES
    gio-2.0
    gee-0.8
    poppler-glib
    gtk+-3.0
    pangocairo
    posix
    ${MOVIE_PACKAGES}
OPTIONS
    --thread
    --debug
    --enable-experimental
    ${EXTRA_VALA_OPTIONS}
GENERATE_HEADER
    presenter
GENERATE_VAPI
    presenter
)

add_executable(pdfpc
    ${VALA_C}
)

# explicitly add libraries (needed e.g. for Fedora 13+)
target_link_libraries(pdfpc -lm)

install(TARGETS
    pdfpc
RUNTIME
DESTINATION
    bin
)

# The tests need a library version of all the pdf_presenter_stuff
add_library(pdf_presenter_console_test_library
    SHARED
    EXCLUDE_FROM_ALL
    ${VALA_C} presenter.h presenter.vapi
)
