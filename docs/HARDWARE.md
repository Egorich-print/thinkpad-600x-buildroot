# Hardware matrix — IBM ThinkPad 600X 2645-4EU

Target configuration as locked for this image. Treat **64 MB RAM** as a hard
constraint; the baseline design must not assume more.

| Component        | Value / vendor                    | Linux driver (6.18)            | Status        |
|------------------|-----------------------------------|--------------------------------|---------------|
| CPU              | Intel Mobile Pentium III, 500 MHz | `CONFIG_MPENTIUMIII`           | supported     |
| Arch             | x86 32-bit (MMX+SSE, **no SSE2**) | `-march=pentium3`              | supported     |
| RAM              | 64 MB PC100 SDRAM                 | —                              | constraint    |
| Chipset          | Intel 440BX + PIIX4              | `ata_piix` (PATA)              | supported     |
| Storage          | IDE/PATA HDD (~12 GB)            | `CONFIG_ATA_PIIX` + `sd_mod`   | supported     |
| Graphics         | NeoMagic MagicGraph256ZX (4 MB)   | `neofb` + Xorg `neomagic`      | supported     |
| Display          | 1024×768 TFT                      | framebuffer + Xorg             | supported     |
| CardBus/PCMCIA   | 2× CardBus slots                 | `yenta_socket`, `pcmcia`       | supported     |
| Audio            | Crystal CS46xx (AC'97)           | `snd_cs46xx` (+`snd_intel8x0`) | supported     |
| USB 1.1          | UHCI/OHCI                         | `uhci_hcd`, `ohci_hcd`         | supported     |
| Ethernet (PCMCIA)| Xircom/3Com/Intel CardBus NICs   | `xirc2ps_cs`, `3c574_cs`, `e100` etc. | supported |
| Optical          | UltraSlimBay CD/DVD                | `snd`-none; `sr_mod` (SCSI CD) | supported     |
| Floppy (optional)| UltraSlimBay FDD                  | `floppy` (module)              | supported     |
| IrDA             | IrDA port                         | **removed upstream (4.17)**    | unsupported   |
| Power/battery    | APM + ACPI                        | `thinkpad_acpi`, `apm`, ACPI   | supported     |
| Wi-Fi (add-on)   | TL-WN727N (Ralink RT3070/RT5370)  | `rt2800usb` + `rt2870.bin` fw  | supported     |
| Bluetooth (add-on)| Ugreen CM591 (Realtek, 5.3)      | `btusb` + `rtl8761b` firmware  | supported     |

## Notes

- **SSE2 is absent.** This is load-bearing for toolchain/Go choices: Buildroot
  selects `GO386=softfloat` automatically because `BR2_x86_pentium3` does not set
  `BR2_X86_CPU_HAS_SSE2`. Any prebuilt binary compiled for `-march=pentium4` or a
  Go `sse2` baseline will SIGILL here.
- **No USB boot** on the 600X BIOS. Deployment is PATA HDD (or CF-to-IDE adapter),
  via a bootloader written to the MBR.
- **IrDA** cannot be supported by a modern kernel (subsystem deleted). Documented
  as unsupported; no workaround at kernel level.
- Kernel assumptions were validated against the Linux `Kconfig` for 6.18 (driver
  dependency inspection), not forum folklore.