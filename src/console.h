#pragma once

/**
 * Taken from: https://github.com/xournalpp/xournalpp/blob/700308a27457116ae804429631d5f31a525ff9b7/src/exe/win32/console.h
 */

/**
 * Allocates a new (hidden) console and associates the standard input and output handles with it.
 */
void attachConsole();
