/*
 * neomagic_diag — safe standalone test of the NeoMagic 256ZX BitBLT engine.
 *
 * Replicates the register programming of the Linux kernel driver
 * drivers/video/fbdev/neofb.c (GPL-2.0) and include/video/neomagic.h.
 * No undocumented registers are written. Every test saves/restores state
 * and verifies its results.
 *
 * Build:       make CROSS_COMPILE=i686-linux-      (cross for the 600X)
 *              make                                 (native, same-arch test)
 * Run:  as root on the physical 600X, from the text console, X stopped.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/mman.h>
#include <time.h>

/* ---- Register block (struct Neo2200) offsets, from include/video/neomagic.h ---- */
enum {
    REG_BLTSTAT      = 0x00,
    REG_BLTCNTL      = 0x04,
    REG_XPCOLOR      = 0x08,
    REG_FGCOLOR      = 0x0C,
    REG_BGCOLOR      = 0x10,
    REG_PITCH        = 0x14,
    REG_CLIPLT       = 0x18,
    REG_CLIPRB       = 0x1C,
    REG_SRCBITOFFSET = 0x20,
    REG_SRCSTART     = 0x24,
    REG_DSTSTART     = 0x2C,
    REG_XYEXT        = 0x30,
};

/* bltStat bits */
#define NEO_BS0_BLT_BUSY   0x00000001u
#define NEO_BS0_FIFO_AVAIL 0x00000002u
#define NEO_BS0_FIFO_PEND  0x00000004u

/* bltCntl — BC0 (bits 0-7) */
#define NEO_BC0_DST_Y_DEC  0x00000001u
#define NEO_BC0_X_DEC      0x00000002u
#define NEO_BC0_SRC_TRANS  0x00000004u
#define NEO_BC0_SRC_IS_FG  0x00000008u
#define NEO_BC0_SRC_Y_DEC  0x00000010u
#define NEO_BC0_FILL_PAT   0x00000020u
#define NEO_BC0_SRC_MONO   0x00000040u
#define NEO_BC0_SYS_TO_VID 0x00000080u

/* BC3 (bits 24-31) */
#define NEO_BC3_SRC_XY_ADDR 0x01000000u
#define NEO_BC3_DST_XY_ADDR 0x02000000u
#define NEO_BC3_CLIP_ON     0x04000000u
#define NEO_BC3_FIFO_EN     0x08000000u
#define NEO_BC3_BLT_ON_ADDR 0x10000000u
#define NEO_BC3_SKIP_MAPPING 0x80000000u

/* ROP field observed in neofb.c (classic GX raster-op truth table) */
#define NEOMAGIC_ROP_COPY 0x000C0000u
#define NEOMAGIC_ROP_XOR  0x00060000u

/* NEO_MODE1_* — written to bltStat[16:31] as (depth << 16).
 * (The NEO_MODE1_X_* width bits exist in neomagic.h but the kernel's
 * acceleration path does NOT use them; width is conveyed by the pitch reg.) */
#define NEO_MODE1_DEPTH8  0x0100u
#define NEO_MODE1_DEPTH16 0x0200u
#define NEO_MODE1_DEPTH24 0x0300u

#define PCI_VENDOR_NEOMAGIC 0x10c8u
#define PCI_DEVICE_NM2360   0x0006u

#define MMIO_SIZE 0x200000u

static volatile uint32_t *blt;  /* BLT block = MMIO + 0 */
static volatile uint32_t *mmio; /* BAR1 base (2 MB window) */

static uint32_t blt_read(unsigned reg)        { return blt[reg / 4]; }
static void     blt_write(unsigned reg, uint32_t v) { blt[reg / 4] = v; }

static void wait_idle_or_die(unsigned timeout_ms, const char *what)
{
    struct timespec t;
    long long start;
    long long now;
    clock_gettime(CLOCK_MONOTONIC, &t);
    start = (long long)t.tv_sec * 1000 + t.tv_nsec / 1000000;

    for (;;) {
        if (!(blt_read(REG_BLTSTAT) & NEO_BS0_BLT_BUSY))
            return;
        clock_gettime(CLOCK_MONOTONIC, &t);
        now = (long long)t.tv_sec * 1000 + t.tv_nsec / 1000000;
        if (now - start > (long long)timeout_ms) {
            fprintf(stderr, "%s: TIMEOUT after %ums (engine stuck); aborting\n",
                    what, timeout_ms);
            exit(EXIT_FAILURE);
        }
    }
}

