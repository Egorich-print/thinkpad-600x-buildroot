################################################################################
#
# cde — Common Desktop Environment 2.5.3
#
# Autotools tree that must run its own autogen.sh (libtoolize/aclocal/autoconf/
# autoheader/automake). Build-time host tools (ksh/mksh, cpp, rpcgen, gencat,
# bdftopcf, mkfontdir, sessreg, xrdb, onsgmls) are probed at configure time and
# must be present on the build host.
#
################################################################################

CDE_VERSION = 2.5.3
CDE_SOURCE = cde-$(CDE_VERSION).tar.gz
CDE_SITE = https://downloads.sourceforge.net/project/cdesktopenv/src
CDE_LICENSE = LGPL-2.0 (with GPL/MIT parts)
CDE_LICENSE_FILES = COPYING

CDE_INSTALL_STAGING = NO

CDE_DEPENDENCIES = openmotif libtirpc lmdb jpeg mksh \
	xlib_libX11 xlib_libXt xlib_libXext xlib_libXmu xlib_libXpm \
	xlib_libXrender xlib_libXft xlib_libXinerama xlib_libXScrnSaver \
	xlib_libXaw xlib_libXrandr xlib_libXdmcp xlib_libICE xlib_libSM \
	fontconfig freetype linux-pam \
	host-autoconf host-automake host-libtool host-pkgconf \
	host-bison host-flex host-m4 host-gettext

CDE_AUTORECONF = YES
CDE_AUTORECONF_OPTS = -f -i

CDE_CONF_ENV = \
	CFLAGS="$(TARGET_CFLAGS) -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch" \
	CXXFLAGS="$(TARGET_CXXFLAGS) -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch" \
	LDFLAGS="$(TARGET_LDFLAGS) -ltirpc" \
	CPPFLAGS="$(TARGET_CPPFLAGS) -I$(STAGING_DIR)/usr/include/tirpc"

CDE_CONF_OPTS = \
	--prefix=/usr/dt \
	--exec-prefix=/usr/dt \
	--libdir=/usr/dt/lib \
	--disable-docs

# Drop programs we build without (dtksh needs tcl+A&T ksh; dtappbuilder needs
# motif libUil which we do not ship; dtmail/dtcm/dtinfo/dtlogin are optional and
# heavy). Also stop the target build from regenerating tradcpp (a host tool that
# must execute at build time; we build it natively instead).
define CDE_FIX_SOURCES
	sed -i -e '3d' -e '5,8d' $(@D)/util/tradcpp/Makefile.am
	sed -i -e 's/dtmail//g' -e 's/dtksh//g' -e 's/dtcm//g' \
	    -e 's/dtappbuilder//g' -e 's/dtinfo//g' -e 's/localized//g' \
	    -e 's/dthelp//g' -e 's/dtdocbook//g' -e 's/ttsnoop//g' -e 's/tttypes//g' \
	    -e '8s/\\$$//' -e '9d' $(@D)/programs/Makefile.am
	sed -i '/^noinst_PROGRAMS/d' $(@D)/lib/DtTerm/util/Makefile.am
	sed -i '10,13d' $(@D)/programs/fontaliases/Makefile.am
	# chown root (setuid legacy) fails under the non-root Buildroot install;
	# make it non-fatal (the final image owner is set via fakeroot anyway).
	sed -i 's/chown root /-chown root /g' $(@D)/programs/dtterm/Makefile.am \
	    $(@D)/programs/dtsession/Makefile.am \
	    $(@D)/programs/dtsearchpath/dtappg/Makefile.am
	# strip the hard-coded absolute tirpc include (cross gcc rejects it);
	# the real tirpc headers are found via the sysroot include path.
	sed -i -e 's~ -I/usr/include/tirpc~~g' $(@D)/configure.ac
	# drop the Tcl config probes (only dtksh needed Tcl; dtksh is removed).
	sed -i -e '/SC_PATH_TCLCONFIG/d' -e '/SC_LOAD_TCLCONFIG/d' $(@D)/configure.ac
endef
CDE_POST_PATCH_HOOKS += CDE_FIX_SOURCES

# Build the build-time host tools natively (they are otherwise cross-compiled
# and cannot execute on the build host): tradcpp (GENCPP), lineToData, mk_fonts_alias.
define CDE_BUILD_HOST_TOOLS
	$(HOSTCC) $(HOST_CFLAGS) -I$(@D)/util/tradcpp -o $(@D)/util/tradcpp/tradcpp \
		$(@D)/util/tradcpp/array.c $(@D)/util/tradcpp/directive.c \
		$(@D)/util/tradcpp/eval.c $(@D)/util/tradcpp/files.c \
		$(@D)/util/tradcpp/main.c $(@D)/util/tradcpp/macro.c \
		$(@D)/util/tradcpp/output.c $(@D)/util/tradcpp/place.c \
		$(@D)/util/tradcpp/utils.c $(HOST_LDFLAGS)
	$(HOSTCC) $(HOST_CFLAGS) -I$(@D)/lib/DtTerm/TermPrim \
		-o $(@D)/lib/DtTerm/util/lineToData $(@D)/lib/DtTerm/util/lineToData.c $(HOST_LDFLAGS)
	$(HOSTCC) $(HOST_CFLAGS) \
		-o $(@D)/programs/fontaliases/mk_fonts_alias $(@D)/programs/fontaliases/mk_fonts_alias.c $(HOST_LDFLAGS)
endef
CDE_PRE_BUILD_HOOKS += CDE_BUILD_HOST_TOOLS

$(eval $(autotools-package))