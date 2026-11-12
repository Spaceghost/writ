ifndef OUT
$(error Set OUT to a new absolute directory outside the checkout)
endif
ifeq ($(filter /%,$(OUT)),)
$(error OUT must be absolute)
endif
ifneq ($(filter $(abspath ../../../..)/% $(abspath ../../../..),$(abspath $(OUT))),)
$(error Build outside the source checkout)
endif
CC ?= cc
CXX ?= c++
VERSION ?= development
SOURCE_COMMIT ?= unknown
FUSE_CFLAGS ?= $(shell pkg-config --cflags fuse3)
FUSE_LIBS ?= $(shell pkg-config --libs fuse3)
CPPFLAGS += -D_FILE_OFFSET_BITS=64 -DWRIT_VERSION='"$(VERSION)"' -DWRIT_SOURCE_COMMIT='"$(SOURCE_COMMIT)"'
CFLAGS += -std=c11 -O2 -Wall -Wextra -Werror -ffile-prefix-map=$(CURDIR)=. -ffile-prefix-map=$(OUT)=.
CXXFLAGS += -std=c++17 -O2 -Wall -Wextra -Werror -ffile-prefix-map=$(CURDIR)=. -ffile-prefix-map=$(OUT)=.
LDLIBS += $(FUSE_LIBS) -lcrypto -pthread
LDFLAGS += -Wl,--build-id=sha1 -Wl,-rpath,'$$ORIGIN/lib'
.PHONY: all
all: $(OUT)/writ-linux
$(OUT):
	mkdir -p "$@"
$(OUT)/policy_pipe.o: ../policy_pipe.c ../policy_pipe.h | $(OUT)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ../policy_pipe.c -o "$@"
$(OUT)/writ-linux: provider.cpp native.hpp $(OUT)/policy_pipe.o
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(FUSE_CFLAGS) provider.cpp $(OUT)/policy_pipe.o $(LDFLAGS) $(LDLIBS) -o "$@"
