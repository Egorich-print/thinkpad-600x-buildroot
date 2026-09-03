################################################################################
#
# btop
#
################################################################################

BTOP_VERSION = 1.4.7
BTOP_SITE = $(call github,aristocratos,btop,v$(BTOP_VERSION))
BTOP_LICENSE = Apache-2.0
BTOP_LICENSE_FILES = LICENSE

define BTOP_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CXX="$(TARGET_CXX)" \
		CC="$(TARGET_CC)" \
		OPTFLAGS="$(TARGET_CXXFLAGS)" \
		ADDFLAGS="$(TARGET_LDFLAGS)" \
		GPU_SUPPORT=false STATIC=false
endef

define BTOP_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install \
		PREFIX=/usr DESTDIR=$(TARGET_DIR) GPU_SUPPORT=false
	rm -f $(TARGET_DIR)/usr/share/btop/darwin 2>/dev/null || true
endef

$(eval $(generic-package))