#pragma once

#ifdef _WIN32

/**
 * Detatches console if not needed (if parent process is not cmd.exe or powershell.exe)
 */
void hideConsoleIfNotNeeded();

#endif