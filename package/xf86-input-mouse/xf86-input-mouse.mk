################################################################################
#
# xf86-input-mouse
#
################################################################################

XF86_INPUT_MOUSE_VERSION = 1.9.5
XF86_INPUT_MOUSE_SOURCE = xf86-input-mouse-$(XF86_INPUT_MOUSE_VERSION).tar.xz
XF86_INPUT_MOUSE_SITE = https://xorg.freedesktop.org/archive/individual/driver
XF86_INPUT_MOUSE_LICENSE = MIT
XF86_INPUT_MOUSE_LICENSE_FILES = COPYING
XF86_INPUT_MOUSE_AUTORECONF = YES

XF86_INPUT_MOUSE_DEPENDENCIES = \
	host-pkgconf \
	xorgproto \
	xserver_xorg-server

# The driver installs its private header via automake's `sdk_HEADERS`, and sdkdir
# expands to an absolute path inside the build machine's sysroot.  "make install"
# then writes to $(TARGET_DIR)/home/<builduser>/..., which Buildroot rejects as an
# install outside the target, even though the .so lands in the right place.  The
# header is of no use to us, so drop the whole `include` subdirectory from the
# install; `src` (mouse_drv.so) and `man` are what this image needs.
define XF86_INPUT_MOUSE_FIX_SOURCES
	sed -i 's/^SUBDIRS = .*/SUBDIRS = src man/' $(@D)/Makefile.am
endef
XF86_INPUT_MOUSE_POST_PATCH_HOOKS += XF86_INPUT_MOUSE_FIX_SOURCES

$(eval $(autotools-package))
