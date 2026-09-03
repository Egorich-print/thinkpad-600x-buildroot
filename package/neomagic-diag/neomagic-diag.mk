################################################################################
#
# neomagic-diag
#
################################################################################

NEOMAGIC_DIAG_VERSION = 1.0
NEOMAGIC_DIAG_SITE = $(BR2_EXTERNAL_THINKPAD600X_PATH)/tools/neomagic_diag
NEOMAGIC_DIAG_SITE_METHOD = local
NEOMAGIC_DIAG_LICENSE = MIT
NEOMAGIC_DIAG_LICENSE_FILES = neomagic_diag.c

define NEOMAGIC_DIAG_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -static \
		-o $(@D)/neomagic_diag $(@D)/neomagic_diag.c
endef

define NEOMAGIC_DIAG_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/neomagic_diag \
		$(TARGET_DIR)/usr/bin/neomagic_diag
endef

$(eval $(generic-package))