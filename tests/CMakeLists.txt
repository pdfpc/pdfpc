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
	pdf_presenter_console_test_library
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

set(TEST_SRC
	foobar.vala
)

# The presenter.h needs to be found during test compiles
include_directories(
	"${CMAKE_CURRENT_BINARY_DIR}/../src"
)

# Unfortunately the "test" target name is already registered with ctest
# therefore we create our own
add_custom_target("check" COMMAND ${CMAKE_CTEST_COMMAND} "-V")

foreach(test_file_src ${TEST_SRC})
	string(REPLACE ".vala" "" test_executable ${test_file_src})
	
	vala_precompile(TEST_C
		${test_file_src} 
	PACKAGES 
		gio-2.0
		poppler-glib
		gtk+-2.0
		posix
	CUSTOM_VAPIS
		"${CMAKE_CURRENT_BINARY_DIR}/../src/presenter.vapi"
	OPTIONS 
		--thread
	)

	add_executable(${test_executable}
		EXCLUDE_FROM_ALL
		${TEST_C}
	)

	add_dependencies("check" ${test_executable})

	add_test(${test_executable}
		"${CMAKE_CURRENT_BINARY_DIR}/${test_executable}"
	)
endforeach(test_file_src ${TEST_SRC})
