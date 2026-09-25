# Hardware matrix — IBM ThinkPad 600X 2645-4EU

Target configuration as locked for this image. Treat **64 MB RAM** as a hard
constraint; the baseline design must not assume more.

| Component        | Value / vendor                    | Linux driver (6.12.104)        | Status        |
|------------------|-----------------------------------|--------------------------------|---------------|
| CPU              | Intel Mobile Pentium III, 500 MHz | `CONFIG_MPENTIUMIII`           | supported     |
| Arch             | x86 32-bit (MMX+SSE, **no SSE2**) | `-march=pentium3`              | supported     |
| RAM              | 64 MB PC100 SDRAM                 | —                              | constraint    |
| Chipset          | Intel 440BX + PIIX4              | `CONFIG_ATA_PIIX` (PATA)       | supported     |
| Storage          | 40 GB PATA HDD                    | `CONFIG_ATA_PIIX` + `CONFIG_BLK_DEV_SD` | supported |
| Graphics         | NeoMagic MagicGraph256ZX (4 MB)   | `CONFIG_FB_NEOMAGIC` + Xorg `xf86-video-neomagic` | unverified |
| Display          | 1024×768 TFT                      | `CONFIG_FB` + Xorg             | unverified     |
| CardBus/PCMCIA   | 2× CardBus slots                 | `CONFIG_YENTA`, `CONFIG_PCMCIA` | supported     |
| Audio            | Crystal CS46xx (AC'97)           | `CONFIG_SND_CS46XX` + `CONFIG_SND_INTEL8X0` | unverified |
| USB 1.1          | UHCI/OHCI/EHCI                    | `CONFIG_USB_UHCI_HCD`, `CONFIG_USB_OHCI_HCD`, `CONFIG_USB_EHCI_HCD` | supported |
| Ethernet (PCMCIA)| Xircom/3Com/Intel CardBus NICs   | `CONFIG_PCMCIA_XIRC2PS`, `CONFIG_PCMCIA_3C574`, `CONFIG_E100` | supported |
| Optical          | UltraSlimBay CD/DVD                | `CONFIG_BLK_DEV_SR` + `CONFIG_CDROM` | supported |
| Floppy (optional)| UltraSlimBay FDD                  | `CONFIG_BLK_DEV_FD`             | supported     |
| IrDA             | IrDA port                         | **removed upstream (4.17)**    | unsupported   |
| Power/battery    | APM + ACPI                        | `CONFIG_THINKPAD_ACPI`, `CONFIG_APM`, `CONFIG_ACPI` | supported |
| Wi-Fi (USB add-on)| TL-WN727N (MediaTek MT7601U, 148f:7601) | `CONFIG_MT7601U` + MediaTek `mt7601u.bin` | unverified |
| Other Wi-Fi      | Ralink / Realtek / Atheros USB     | `CONFIG_RT2800USB`/`CONFIG_RT2X00` + Ralink firmware, `CONFIG_RTL8XXXU`, `CONFIG_ATH9K_HTC` | configured |

## Notes

- **SSE2 is absent.** This is load-bearing for toolchain/Go choices: Buildroot
  selects `GO386=softfloat` automatically because `BR2_x86_pentium3` does not set
  `BR2_X86_CPU_HAS_SSE2`. Any prebuilt binary compiled for `-march=pentium4` or a
  Go `sse2` baseline will SIGILL here.
- **No USB boot** on the 600X BIOS. Deployment is PATA HDD (or CF-to-IDE adapter),
  via a bootloader written to the MBR.
- **IrDA** cannot be supported by a modern kernel (subsystem deleted). Documented
  as unsupported; no workaround at kernel level.
- This matrix follows the repository's Linux 6.12.104 Kconfig; it is not a hardware
  validation report. NeoMagic framebuffer/DDX/acceleration and CS46xx audio output
  remain unverified on the physical 600X.