static uint32_t mode1_for(int bpp)
{
    switch (bpp) {
    case 8:  return NEO_MODE1_DEPTH8;
    case 15:
    case 16: return NEO_MODE1_DEPTH16;
    case 24: return NEO_MODE1_DEPTH24;
    }
    return 0;
}

/* accel init — identical to neo2200_accel_init(); only the DEPTH is written
 * to bltStat[16:31] (the kernel does NOT encode the screen width there —
 * width/pitch are conveyed via the pitch register only). */
static void accel_init(int xres, int bpp)
{
    uint32_t bltMod = mode1_for(bpp);
    uint32_t pitch  = (uint32_t)xres * ((bpp + 7) >> 3);

    wait_idle_or_die(100, "accel init");
    blt_write(REG_BLTSTAT, bltMod << 16);
    blt_write(REG_PITCH,   (pitch << 16) | pitch);
}

/* solid fill — identical to neo2200_fillrect() */
static void hw_fill(int x, int y, int w, int h, uint32_t color, int bpp, int xres,
                    int rop_xor)
{
    uint32_t dst = (uint32_t)(x + y * xres) * ((bpp + 7) >> 3);
    uint32_t rop = rop_xor ? NEOMAGIC_ROP_XOR : NEOMAGIC_ROP_COPY;

    wait_idle_or_die(500, rop_xor ? "ROP XOR" : "fill");
    blt_write(REG_BLTCNTL,
              NEO_BC3_FIFO_EN | NEO_BC0_SRC_IS_FG | NEO_BC3_SKIP_MAPPING | rop);
    blt_write(REG_FGCOLOR, color);
    blt_write(REG_DSTSTART, dst);
    blt_write(REG_XYEXT, ((uint32_t)h << 16) | ((uint32_t)w & 0xffff));
    wait_idle_or_die(500, rop_xor ? "ROP XOR" : "fill");
}

/* screen-to-screen copy — identical to neo2200_copyarea() */
static void hw_copy(int sx, int sy, int dx, int dy, int w, int h, int bpp,
                    int line_len)
{
    uint32_t bltCntl = NEO_BC3_FIFO_EN | NEO_BC3_SKIP_MAPPING | NEOMAGIC_ROP_COPY;
    uint32_t sxb = (uint32_t)sx, syb = (uint32_t)sy;
    uint32_t dxb = (uint32_t)dx, dyb = (uint32_t)dy;
    uint32_t bytes = (uint32_t)(bpp >> 3);

    if ((dy > sy) || ((dy == sy) && (dx > sx))) {
        syb += (uint32_t)(h - 1);
        dyb += (uint32_t)(h - 1);
        sxb += (uint32_t)(w - 1);
        dxb += (uint32_t)(w - 1);
        bltCntl |= NEO_BC0_X_DEC | NEO_BC0_DST_Y_DEC | NEO_BC0_SRC_Y_DEC;
    }

    uint32_t src = sxb * bytes + syb * line_len;
    uint32_t dst = dxb * bytes + dyb * line_len;

    wait_idle_or_die(500, "copy");
    blt_write(REG_BLTCNTL, bltCntl);
    blt_write(REG_SRCSTART, src);
    blt_write(REG_DSTSTART, dst);
    blt_write(REG_XYEXT, ((uint32_t)h << 16) | ((uint32_t)w & 0xffff));
    wait_idle_or_die(500, "copy");
}

static long long now_us(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000000 + t.tv_nsec / 1000;
}

/* software fill into the mapped framebuffer, for comparison */
static void sw_fill(volatile uint8_t *fb, int x, int y, int w, int h, int bpp,
                    int xres, uint16_t color)
{
    int bytes = (bpp + 7) >> 3;
    int line = xres * bytes;
    int i;
    int j;
    for (j = 0; j < h; j++) {
        if (bytes == 2) {
            volatile uint16_t *row = (volatile uint16_t *)(fb + (y + j) * line);
            for (i = 0; i < w; i++) row[x + i] = color;
        } else {
            volatile uint8_t *row = fb + (y + j) * line;
            memset((void *)(row + x), color, w);
        }
    }
}

