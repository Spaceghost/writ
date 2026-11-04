TARGET = test_writ_policy
SRC_CC = main.cc policy.cc core_checks.cc
SRC_C = quickjs_alloc.c
LIBS = base libc libm writ_quickjs
INC_DIR += $(REP_DIR)/../runtime/genode $(WRIT_QUICKJS_DIR)
vpath policy.cc $(REP_DIR)/../runtime/genode
vpath core_checks.cc $(REP_DIR)/../runtime/genode
vpath quickjs_alloc.c $(REP_DIR)/../runtime/genode
