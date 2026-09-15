################################################################################
#
# xf86-input-keyboard
#
################################################################################

XF86_INPUT_KEYBOARD_VERSION = 1.9.0
XF86_INPUT_KEYBOARD_SOURCE = xf86-input-keyboard-$(XF86_INPUT_KEYBOARD_VERSION).tar.bz2
XF86_INPUT_KEYBOARD_SITE = https://xorg.freedesktop.org/archive/individual/driver
XF86_INPUT_KEYBOARD_LICENSE = MIT
XF86_INPUT_KEYBOARD_LICENSE_FILES = COPYING
XF86_INPUT_KEYBOARD_AUTORECONF = YES

XF86_INPUT_KEYBOARD_DEPENDENCIES = \
	host-pkgconf \
	xorgproto \
	xserver_xorg-server

$(eval $(autotools-package))