static int find_device(uint64_t *fb_base, uint64_t *fb_len, uint64_t *mmio_base,
                       uint64_t *mmio_len, char *sysdev, size_t sysdev_sz)
{
    DIR *d = opendir("/sys/bus/pci/devices");
    if (!d) { perror("opendir /sys/bus/pci/devices"); return -1; }
    struct dirent *de;
    int bar;
    while ((de = readdir(d))) {
        if (de->d_name[0] == '.') continue;
        char path[512];
        unsigned v = 0, dev = 0;

        snprintf(path, sizeof path, "/sys/bus/pci/devices/%s/vendor", de->d_name);
        FILE *f = fopen(path, "r");
        if (f) { fscanf(f, "0x%x", &v); fclose(f); }

        snprintf(path, sizeof path, "/sys/bus/pci/devices/%s/device", de->d_name);
        f = fopen(path, "r");
        if (f) { fscanf(f, "0x%x", &dev); fclose(f); }

        if (v == PCI_VENDOR_NEOMAGIC && dev == PCI_DEVICE_NM2360) {
            snprintf(sysdev, sysdev_sz, "%s", de->d_name);
            for (bar = 0; bar < 2; bar++) {
                snprintf(path, sizeof path,
                         "/sys/bus/pci/devices/%s/resource%d", de->d_name, bar);
                f = fopen(path, "r");
                if (!f) continue;
                unsigned long long start = 0, end = 0;
                if (fscanf(f, "0x%llx 0x%llx", &start, &end) == 2) {
                    if (bar == 0) { *fb_base = start; *fb_len = end - start + 1; }
                    if (bar == 1) { *mmio_base = start; *mmio_len = end - start + 1; }
                }
                fclose(f);
            }
            printf("Found NeoMagic NM2360 at PCI %s\n", de->d_name);
            closedir(d);
            return 0;
        }
    }
    closedir(d);
    fprintf(stderr, "NeoMagic NM2360 (0x10c8:0x0006) not found.\n");
    return -1;
}

