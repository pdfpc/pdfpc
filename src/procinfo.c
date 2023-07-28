#ifdef _WIN32
#include <Windows.h>
#include "console.h"

void GetProcessPath(char **path_array, int *path_length) {
    GetModuleFileNameA(NULL, *path_array, *path_length);
} 

#endif