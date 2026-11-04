#include <libc/component.h>
#include <base/log.h>
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconversion"
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <string.h>
#pragma GCC diagnostic pop

namespace {

struct Failed { };
char const canary[] = "Writ native Genode public canary\n";

void check(bool ok, char const *name)
{
    if (!ok) { Genode::error("FAIL ", name); throw Failed(); }
    Genode::log("PASS ", name);
}

void run()
{
    int fd = open("/writ/data", O_RDONLY);
    check(fd >= 0, "libc opens Writ through native VFS File_system mount");
    char bytes[64] { };
    ssize_t n = read(fd, bytes, sizeof(bytes));
    check(n == ssize_t(sizeof(canary) - 1) && !memcmp(bytes, canary, sizeof(canary) - 1),
          "libc reads exact immutable canary");
    check(lseek(fd, 5, SEEK_SET) == 5, "libc seek succeeds");
    n = read(fd, bytes, 8);
    check(n == 8 && !memcmp(bytes, canary + 5, 8), "libc ranged read is exact");
    struct stat st { };
    check(!fstat(fd, &st) && st.st_size == off_t(sizeof(canary) - 1), "libc stat reports exact registered size");
    check(open("/writ/data", O_WRONLY) == -1, "libc write-open is denied");
    check(open("/writ/other", O_RDONLY) == -1, "libc cannot open unregistered object");
    check(!close(fd), "libc closes the native handle");
}

}

void Libc::Component::construct(Libc::Env &env)
{
    try {
        Libc::with_libc([] { run(); });
        Genode::log("WRITFS VFS NATIVE PASS");
        env.parent().exit(0);
    } catch (...) {
        Genode::error("WRITFS VFS NATIVE FAIL");
        env.parent().exit(1);
    }
}
