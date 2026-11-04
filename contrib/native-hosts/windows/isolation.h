#ifndef WRIT_WINDOWS_ISOLATION_H
#define WRIT_WINDOWS_ISOLATION_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* Mechanical Windows object ownership. These checks do not grant Bend authority. */
BOOL writ_process_security(SECURITY_ATTRIBUTES *attributes);
BOOL writ_protect_broker(void);
BOOL writ_ordinary_token(HANDLE token, PSID expected_user);
BOOL writ_same_user_probe(const wchar_t *image, HANDLE policy, HANDLE worker);
int writ_outsider_probe(int argc, wchar_t **argv);

#endif
