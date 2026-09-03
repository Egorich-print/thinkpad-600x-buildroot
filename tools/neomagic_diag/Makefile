# Build for the ThinkPad 600X (i686) with the Buildroot toolchain, or native.
#
#   make CROSS_COMPILE=i686-linux-   # cross (path must include the toolchain)
#   make                             # native (same-arch, e.g. on the target)

CROSS_COMPILE ?=
CC      := $(CROSS_COMPILE)gcc
CFLAGS  += -O2 -Wall -Wextra -static

all: neomagic_diag

neomagic_diag: neomagic_diag.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f neomagic_diag

.PHONY: all clean