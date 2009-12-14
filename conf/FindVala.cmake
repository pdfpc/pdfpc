##
# The Vala Macros have been created by Florian Sowade
# Thanks for your help :)
##

# - Find vala compiler
# This module finds if vala compiler is installed and determines where the
# executables are. This code sets the following variables:
#
#  VALA_FOUND       - Was the vala compiler found
#  VALA_EXECUTABLE  - path to the vala compiler
#

find_program(VALA_EXECUTABLE
  NAMES valac)

# handle the QUIETLY and REQUIRED arguments and set VALA_FOUND to TRUE if
# all listed variables are TRUE
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Vala DEFAULT_MSG VALA_EXECUTABLE)

mark_as_advanced(VALA_EXECUTABLE)

# Determine vala version
execute_process(COMMAND ${VALA_EXECUTABLE} "--version" 
                OUTPUT_VARIABLE "VALA_VERSION")
string(REPLACE "Vala" "" "VALA_VERSION" ${VALA_VERSION})
string(STRIP ${VALA_VERSION} "VALA_VERSION")

# This is a helper Macro to parse optional arguments in Macros/Functions
# See http://www.cmake.org/Wiki/CMakeMacroParseArguments for documentation
macro(parse_arguments prefix arg_names option_names)
  set(DEFAULT_ARGS)
  foreach(arg_name ${arg_names})
    set(${prefix}_${arg_name})
  endforeach(arg_name)
  foreach(option ${option_names})
    set(${prefix}_${option} FALSE)
  endforeach(option)

  set(current_arg_name DEFAULT_ARGS)
  set(current_arg_list)
  foreach(arg ${ARGN})
    set(larg_names ${arg_names})
    list(FIND larg_names "${arg}" is_arg_name)
    if(is_arg_name GREATER -1)
      set(${prefix}_${current_arg_name} ${current_arg_list})
      set(current_arg_name ${arg})
      set(current_arg_list)
    else(is_arg_name GREATER -1)
      set(loption_names ${option_names})
      list(FIND loption_names "${arg}" is_option)
      if(is_option GREATER -1)
	    set(${prefix}_${arg} TRUE)
      else(is_option GREATER -1)
	    set(current_arg_list ${current_arg_list} ${arg})
      endif(is_option GREATER -1)
    endif(is_arg_name GREATER -1)
  endforeach(arg)
  set(${prefix}_${current_arg_name} ${current_arg_list})
endmacro(parse_arguments)

# vala_precompile[output src.vala ... [PACKAGES ...] [OPTIONS ...]]
# This macro precomiples the given vala files to .c files and puts
# a list with the generated .c files to output.
# packages and additional compiler options are directly passed to the
# vala compiler.
macro(vala_precompile output)
	include_directories(${CMAKE_CURRENT_BINARY_DIR})
	parse_arguments(ARGS "PACKAGES;OPTIONS;GENERATE_HEADER;GENERATE_VAPI" "" ${ARGN})
	set(vala_pkg_opts "")
	foreach(pkg ${ARGS_PACKAGES})
		list(APPEND vala_pkg_opts "--pkg=${pkg}")
	endforeach(pkg ${ARGS_PACKAGES})
	set(in_files, "")
	set(out_files, "")
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
		list(APPEND header_arguments "-H")
		list(APPEND header_arguments "${ARGS_GENERATE_HEADER}.h")
	endif(ARGS_GENERATE_HEADER)

	set(vapi_arguments "")
	if(ARGS_GENERATE_VAPI)
		list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.vapi")
		set(vapi_arguments "--library=${ARGS_GENERATE_VAPI}")
	endif(ARGS_GENERATE_VAPI)

	add_custom_command(OUTPUT ${out_files} 
					   COMMAND ${VALA_EXECUTABLE} ARGS "-C" ${header_arguments} ${vapi_arguments}
					   "-b" ${CMAKE_CURRENT_SOURCE_DIR} "-d" ${CMAKE_CURRENT_BINARY_DIR} 
					   ${vala_pkg_opts} ${ARGS_OPTIONS} ${in_files}
					   DEPENDS ${in_files})
endmacro(vala_precompile)
