#
# writ_shim.mk - Genode build configuration for the shim's fault front end
# (build configuration, not Writ implementation). Genode base-hw lane,
# Task 1. Included by every target.mk that compiles writ_mem.cc: through
# scripts/genode/writ_bend.inc for the Bend components, and directly by
# hosts/genode/probes/reservation/target.mk. Live copy:
# ../writ-genode/writ-repo/src/writ_shim/writ_shim.mk (byte-identical, beside
# writ_mem.cc).
#
# writ_mem.cc compiles exactly one of its two fault front ends (its header,
# "Fault delivery"). The choice follows the build directory's KERNEL, which
# tool/builddir/build.mk exports to every target build (build.mk:74-75) and
# which etc/build.conf sets: KERNEL ?= linux in ../writ-genode/build/x86_64,
# KERNEL ?= hw in ../writ-genode/build/x86_64-hw. The macro is added to
# CC_CXX_OPT only, so the generated C (CC_C_OPT, clang) is compiled exactly
# as before. Any other kernel stops the build here; writ_mem.cc also refuses
# to compile without exactly one of the two macros.
#
ifeq ($(KERNEL),linux)
CC_CXX_OPT += -DWRIT_SHIM_FAULT_LINUX_SIGSEGV
else ifeq ($(KERNEL),hw)
CC_CXX_OPT += -DWRIT_SHIM_FAULT_REGION_MAP
else
$(error writ_shim.mk: no fault front end for KERNEL='$(KERNEL)' (linux and hw only))
endif
