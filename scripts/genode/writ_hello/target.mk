#
# target.mk for writ_hello - Genode build configuration, not Writ
# implementation. Builds the trivial bring-up component of the Genode
# component lane (Task 1) from main.cc against Genode's base library.
#
TARGET = writ_hello
SRC_CC = main.cc
LIBS   = base
