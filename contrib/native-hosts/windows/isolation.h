#ifndef WRIT_WINDOWS_ISOLATION_H
#define WRIT_WINDOWS_ISOLATION_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* Mechanical Windows object ownership. These checks do not grant Bend authority. */
BOOL writ_process_security(SECURITY_ATTRIBUTES *attributes);
#define WRIT_ENVIRONMENT_CAPACITY 4096
BOOL writ_child_environment(wchar_t *system_root, DWORD root_capacity,
    wchar_t *environment, size_t capacity, const wchar_t *private_temp);
BOOL writ_protect_broker(void);
BOOL writ_ordinary_token(HANDLE token, PSID expected_user);
BOOL writ_same_user_probe(const wchar_t *image, HANDLE policy, HANDLE worker);
BOOL writ_positive_channels(const wchar_t *image);
int writ_outsider_probe(int argc, wchar_t **argv);

#endif
