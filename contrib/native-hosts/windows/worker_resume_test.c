#include "worker.h"
#include <stdio.h>
#include <strsafe.h>
#include <wchar.h>

/* Both cases own a fresh child. The child accepts no handles and has a finite
   lifetime if the test fails to retire it. */
static BOOL check_resume(const wchar_t *image, BOOL extra_suspend)
{
    wchar_t command[32768];
    STARTUPINFOW startup = { sizeof(startup) };
    PROCESS_INFORMATION child = {0};
    WRIT_WORKER worker = {0};
    FILETIME exited, kernel, user;
    BOOL ok = FALSE;
    const char *stage = "create suspended child";
    if (FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"\"%s\" --child", image)) ||
        !CreateProcessW(image, command, NULL, NULL, FALSE, CREATE_SUSPENDED,
            NULL, NULL, &startup, &child)) goto done;
    worker.process = child.hProcess;
    worker.thread = child.hThread;
    worker.pid = child.dwProcessId;
    stage = "read child lifetime";
    if (!GetProcessTimes(worker.process, &worker.created, &exited, &kernel, &user)) goto done;

    if (extra_suspend) {
        stage = "add a second suspension";
        if (SuspendThread(worker.thread) != 1) goto done;
    } else {
        stage = "resume from one suspension";
        if (!writ_worker_resume(&worker)) goto done;
    }
    stage = extra_suspend ? "reject previous suspend count two" : "reject previous suspend count zero";
    if (writ_worker_resume(&worker) || GetLastError() != ERROR_INVALID_STATE) goto done;
    ok = TRUE;
done:
    if (!ok) fprintf(stderr, "FAIL worker resume test: %s (error=%lu)\n", stage, GetLastError());
    if (!writ_worker_stop(&worker)) {
        fprintf(stderr, "FAIL worker resume test: child retirement\n");
        ok = FALSE;
    }
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc == 2 && wcscmp(argv[1], L"--child") == 0) {
        Sleep(20000);
        return 0;
    }
    if (argc != 1) return 2;
    wchar_t image[32768];
    DWORD length = GetModuleFileNameW(NULL, image, ARRAYSIZE(image));
    if (!length || length >= ARRAYSIZE(image) ||
        !check_resume(image, FALSE) || !check_resume(image, TRUE)) return 1;
    puts("PASS native worker initial resume accepts 1 and rejects 0 and 2");
    return 0;
}
