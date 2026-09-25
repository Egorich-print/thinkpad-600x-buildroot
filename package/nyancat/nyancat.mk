################################################################################
#
# nyancat
#
################################################################################

NYANCAT_VERSION = 1.5.2
NYANCAT_SOURCE = nyancat-$(NYANCAT_VERSION).tar.gz
NYANCAT_SITE = https://github.com/klange/nyancat/archive/refs/tags/$(NYANCAT_VERSION)
NYANCAT_LICENSE = NCSA
# The 1.5.2 tarball has no LICENSE file: the grant lives in the source header.
NYANCAT_LICENSE_FILES = src/nyancat.c
NYANCAT_DEPENDENCIES = ncurses

define NYANCAT_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)"
endef

define NYANCAT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/src/nyancat $(TARGET_DIR)/usr/bin/nyancat
endef

$(eval $(generic-package))
