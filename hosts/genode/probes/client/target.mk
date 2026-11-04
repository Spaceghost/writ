#
# target.mk for writ_channel_client - Genode build configuration for the
# client probe (scaffolding, not a Writ client). Genode channel lane,
# Task 2. Live copy: ../writ-genode/writ-repo/src/app/writ_channel_client/
# (with writ_channel_client.cc). The session header comes from the shim's
# directory, $(REP_DIR)/src/writ_shim/ (hosts/genode/shim/).
#
TARGET  = writ_channel_client
SRC_CC  = writ_channel_client.cc
LIBS    = base
INC_DIR += $(REP_DIR)/src/writ_shim
