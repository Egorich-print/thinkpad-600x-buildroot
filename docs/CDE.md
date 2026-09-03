# CDE 2.5.3 — build & runtime integration

CDE is built from source (the actual open-source Common Desktop Environment) as a
custom Buildroot package (`package/cde/`), installed under `/usr/dt`.

## Build method

- **Source**: `cde-2.5.3.tar.gz` (vendored into `$BR2_DL_DIR`; SourceForge release
  path is unstable so the tarball is carried locally).
- **Autotools, not imake.** Flow: `autoreconf` → `./configure` → `make`.
- `./configure --prefix=/usr/dt --disable-docs`.
- OpenMotif 2.3.8 provides `libXm`/`libMrm`/`libUil` (headers in staging via
  `OPENMOTIF_INSTALL_STAGING`).
- **libtirpc** supplies SunRPC after glibc removed it; CDE's configure detects it
  and adds `-DOPT_TIRPC -ltirpc` automatically. The hard-coded `-I/usr/include/tirpc`
  is harmless in cross-compile (the real headers are found via the sysroot).
- LMDB (DtMmdb/dtinfo), libjpeg are needed.

### Cross-compilation patches (`package/cde/*.patch`)

1. **`0001-tradcpp-host-build.patch`** — CDE's `tradcpp` preprocessor (GENCPP) must
   *execute* at build time; it would otherwise be cross-compiled (i686) and fail to
   run on the aarch64 host. The patch removes the target build rule and
   `cde.mk`'s `CDE_BUILD_HOST_TRADCPP` compiles it natively with `$(HOSTCC)`.
2. **`0002-drop-dtksh.patch`** — removes `dtksh` from `programs/SUBDIRS`, dropping
   the tcl/ksh-TARGET-toolchain requirement and its size.

### Build-time host tools (probed at configure, not shipped)

`ksh`/`mksh`, `cpp` (system cpp, *not* `gcc -E`), `rpcgen`, `gencat`, `bdftopcf`,
`mkfontdir`, `sessreg`, `xrdb`, `onsgmls` (openSP), `flex`, `bison`, `m4`, `perl`.
See `docs/BUILD.md`.

## Runtime model

No `dtlogin`, no `rpcbind`, no `rpc.ttdbserver` — a local session does not need
them. Startup is console login → `startx /usr/dt/bin/Xsession`:

1. `Xsession` (a ksh-syntax script, run by target **mksh**).
2. `dtsearchpath -ksh` exports `DTAPPSEARCHPATH`, `DTDATABASESEARCHPATH`,
   `DTHELPSEARCHPATH`, `DTICONSEARCHPATH`.
3. `ttsession -s` (ToolTalk, standalone).
4. `dtdbcache -init`, `dtappgather`.
5. `dtsession` → restores/starts **dtwm** + front panel + dtfile.

Required env: `LANG=en_US.UTF-8`, `DT=true`, `PATH=/usr/dt/bin:$PATH`,
`LD_LIBRARY_PATH=/usr/dt/lib`.

## Fonts

CDE 2.5 uses core X fonts for its classic look (`xset fp+` misc/75dpi/100dpi/Xt
paths) with Xft offered through Xft-enabled OpenMotif. Both `xfonts-*` core fonts
and fontconfig/freetype are installed. `--enable-misc-fixed` selects the misc-fixed
UI font.

## What's deliberately excluded

- `dtlogin`/`dtgreet` (graphical login greeter — replaces `getty`, not needed).
- `dtksh` (tcl/ksh scripting shell) — size/toolchain cost.
- `dtmail` (full IMAP/POP mail client) — only if a lightweight CDE mail client is
  later required.
- `dtcm` (calendar), `dtinfo` (SGML help browser) — optional; kept out of the
  baseline profile.