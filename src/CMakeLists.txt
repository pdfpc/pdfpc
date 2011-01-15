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
	classes/cache_status.vala
	classes/metadata/base.vala
	classes/metadata/pdf.vala
	classes/mutex_locks.vala
	classes/options.vala
	classes/presentation_controller.vala
	classes/renderer/base.vala
	classes/renderer/pdf.vala
	classes/renderer/cache/base.vala
	classes/renderer/cache/simple/engine.vala
	classes/renderer/cache/png/item.vala
	classes/renderer/cache/png/engine.vala
	classes/renderer/cache/option_factory.vala
	classes/scaler.vala
	classes/timer_label.vala
	classes/view/base.vala
	classes/view/default.vala
	classes/view/pdf.vala
	classes/view/behaviour/base.vala
	classes/view/behaviour/pdf_link/implementation.vala
	classes/view/behaviour/pdf_link/signal_provider.vala
	classes/window/fullscreen.vala
	classes/window/presentation.vala
	classes/window/presenter.vala
	interfaces/renderer/caching.vala
	interfaces/view/prerendering.vala
	interfaces/view/behaviour/decoratable.vala
	interfaces/controllable.vala
	pdf_presenter_console.vala
)

# Vala segfaults if its output dirs are not existant. Therefore make sure they
# are there.
macro(make_compile_directory directory)
	if (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${directory}")
		make_directory("${CMAKE_CURRENT_BINARY_DIR}/${directory}")
	endif (NOT IS_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${directory}")
endmacro(make_compile_directory)

vala_precompile(VALA_C
	${VALA_SRC}
PACKAGES 
	gio-2.0
	poppler-glib
	gtk+-2.0
	posix
OPTIONS 
	--thread
	--debug
GENERATE_HEADER
	presenter
GENERATE_VAPI
	presenter
)

add_executable(pdf_presenter_console
  	${VALA_C}
)

# explicitly add libraries (needed e.g. for Fedora 13+)
target_link_libraries(pdf_presenter_console -lm)

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
