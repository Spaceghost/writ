#ifndef WRIT_WINDOWS_CHANNELS_H
#define WRIT_WINDOWS_CHANNELS_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef struct { DWORD stage; HRESULT result; } WRIT_CHANNEL_RESULT;

/* Fixed native probes. No clipboard contents or COM methods are read/invoked. */
WRIT_CHANNEL_RESULT writ_clipboard_attempt(void);
WRIT_CHANNEL_RESULT writ_com_attempt(void);
BOOL writ_clipboard_denied(WRIT_CHANNEL_RESULT result);
BOOL writ_com_denied(WRIT_CHANNEL_RESULT result);

#endif
