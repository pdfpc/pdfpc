##
# Copyright 2009 Jakob Westhoff. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY JAKOB WESTHOFF ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL JAKOB WESTHOFF OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of Jakob Westhoff
##

include(ParseArguments)
find_package(Vala REQUIRED)

##
# Compile vala files to their c equivalents for further processing. 
#
# The "vala_precompile" macro takes care of calling the valac executable on the
# given source to produce c files which can then be processed further using
# default cmake functions.
# 
# The first parameter provided is a variable, which will be filled with a list
# of c files outputted by the vala compiler. This list can than be used in
# conjuction with functions like "add_executable" or others to create the
# neccessary compile rules with CMake.
# 
# The initial variable is followed by a list of .vala files to be compiled.
# Please take care to add every vala file belonging to the currently compiled
# project or library as Vala will otherwise not be able to resolve all
# dependencies.
# 
# The following sections may be specified afterwards to provide certain options
# to the vala compiler:
# 
# PACKAGES
#   A list of vala packages/libraries to be used during the compile cycle. The
#   package names are exactly the same, as they would be passed to the valac
#   "--pkg=" option.
# 
# OPTIONS
#   A list of optional options to be passed to the valac executable. This can be
#   used to pass "--thread" for example to enable multi-threading support.
#
# CUSTOM_VAPIS
#   A list of custom vapi files to be included for compilation. This can be
#   useful to include freshly created vala libraries without having to install
#   them in the system.
#
# GENERATE_VAPI
#   Pass all the needed flags to the compiler to create an internal vapi for
#   the compiled library. The provided name will be used for this and a
#   <provided_name>.vapi file will be created.
# 
# GENERATE_HEADER
#   Let the compiler generate a header file for the compiled code. There will
#   be a header file as well as an internal header file being generated called
#   <provided_name>.h and <provided_name>_internal.h
#
# The following call is a simple example to the vala_precompile macro showing
# an example to every of the optional sections:
#
#   vala_precompile(VALA_C
#       source1.vala
#       source2.vala
#       source3.vala
#   PACKAGES
#       gtk+-2.0
#       gio-1.0
#       posix
#   OPTIONS
#       --thread
#   CUSTOM_VAPIS
#       some_vapi.vapi
#   GENERATE_VAPI
#       myvapi
#   GENERATE_HEADER
#       myheader
#   )
#
# Most important is the variable VALA_C which will contain all the generated c
# file names after the call.
##

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

    set(vapi_arguments "")
    if(ARGS_GENERATE_VAPI)
        list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_VAPI}.vapi")
        set(vapi_arguments "--internal-vapi=${ARGS_GENERATE_VAPI}.vapi")

        # Header and internal header is needed to generate internal vapi
        if (NOT ARGS_GENERATE_HEADER)
            set(ARGS_GENERATE_HEADER ${ARGS_GENERATE_VAPI})
        endif(NOT ARGS_GENERATE_HEADER)
    endif(ARGS_GENERATE_VAPI)

    set(header_arguments "")
    if(ARGS_GENERATE_HEADER)
        list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_HEADER}.h")
        list(APPEND out_files "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_GENERATE_HEADER}_internal.h")
        list(APPEND header_arguments "--header=${ARGS_GENERATE_HEADER}.h")
        list(APPEND header_arguments "--internal-header=${ARGS_GENERATE_HEADER}_internal.h")
    endif(ARGS_GENERATE_HEADER)

    add_custom_command(OUTPUT ${out_files} 
    COMMAND 
        ${VALA_EXECUTABLE} 
    ARGS 
        "-C" 
        ${header_arguments} 
        ${vapi_arguments}
        "-b" ${CMAKE_CURRENT_SOURCE_DIR} 
        "-d" ${CMAKE_CURRENT_BINARY_DIR} 
        ${vala_pkg_opts} 
        ${ARGS_OPTIONS} 
        ${in_files} 
        ${ARGS_CUSTOM_VAPIS}
    DEPENDS 
        ${in_files} 
        ${ARGS_CUSTOM_VAPIS}
    )
endmacro(vala_precompile)
