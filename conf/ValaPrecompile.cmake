include(ParseArguments)

# vala_precompile[output src.vala ... [PACKAGES ...] [OPTIONS ...]]
# This macro precomiples the given vala files to .c files and puts
# a list with the generated .c files to output.
# packages and additional compiler options are directly passed to the
# vala compiler.
macro(vala_precompile output)
	include_directories(${CMAKE_CURRENT_BINARY_DIR})
	parse_arguments(ARGS "PACKAGES;OPTIONS;GENERATE_HEADER;GENERATE_VAPI;CUSTOM_VAPIS" "" ${ARGN})
	set(vala_pkg_opts "")
	foreach(pkg ${ARGS_PACKAGES})
		list(APPEND vala_pkg_opts "--pkg=${pkg}")
	endforeach(pkg ${ARGS_PACKAGES})
	set(in_files "")
	set(out_files "")
	set(${output} "")
	foreach(src ${ARGS_DEFAULT_ARGS})
		list(APPEND in_files "${CMAKE_CURRENT_SOURCE_DIR}/${src}")
		string(REPLACE ".vala" ".c" src ${src})
		set(out_file "${CMAKE_CURRENT_BINARY_DIR}/${src}")
		list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${src}")
		list(APPEND ${output} ${out_file})
	endforeach(src ${ARGS_DEFAULT_ARGS})

	set(header_arguments "")
	if(ARGS_GENERATE_HEADER)
		list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_HEADER}.h")
		list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_HEADER}_internal.h")
		list(APPEND header_arguments "--header=${ARGS_GENERATE_HEADER}.h")
		list(APPEND header_arguments "--internal-header=${ARGS_GENERATE_HEADER}_internal.h")
	endif(ARGS_GENERATE_HEADER)

	set(vapi_arguments "")
	if(ARGS_GENERATE_VAPI)
		list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.vapi")
		set(vapi_arguments "--internal-vapi=${ARGS_GENERATE_VAPI}.vapi")
	endif(ARGS_GENERATE_VAPI)

	add_custom_command(OUTPUT ${out_files} 
					   COMMAND ${VALA_EXECUTABLE} ARGS "-C" ${header_arguments} ${vapi_arguments}
					   "-b" ${CMAKE_CURRENT_SOURCE_DIR} "-d" ${CMAKE_CURRENT_BINARY_DIR} 
					   ${vala_pkg_opts} ${ARGS_OPTIONS} ${in_files} ${ARGS_CUSTOM_VAPIS}
					   DEPENDS ${in_files} ${ARGS_CUSTOM_VAPIS})
endmacro(vala_precompile)
