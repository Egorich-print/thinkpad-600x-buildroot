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

$(eval $(autotools-package))
