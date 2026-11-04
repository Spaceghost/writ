ifeq ($(WRIT_QUICKJS_DIR),)
$(error WRIT_QUICKJS_DIR must name the verified QuickJS 2026-06-04 source)
endif

SRC_C = quickjs.c dtoa.c libregexp.c libunicode.c cutils.c
INC_DIR += $(WRIT_QUICKJS_DIR) $(REP_DIR)/../runtime/genode
LIBS += libc libm

# These substitutions preserve allocation sizes and impose a hard heap bound.
# They do not change JavaScript operations or Bend-generated policy.
CC_OPT += -include $(REP_DIR)/../runtime/genode/quickjs_alloc.h
CC_OPT += -Dmalloc=writ_qjs_malloc -Drealloc=writ_qjs_realloc
CC_OPT += -Dfree=writ_qjs_free -Dmalloc_usable_size=writ_qjs_usable_size
CC_OPT += -DCONFIG_VERSION='"2026-06-04"'
CC_WARN =
CC_CXX_WARN_STRICT =
vpath %.c $(WRIT_QUICKJS_DIR)
