find_package(PkgConfig)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)
pkg_check_modules(GEE REQUIRED gee-1.0)
pkg_check_modules(POPPLER REQUIRED poppler-glib)
pkg_check_modules(GTK REQUIRED gtk+-2.0)
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
pkg_check_modules(RSVG REQUIRED librsvg-2.0)

set(CFLAGS
	${GOBJECT_CFLAGS} ${GOBJECT_CFLAGS_OTHER}
	${GIO_CFLAGS} ${GIO_CFLAGS_OTHER}
        ${GEE_CFLAGS} ${GEE_CFLAGS_OTHER}
	${POPPLER_CFLAGS} ${POPPLER_CFLAGS_OTHER}
	${GTK_CFLAGS} ${GTK_CFLAGS_OTHER}
	${GTHREAD_CFLAGS} ${GTHREAD_CFLAGS_OTHER}
        ${RSVG_CFLAGS} ${RSVG_CFLAGS_OTHER}
)
add_definitions(${CFLAGS})

set(LIBS
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
        ${GEE_LIBRARIES}
	${POPPLER_LIBRARIES}
	${GTK_LIBRARIES}
	${GTHREAD_LIBRARIES}
        ${RSVG_LIBRARIES}
)
link_libraries(${LIBS})

set(LIB_PATHS
	${GOBJECT_LIBRARY_DIRS}
	${GIO_LIBRARY_DIRS}
        ${GEE_LIBRARY_DIRS}
	${POPPLER_LIBRARY_DIRS}
	${GTK_LIBRARY_DIRS}
	${GTHREAD_LIBRARY_DIRS}
        ${RSVG_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/paths.in ${CMAKE_CURRENT_SOURCE_DIR}/paths.vala)

file (GLOB_RECURSE VALA_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.vala)

vala_precompile(VALA_C
	${VALA_SRC}
PACKAGES 
	gio-2.0
        gee-1.0
	poppler-glib
	gtk+-2.0
	posix
        librsvg-2.0
OPTIONS 
	--thread
	--debug
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
