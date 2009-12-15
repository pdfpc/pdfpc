# - Find vala compiler
# This module finds if vala compiler is installed and determines where the
# executables are. This code sets the following variables:
#
#  VALA_FOUND       - Was the vala compiler found
#  VALA_EXECUTABLE  - path to the vala compiler
#  VALA_VERSION     - The version number of the available valac

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
