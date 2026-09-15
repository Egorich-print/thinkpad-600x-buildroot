#!/bin/sh
set -e
TARGET_DIR="$1"

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

# Root .xinitrc -> launch CDE (startx runs this).
mkdir -p "$TARGET_DIR/root" "$TARGET_DIR/etc/skel"
cat > "$TARGET_DIR/root/.xinitrc" <<'EOF'
# CDE desktop.
#
# dtwm provides the window manager *and* the CDE Front Panel (WmFP).  In this
# reduced build dtsession never manages to spawn it, so start dtwm here and
# then run Xsession, which sets up the DT search paths / fonts and starts
# ttsession + dtsession.
/usr/dt/bin/dtwm &
exec /usr/dt/bin/Xsession
EOF
cp "$TARGET_DIR/root/.xinitrc" "$TARGET_DIR/etc/skel/.xinitrc"

# Default UTF-8 locale (glibc's built-in C.UTF-8) so btop/others detect UTF-8.
# Guard against duplicate appends on incremental rebuilds.
if ! grep -q 'LC_ALL=C.UTF-8' "$TARGET_DIR/etc/profile" 2>/dev/null; then
    printf 'export LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> "$TARGET_DIR/etc/profile"
fi
exit 0