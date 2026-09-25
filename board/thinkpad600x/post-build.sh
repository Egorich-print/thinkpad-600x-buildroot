#!/bin/sh
set -e
TARGET_DIR="${1:-}"
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "post-build.sh: usage: $0 <target-dir>" >&2
    exit 1
fi

# Root profile
[ -d "$TARGET_DIR/root" ] || mkdir -p "$TARGET_DIR/root"
chmod 700 "$TARGET_DIR/root"

# Ensure runtime dirs exist
for d in /var/log /var/run /var/lock /var/lib/misc /run/lock /tmp; do
    mkdir -p "$TARGET_DIR$d"
done

# Drop auto-started bare Xorg: the 600X uses console login -> startx -> CDE.
rm -f "$TARGET_DIR/etc/init.d/S40xorg"

# CDE Xsession is a Korn-shell script with shebang #!/usr/bin/ksh; provide it
# via mksh (Buildroot installs mksh at /bin/mksh).
ln -sf /bin/mksh "$TARGET_DIR/usr/bin/ksh"

# Root .xinitrc -> CDE session (this is what "startx" runs).
mkdir -p "$TARGET_DIR/root" "$TARGET_DIR/etc/skel"
cat > "$TARGET_DIR/root/.xinitrc" <<'EOF'
# CDE desktop.
#
# dtwm provides the window manager *and* the CDE Front Panel (WmFP).  CDE's
# Xsession starts ttsession and dtsession but never dtwm itself (dtsession
# would normally do that through dtsmcmd, which this reduced build omits), so
# start dtwm here and then run Xsession, which sets up the DT search paths and
# fonts around it.
/usr/dt/bin/dtwm &
exec /usr/dt/bin/Xsession
EOF
chmod 755 "$TARGET_DIR/root/.xinitrc"
cp "$TARGET_DIR/root/.xinitrc" "$TARGET_DIR/etc/skel/.xinitrc"
chmod 755 "$TARGET_DIR/etc/skel/.xinitrc"

# Default UTF-8 locale (glibc's built-in C.UTF-8) so btop/others detect UTF-8.
# Guard against duplicate appends on incremental rebuilds.
if ! grep -q 'LC_ALL=C.UTF-8' "$TARGET_DIR/etc/profile" 2>/dev/null; then
    printf 'export LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> "$TARGET_DIR/etc/profile"
fi

# Dillo needs a per-user config directory; otherwise it prints
# "Cannot open file '~/.dillo/dillorc'" on first run.  Seed it for root and
# for new users (skel) from the system dillo config.
if [ -d "$TARGET_DIR/etc/dillo" ]; then
    for d in "$TARGET_DIR/root/.dillo" "$TARGET_DIR/etc/skel/.dillo"; do
        mkdir -p "$d"
        for f in dillorc dpidrc domainrc keysrc hsts_preload; do
            [ -f "$TARGET_DIR/etc/dillo/$f" ] && cp -f "$TARGET_DIR/etc/dillo/$f" "$d/$f"
        done
    done
fi
exit 0