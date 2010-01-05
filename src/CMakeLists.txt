find_package(PkgConfig)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)
pkg_check_modules(POPPLER REQUIRED poppler-glib)
pkg_check_modules(GTK REQUIRED gtk+-2.0)
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)

set(CFLAGS
	${GOBJECT_CFLAGS} ${GOBJECT_CFLAGS_OTHER}
	${GIO_CFLAGS} ${GIO_CFLAGS_OTHER}
	${POPPLER_CFLAGS} ${POPPLER_CFLAGS_OTHER}
	${GTK_CFLAGS} ${GTK_CFLAGS_OTHER}
	${GTHREAD_CFLAGS} ${GTHREAD_CFLAGS_OTHER}
)
add_definitions(${CFLAGS})

set(LIBS
	${GOBJECT_LIBRARIES}
	${GIO_LIBRARIES}
	${POPPLER_LIBRARIES}
	${GTK_LIBRARIES}
	${GTHREAD_LIBRARIES}
)
link_libraries(${LIBS})

set(LIB_PATHS
	${GOBJECT_LIBRARY_DIRS}
	${GIO_LIBRARY_DIRS}
	${POPPLER_LIBRARY_DIRS}
	${GTK_LIBRARY_DIRS}
	${GTHREAD_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})

set(VALA_SRC
	pdf_presenter_console.vala
	classes/cache_status.vala
	classes/fullscreen_window.vala
	classes/link_handler.vala
	classes/link_handler/default_link_handler.vala
	classes/pdf_event_box.vala
	classes/pdf_image.vala
	classes/presentation_controller.vala
	classes/presentation_window.vala
	classes/presenter_window.vala
	classes/timer_label.vala
	interfaces/controllable.vala
)

# Vala segfaults if its output dirs are not existant. Therefore make sure they
# are there.
if (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/classes")
	make_directory("${CMAKE_CURRENT_BINARY_DIR}/classes")
endif (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/classes")
if (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/interfaces")
	make_directory("${CMAKE_CURRENT_BINARY_DIR}/interfaces")
endif (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/interfaces")

vala_precompile(VALA_C
	${VALA_SRC}
PACKAGES 
	gio-2.0
	poppler-glib
	gtk+-2.0
	posix
OPTIONS 
	--thread
GENERATE_HEADER
	presenter
GENERATE_VAPI
	presenter
)

add_executable(pdf_presenter_console
  	${VALA_C}
)

install(TARGETS 
	pdf_presenter_console
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
