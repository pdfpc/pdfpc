#pragma once

#ifdef _WIN32

#include <Windows.h>

const int MAX_PATH_LENTH = MAX_PATH + 1; 

void GetProcessPath(char **path_array, int *path_length);

#endif