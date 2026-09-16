################################################################################
#
# aquarium
#
################################################################################

AQUARIUM_VERSION = 1.0
AQUARIUM_SITE = $(BR2_EXTERNAL_THINKPAD600X_PATH)/tools/aquarium
AQUARIUM_SITE_METHOD = local
AQUARIUM_LICENSE = MIT
AQUARIUM_LICENSE_FILES = aquarium.c
AQUARIUM_DEPENDENCIES = ncurses

define AQUARIUM_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Os \
		-o $(@D)/aquarium $(@D)/aquarium.c \
		$(TARGET_LDFLAGS) -lncurses
endef

define AQUARIUM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/aquarium $(TARGET_DIR)/usr/bin/aquarium
endef

$(eval $(generic-package))
