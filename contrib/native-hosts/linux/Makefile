# Generated files and binaries must be kept outside this checkout.
ifndef OUT
$(error Set OUT to an absolute build directory outside the source checkout)
endif
ifeq ($(filter /%,$(OUT)),)
$(error OUT must be absolute)
endif
ifneq ($(filter $(abspath ../../..)/% $(abspath ../../..),$(abspath $(OUT))),)
$(error OUT must be outside the source checkout)
endif

CC ?= cc
PKG_CONFIG ?= pkg-config
CPPFLAGS += -D_FILE_OFFSET_BITS=64
CFLAGS += -std=c11 -O2 -g -Wall -Wextra -Werror -Wformat=2 -Wconversion -Wshadow
FUSE_CFLAGS := $(shell $(PKG_CONFIG) --cflags fuse3)
FUSE_LIBS := $(shell $(PKG_CONFIG) --libs fuse3)

.PHONY: all
all: $(OUT)/writfs-linux $(OUT)/transport-probe $(OUT)/crash-probe

$(OUT):
	mkdir -p "$@"

$(OUT)/writfs-linux: writfs.c policy_pipe.c policy_pipe.h worker.c worker.h | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(FUSE_CFLAGS) writfs.c policy_pipe.c worker.c $(FUSE_LIBS) -o "$@"

$(OUT)/transport-probe: transport_probe.c policy_pipe.c policy_pipe.h | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) transport_probe.c policy_pipe.c -pthread -o "$@"

$(OUT)/crash-probe: crash_probe.c | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) crash_probe.c -o "$@"

# Nonprivileged synthetic scheduling test. Includes the production callbacks;
# it mocks FUSE/OS/policy calls and does not mount or probe native identity.
$(OUT)/handoff-order-test: handoff-order-test.c writfs.c policy_pipe.c policy_pipe.h worker.c worker.h | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(FUSE_CFLAGS) handoff-order-test.c policy_pipe.c worker.c $(FUSE_LIBS) -o "$@"

# Includes production worker.c with mocked process and descriptor operations.
$(OUT)/retire-error-test: retire-error-test.c worker.c worker.h | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) -ffunction-sections -Wl,--gc-sections retire-error-test.c -o "$@"

# Owned-process kernel test (board question 23): two disposable clone3
# children and private socket pairs only; no privilege, mount or host probing.
$(OUT)/channel-identity-test: channel-identity-test.c | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) channel-identity-test.c -o "$@"
