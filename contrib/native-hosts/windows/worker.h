#ifndef WRIT_WINDOWS_WORKER_H
#define WRIT_WINDOWS_WORKER_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef struct {
    HANDLE process, thread, job, image, network;
    DWORD pid;
    FILETIME created;
    TOKEN_STATISTICS token;
    BYTE user_sid[SECURITY_MAX_SID_SIZE];
    PSID app_sid;
    wchar_t profile[96];
    wchar_t image_path[32768];
    wchar_t private_directory[MAX_PATH];
    wchar_t private_image[MAX_PATH];
    BYTE image_hash[32];
    BOOL lpac, profile_created, directory_created, image_created;
    UINT64 filters[4];
} WRIT_WORKER;

BOOL writ_worker_create(WRIT_WORKER *worker, const wchar_t *image,
    wchar_t *command, HANDLE *inherited, DWORD inherited_count, BOOL lpac);
BOOL writ_worker_alive(const WRIT_WORKER *worker);
BOOL writ_worker_matches(const WRIT_WORKER *worker, DWORD pid, HANDLE request_token);
BOOL writ_worker_resume(WRIT_WORKER *worker);
BOOL writ_worker_terminate(WRIT_WORKER *worker);
BOOL writ_worker_remove_network_filters(WRIT_WORKER *worker);
BOOL writ_worker_stop(WRIT_WORKER *worker);

#endif
