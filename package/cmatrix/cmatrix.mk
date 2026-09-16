################################################################################
#
# cmatrix
#
################################################################################

CMATRIX_VERSION = 2.0
CMATRIX_SOURCE = cmatrix-$(CMATRIX_VERSION).tar.gz
CMATRIX_SITE = https://github.com/abishekvashok/cmatrix/archive/refs/tags/v$(CMATRIX_VERSION)
CMATRIX_LICENSE = GPL-3.0+
CMATRIX_LICENSE_FILES = COPYING
CMATRIX_AUTORECONF = YES
CMATRIX_DEPENDENCIES = ncurses

# configure.ac uses AC_CHECK_FILE() on host-ish paths, which errors out when
# cross compiling ("cannot check for file existence when cross compiling").
# Preset the relevant cache variables.
CMATRIX_CONF_ENV = \
	ac_cv_file__usr_lib_kbd_consolefonts=no \
	ac_cv_file__usr_share_consolefonts=no \
	ac_cv_file__usr_lib_X11_fonts_misc=no \
	ac_cv_file__usr_X11R6_lib_X11_fonts_misc=no

$(eval $(autotools-package))