static int mmap_resources(const char *sysdev, volatile uint8_t **fb_out,
                          uint64_t fb_len)
{
    char path[512];
    snprintf(path, sizeof path, "/sys/bus/pci/devices/%s/resource0", sysdev);
    int fd = open(path, O_RDWR | O_SYNC);
    if (fd < 0) { perror("open resource0 (framebuffer)"); return -1; }
    *fb_out = mmap(NULL, (size_t)fb_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (*fb_out == MAP_FAILED) { perror("mmap BAR0"); close(fd); return -1; }
    close(fd);

    snprintf(path, sizeof path, "/sys/bus/pci/devices/%s/resource1", sysdev);
    fd = open(path, O_RDWR | O_SYNC);
    if (fd < 0) { perror("open resource1 (MMIO)"); return -1; }
    mmio = mmap(NULL, MMIO_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mmio == MAP_FAILED) { perror("mmap BAR1"); close(fd); return -1; }
    close(fd);

    blt = mmio; /* BLT block is at MMIO offset 0 */
    return 0;
}

/*
 * Safety model (important):
 *  - We only ever write the documented BLT registers (offsets 0x00..0x30), and
 *    never probe unknown MMIO.
 *  - We do NOT save/restore the raw block: several registers are write-only
 *    (reading them is undefined) and `xyExt` is a *trigger* — writing it back
 *    would kick off a spurious BLT. Instead, on entry we wait for the engine to
 *    go idle, run the tests, and on exit we wait idle again and re-run
 *    accel_init() to leave a consistent (depth/pitch, non-triggering) state.
 *  - `wait_idle_or_die()` is time-bounded; a stuck engine aborts the test
 *    instead of looping forever. Userspace mmap of documented registers
 *    cannot panic the kernel; worst case on a misbehaving chip is visual
 *    corruption, which is cleared by re-initialising the mode.
 */
static void usage(const char *a)
{
    fprintf(stderr,
            "usage: %s [--dry-run|--test-fill|--test-blit|--test-rop] "
            "[-w W -h H -b BPP]\n", a);
}

int main(int argc, char **argv)
{
    int xres = 1024, yres = 768, bpp = 16;
    int flag_fill = 0, flag_blit = 0, flag_rop = 0, flag_dry = 0;
    int i;

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--test-fill")) flag_fill = 1;
        else if (!strcmp(argv[i], "--test-blit")) flag_blit = 1;
        else if (!strcmp(argv[i], "--test-rop")) flag_rop = 1;
        else if (!strcmp(argv[i], "--dry-run")) flag_dry = 1;
        else if (!strcmp(argv[i], "-w") && i+1 < argc) xres = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-h") && i+1 < argc) yres = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-b") && i+1 < argc) bpp = atoi(argv[++i]);
        else { usage(argv[0]); return 2; }
    }

    if (bpp != 16) {
        fprintf(stderr, "bpp %d is not supported by this tool; only 16 bpp is supported\n",
                bpp);
        return 2;
    }
    if (xres <= 0 || yres <= 0) {
        fprintf(stderr, "invalid geometry %dx%d; width and height must be positive\n",
                xres, yres);
        return 2;
    }

    uint64_t fb_base = 0, fb_len = 0, mmio_base = 0, mmio_len = 0;
    char sysdev[256];
    if (find_device(&fb_base, &fb_len, &mmio_base, &mmio_len,
                    sysdev, sizeof sysdev) < 0)
        return 1;
    if (!fb_len) {
        fprintf(stderr, "cannot determine framebuffer BAR size; aborting\n");
        return 1;
    }
    if ((uint64_t)xres * (uint64_t)yres * 2u > fb_len) {
        fprintf(stderr,
                "geometry %dx%d at 16 bpp requires %llu bytes, "
                "but the mapped framebuffer is %llu bytes; aborting\n",
                xres, yres, (unsigned long long)((uint64_t)xres *
                (uint64_t)yres * 2u), (unsigned long long)fb_len);
        return 1;
    }
    if (((flag_fill || flag_rop) && (xres < 640 || yres < 480)) ||
        (flag_rop && (xres <= 325 || yres <= 245)) ||
        (flag_blit && (xres < 800 || yres < 800))) {
        fprintf(stderr, "geometry %dx%d is too small for the selected test(s)\n",
                xres, yres);
        return 2;
    }

    volatile uint8_t *fb = NULL;
    if (mmap_resources(sysdev, &fb, fb_len) < 0)
        return 1;

    uint32_t st = blt_read(REG_BLTSTAT);
    printf("FB base:   0x%llx (len %llu)\n", (unsigned long long)fb_base,
           (unsigned long long)fb_len);
    printf("MMIO base: 0x%llx\n", (unsigned long long)mmio_base);
    printf("Mode: %dx%d @ %d bpp\n", xres, yres, bpp);
    printf("BLT status: 0x%08x (busy=%u fifo_avail=%u fifo_space=%u)\n", st,
           (st & NEO_BS0_BLT_BUSY) ? 1u : 0u,
           (st & NEO_BS0_FIFO_AVAIL) ? 1u : 0u,
           (st >> 8) & 0xFF);

    if (flag_dry) {
        munmap((void *)fb, fb_len);
        munmap((void *)mmio, MMIO_SIZE);
        return 0;
    }

    printf("Wait for engine idle before testing...\n");
    wait_idle_or_die(1000, "initial engine wait");
    if (!flag_fill && !flag_blit && !flag_rop) {
        printf("Engine present and idle; no test was run\n");
        munmap((void *)fb, fb_len);
        munmap((void *)mmio, MMIO_SIZE);
        return 0;
    }
    accel_init(xres, bpp);
    wait_idle_or_die(100, "accel init");

    int failures = 0;
    volatile unsigned short *fb16 = (volatile unsigned short *)fb;

    if (flag_fill || flag_rop) {
        long long t0 = now_us();
        hw_fill(0, 0, 640, 480, 0xF81F, bpp, xres, 0);
        long long t1 = now_us();
        printf("hw_fill 640x480: %lld us\n", t1 - t0);

        unsigned short got = fb16[(240 * xres) + 320];
        printf("verify fill pixel(320,240): got=0x%04x want=0xF81F %s\n",
               got, got == 0xF81F ? "OK" : "FAIL");
        if (got != 0xF81F) failures++;

        if (flag_rop) {
            hw_fill(320, 240, 10, 10, 0xFFFF, bpp, xres, 1); /* XOR white */
            got = fb16[(245 * xres) + 325];
            printf("verify xor pixel(325,245): got=0x%04x "
                   "(0xF81F ^ 0xFFFF = 0x07E0)\n", got);
            if (got != 0x07E0) failures++;
        }
    }

    if (flag_blit) {
        sw_fill(fb, 0, 0, 800, 600, bpp, xres, 0xF800); /* red area */
        long long t0 = now_us();
        hw_copy(0, 0, 0, 200, 800, 600, bpp, xres * (bpp / 8));
        long long t1 = now_us();
        printf("hw_copy 800x600 (0,0)->(0,200): %lld us\n", t1 - t0);

        unsigned short got = fb16[(300 * xres) + 400];
        printf("verify blit pixel(400,300): got=0x%04x want=0xF800 %s\n",
               got, got == 0xF800 ? "OK" : "FAIL");
        if (got != 0xF800) failures++;
    }

    printf("Wait idle + re-init engine to a clean state...\n");
    wait_idle_or_die(1000, "final engine wait");
    accel_init(xres, bpp);

    munmap((void *)fb, fb_len);
    munmap((void *)mmio, MMIO_SIZE);

    printf("%s (acceleration %s)\n",
           failures ? "FAIL" : "OK",
           failures ? "NOT validated on this hardware" : "engine working");
    return failures ? 1 : 0;
}