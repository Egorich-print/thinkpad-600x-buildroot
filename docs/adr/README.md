# ADR index — ThinkPad 600X Buildroot

Architecture Decision Records for this project.  Each ADR is a short,
immutable record (context / decision / consequences); the narrative decision
log with more detail stays in [`../DECISIONS.md`](../DECISIONS.md).

| ADR | Title | Status |
|-----|-------|--------|
| [001](ADR-001-target-toolchain.md) | Target platform & toolchain (i686 Pentium III, glibc) | accepted |
| [002](ADR-002-kernel-612-lts.md) | Kernel base: Linux 6.12 LTS | accepted (supersedes the initial 6.18 choice) |
| [003](ADR-003-init-userspace.md) | Init / userspace: BusyBox init, devtmpfs + mdev (no systemd/udev) | accepted |
| [004](ADR-004-display-x11.md) | Display: Xorg + legacy neomagic DDX, RELRO helper preload | accepted |
| [005](ADR-005-live-boot-initramfs.md) | Live media boot via initramfs + overlayfs (kernel has no `root=LABEL=`) | accepted |
| [006](ADR-006-on-device-installer.md) | On-device HDD installer (sfdisk + extlinux; console= order) | accepted |
| [007](ADR-007-input-drivers.md) | X input without udev: classic mouse/kbd drivers | accepted |
| [008](ADR-008-audio-cs46xx.md) | Audio: Crystal CS46xx with fetched non-free firmware | accepted |
| [009](ADR-009-autologin-cde.md) | Auto-login root and auto-start CDE on the console | accepted |
| [010](ADR-010-rust-infeasible.md) | Rust rejected for PIII (i686 baseline uses SSE2) | accepted |
