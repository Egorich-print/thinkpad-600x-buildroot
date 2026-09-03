################################################################################
#
# openmotif
#
################################################################################

OPENMOTIF_VERSION = 2.3.8
OPENMOTIF_SOURCE = motif-$(OPENMOTIF_VERSION).tar.gz
OPENMOTIF_SITE = https://downloads.sourceforge.net/project/motif/Motif%20$(OPENMOTIF_VERSION)%20Source%20Code
OPENMOTIF_LICENSE = LGPL-2.1+
OPENMOTIF_LICENSE_FILES = COPYING
OPENMOTIF_INSTALL_STAGING = YES
OPENMOTIF_DEPENDENCIES = xlib_libX11 xlib_libXt xlib_libXext xlib_libXmu \
	xlib_libXpm xlib_libXrender xlib_libXft xlib_libXinerama \
	fontconfig freetype jpeg libpng

OPENMOTIF_CONF_ENV = \
	ac_cv_file__usr_X_include_X11_X_h=no \
	ac_cv_file__usr_X11R6_include_X11_X_h=no \
	ac_cv_func_setpgrp_void=yes \
	ac_cv_func_setvbuf_reversed=no \
	CFLAGS="$(TARGET_CFLAGS) -include string.h -include stdlib.h -include stdio.h" \
	CXXFLAGS="$(TARGET_CXXFLAGS) -include string.h -include stdlib.h -include stdio.h"

OPENMOTIF_CONF_OPTS = \
	--enable-xft \
	--enable-jpeg \
	--enable-png \
	--disable-printing

# Motif cross-compile fixes, applied to the GENERATED Makefiles (not Makefile.am,
# to avoid triggering the tarball's stale automake-1.15 regeneration rule):
#  - drop tools/demos/doc from SUBDIRS (they pull the WML host-tool chain)
#  - stop the target build from regenerating makestrs (a host tool that must run)
define OPENMOTIF_FIX_MAKEFILES
	sed -i -e '/tools \\$$/d' -e '/clients \\$$/d' -e '/doc \\$$/d' \
		-e '/demos$$/d' -e 's/include \\$$/include/' $(@D)/Makefile
	sed -i '/^noinst_PROGRAMS/d' $(@D)/config/util/Makefile
endef
OPENMOTIF_PRE_BUILD_HOOKS += OPENMOTIF_FIX_MAKEFILES

define OPENMOTIF_BUILD_HOST_TOOLS
	$(HOSTCC) $(HOST_CFLAGS) -I$(STAGING_DIR)/usr/include \
		-o $(@D)/config/util/makestrs $(@D)/config/util/makestrs.c
endef
OPENMOTIF_PRE_BUILD_HOOKS += OPENMOTIF_BUILD_HOST_TOOLS

define OPENMOTIF_POST_INSTALL_TARGET_RM
	rm -rf $(TARGET_DIR)/usr/share?dir 2>/dev/null || true
endef

# Drop the Motif demo programs to keep rootfs small; keep libXm/libMrm/libUil.
define OPENMOTIF_POST_INSTALL_TARGET_SLIM
	rm -f $(TARGET_DIR)/usr/bin/mwm $(TARGET_DIR)/usr/bin/uil $(TARGET_DIR)/usr/bin/xmbind 2>/dev/null || true
	rm -f $(TARGET_DIR)/usr/lib/libXm.a $(TARGET_DIR)/usr/lib/libMrm.a $(TARGET_DIR)/usr/lib/libUil.a 2>/dev/null || true
	rm -rf $(TARGET_DIR)/usr/share/doc/motif* $(TARGET_DIR)/usr/share/man/*/mwm* 2>/dev/null || true
endef
OPENMOTIF_POST_INSTALL_TARGET_HOOKS += OPENMOTIF_POST_INSTALL_TARGET_SLIM

$(eval $(autotools-package))