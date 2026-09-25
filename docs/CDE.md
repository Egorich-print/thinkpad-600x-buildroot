# CDE 2.5.3 — build & runtime integration

CDE is built from source (the actual open-source Common Desktop Environment) as a
custom Buildroot package (`package/cde/`), installed under `/usr/dt`.

## Build method

- **Source**: `cde-2.5.3.tar.gz` from the configured SourceForge URL; it may be
  pre-populated in `$BR2_DL_DIR` (the repository does not contain the tarball).
- **Autotools, not imake.** Flow: `autoreconf` → `./configure` → `make`.
- `./configure --prefix=/usr/dt --disable-docs`.
- OpenMotif 2.3.8 provides `libXm`/`libMrm`/`libUil` (headers in staging via
  `OPENMOTIF_INSTALL_STAGING`).
- **libtirpc** supplies SunRPC after glibc removed it; CDE's configure detects it
  and adds `-DOPT_TIRPC -ltirpc` automatically. `cde.mk` removes CDE's hard-coded
  `-I/usr/include/tirpc`; the sysroot's tirpc headers are used.
- LMDB and libjpeg are build dependencies.

### Cross-compilation source adjustments (`package/cde/cde.mk`)

1. `CDE_FIX_SOURCES` removes CDE's target `tradcpp` build rule. `tradcpp` (GENCPP)
   must execute at build time, so `CDE_BUILD_HOST_TOOLS` builds it natively with
   `$(HOSTCC)` instead of cross-compiling it for i686.
2. `CDE_FIX_SOURCES` removes the programs this reduced image does not build,
   including `dtksh` and the other optional CDE applications listed below. This
   drops the Tcl/ksh target-toolchain requirement and reduces the image size.

### Build-time host tools (probed at configure, not shipped)

`ksh`/`mksh`, `cpp` (system cpp, *not* `gcc -E`), `rpcgen`, `gencat`, `bdftopcf`,
`mkfontdir`, `sessreg`, `xrdb`, `onsgmls` (openSP), `flex`, `bison`, `m4`, `perl`.
See `docs/BUILD.md`.

## Runtime model

`tty1` runs `/usr/sbin/autostart-cde`, which calls `startx` without a client.
`/root/.xinitrc` (created by `post-build.sh`) starts `/usr/dt/bin/dtwm &` and then
execs `/usr/dt/bin/Xsession`. `dtwm` supplies both the window manager and the CDE
Front Panel; CDE's `Xsession` does not start `dtwm` by itself.

`Xsession` is a ksh-syntax script run by target **mksh** and performs this sequence:

1. `dtsearchpath -ksh` exports `DTAPPSEARCHPATH`, `DTDATABASESEARCHPATH`,
   `DTHELPSEARCHPATH`, and `DTICONSEARCHPATH`.
2. `dtappgather` starts the application database setup.
3. `dtdbcache -init` and `ttsession -s` start the ToolTalk/runtime support.
4. `dtsession` is the selected CDE session client. The normal `dtsmcmd` session
   manager is not shipped, so the explicit `dtwm` start above is required.

The autostart environment sets `HOME=/root`, `PATH=/usr/dt/bin:/usr/bin:/bin:/usr/sbin:/sbin`,
`LANG=C.UTF-8`, and `LC_ALL=C.UTF-8`; `Xsession` exports `DT=true` for the session.

The static ToolTalk type database is compiled on the target at boot by
`/etc/init.d/S95tttypes`, not during the Buildroot build. The script runs
`/usr/dt/bin/tt_type_comp` over `/usr/dt/appconfig/tttypes/*.ptype` in a scratch
`/etc/tt/.types.*` directory and publishes `/etc/tt/types.xdr` only when the
result is non-empty. The two `dtinfo` ptypes are absent because `dtinfo` is not
built.

## Fonts

CDE 2.5 uses core X fonts for its classic look (`xset fp+` misc/75dpi/100dpi/Xt
paths) with Xft offered through Xft-enabled OpenMotif. Both `xfonts-*` core fonts
and fontconfig/freetype are installed. `--enable-misc-fixed` is not passed; CDE's
configure default is `no`.

## What's deliberately excluded

The shipped release contains the core desktop and session binaries
`dtwm`, `dtsession`, `ttsession`, `dtstyle`, `dtlogin`, `dtterm`, `dtfile`,
`dtaction`, `dtpad`, and `tt_type_comp`, plus the `Xsession` helpers
`dtsearchpath`, `dtdbcache`, and `dtappgather`. `rpcbind` and `rpc.ttdbserver` are
also present; `dtlogin` is installed but is not used by this image's console flow.

The following binaries are not built/shipped: `dtsmcmd`, `dtappman`, `dtmail`,
`dtcm`, `dtinfo`, `dthelp`, `dthelpview`, `dthelpgen`, `dtmosaic`, and `dtksh`.
`dtmosaic` is absent; the checked-in `usr/dt/appconfig/types/C/ibm.dt` maps HTML
`Open` actions to `/usr/bin/dillo` (and passes the file argument). Regenerate
`release/rootfs.tar` after this overlay change so the shipped tar carries the same
mapping. Consequently, the Applications, Calendar, Mail, and Help front-panel
controls and their related actions do not launch working applications.

`dtlp` is present in the release only as a script with a `dtksh` interpreter, while
`dtksh` is not shipped, so the CDE print action that invokes `dtlp` is not functional.
`dtprintinfo` is present in the release; the inventory does not support describing it
as absent.