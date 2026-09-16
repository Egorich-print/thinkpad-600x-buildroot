/*
 * aquarium - a small ASCII aquarium for the IBM ThinkPad 600X
 *
 * A native, dependency-light replacement for the Perl "asciiquarium" (which
 * needs Perl + Term::Animation + Curses, ~10 MB of runtime).  Written in C,
 * linked against ncurses only, and meant to run on a Pentium III 500 MHz with
 * a NeoMagic 256ZX under CDE:
 *
 *   - no floating point, no SSE/SSE2, no threads, no malloc churn in the loop
 *   - ncurses keeps a virtual screen and only emits the diff, so a full
 *     erase/redraw per frame is cheap even over a slow 2D framebuffer
 *   - updates at ~10 fps by default (adjust with -f)
 *
 * Keys: q / Q / Esc quit, +/- speed, r redraw, arrows do nothing (aquarium).
 *
 * Build: cc -O2 -o aquarium aquarium.c -lncurses
 */

#include <ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

/* ------------------------------------------------------------------ */
/* sprites (drawn left-to-right; flipped automatically when facing left) */

struct sprite {
    const char *const *art;
    int lines;
    int width;          /* longest line */
    int color;          /* ncurses colour pair */
};

static const char *const FISH_SMALL[] = { "><>" };
static const char *const FISH_MED[]   = { "  __ ", "><(*>", "  -- " };
static const char *const FISH_BIG[]   = { "   ____  ", " ><((((*>", "   ----  " };
static const char *const FISH_TALL[]  = { "  /\\/\\ ", "><<  >>", "  \\/\\/ " };
static const char *const JELLY[]      = { "  ___  ", " (   ) ", "  \\|/  ", "   |   " };

#define NSPRITES 5
static const struct sprite SPRITES[NSPRITES] = {
    { FISH_SMALL, 1, 3, 1 },
    { FISH_MED,   3, 6, 2 },
    { FISH_BIG,   3, 9, 3 },
    { FISH_TALL,  3, 7, 4 },
    { JELLY,      4, 7, 5 },
};

/* colour pair ids */
enum { C_WATER = 1, C_FISH1, C_FISH2, C_FISH3, C_FISH4, C_JELLY,
       C_BUBBLE, C_WEED, C_SURF, C_SAND };

#define MAX_FISH   16
#define MAX_BUBBLE 64
#define MAX_WEED   40

struct fish {
    int x, y;           /* body position (fixed point *FIX) */
    int dir;            /* +1 right, -1 left */
    int speed;          /* pixels per frame, fixed point */
    int sp;             /* sprite index */
};

struct bubble {
    int x, y;
    int speed;
    int alive;
};

struct weed {
    int x;
    int height;
    int phase;          /* sway phase*FIX */
};

#define FIX 16
#define SP(c) ((c) * FIX)

static struct fish   fishes[MAX_FISH];
static struct bubble bubbles[MAX_BUBBLE];
static struct weed   weeds[MAX_WEED];
static int           nfish, nweed;
static volatile sig_atomic_t resized = 1;

static int frame_ms = 100;   /* 10 fps */

/* ------------------------------------------------------------------ */

static void on_winch(int sig)
{
    (void)sig;
    resized = 1;
}

static int irand(int n)
{
    return (n > 0) ? (int)((unsigned)rand() % (unsigned)n) : 0;
}

static void sprite_dims(const struct sprite *s, int *w, int *h)
{
    *w = s->width;
    *h = s->lines;
}

/* Draw one sprite at (y,x).  dir=-1 mirrors horizontally (fish swim left). */
static void draw_sprite(int y, int x, const struct sprite *s, int dir, int color)
{
    int l, i, w;
    int rows = LINES, cols = COLS;

    for (l = 0; l < s->lines; l++) {
        const char *line = s->art[l];
        int len = (int)strlen(line);
        int yy = y + l;
        if (yy < 0 || yy >= rows)
            continue;
        for (i = 0; i < len; i++) {
            int c = dir < 0 ? (len - 1 - i) : i;   /* mirror */
            char ch = line[c];
            int xx = x + i;
            if (ch == ' ')
                continue;
            /* wrap horizontally so fish re-enter from the far side */
            w = cols > 0 ? ((xx % cols) + cols) % cols : 0;
            attron(COLOR_PAIR(color));
            mvaddch(yy, w, (chtype)(unsigned char)ch);
            attroff(COLOR_PAIR(color));
        }
    }
}

static void draw_surface(int y)
{
    int i;
    attron(COLOR_PAIR(C_SURF));
    for (i = 0; i < COLS; i++)
        mvaddch(y, i, (i % 2) ? '~' : '^');
    attroff(COLOR_PAIR(C_SURF));
}

static void draw_sand(int y)
{
    int i;
    attron(COLOR_PAIR(C_SAND));
    for (i = 0; i < COLS; i++)
        mvaddch(y, i, (i % 3) ? '.' : 'o');
    attroff(COLOR_PAIR(C_SAND));
}

static void draw_weed(int bottom)
{
    int i;
    attron(COLOR_PAIR(C_WEED));
    for (i = 0; i < nweed; i++) {
        struct weed *w = &weeds[i];
        int len = w->height;
        int j;
        for (j = 0; j < len; j++) {
            int yy = bottom - 1 - j;
            int sway = ((w->phase + j * 3) / FIX) % 3 - 1;  /* -1,0,1 */
            int xx = w->x + (j > 1 ? sway : 0);
            char ch = (j == len - 1) ? '*' : ((j & 1) ? ')' : '(');
            if (yy >= 0 && yy < LINES && xx >= 0 && xx < COLS)
                mvaddch(yy, xx, (chtype)(unsigned char)ch);
        }
    }
    attroff(COLOR_PAIR(C_WEED));
}

static void spawn_fish(int i, int first)
{
    struct fish *f = &fishes[i];
    int sp = irand(NSPRITES);
    int w, h;

    sprite_dims(&SPRITES[sp], &w, &h);
    f->sp = sp;
    /* keep off the very top (surface) and bottom (sand/weed) */
    f->y = 2 + irand(LINES > (h + 6) ? (LINES - h - 6) : 1);
    f->dir = irand(2) ? 1 : -1;
    f->speed = SP(1) + irand(3) * (FIX / 4);          /* 1.00 .. 1.50 px/frame */
    f->x = first ? irand(COLS) : (f->dir > 0 ? -w : COLS + w);
}

static void spawn_bubble(struct bubble *b)
{
    b->alive = 1;
    b->x = irand(COLS);
    b->y = LINES - 2 - irand(3);
    b->speed = 1 + irand(2);
}

static void init_all(void)
{
    int i;

    nfish = MAX_FISH / 2 + irand(MAX_FISH / 2);
    if (nfish < 4)
        nfish = 4;
    for (i = 0; i < nfish; i++)
        spawn_fish(i, 1);

    nweed = 8 + irand(MAX_WEED / 2);
    if (nweed > COLS / 3)
        nweed = COLS / 3;
    for (i = 0; i < nweed; i++) {
        weeds[i].x = 2 + irand(COLS > 4 ? COLS - 4 : 1);
        weeds[i].height = 3 + irand(6);
        weeds[i].phase = irand(FIX * 3);
    }

    memset(bubbles, 0, sizeof(bubbles));
    for (i = 0; i < 6; i++) {
        spawn_bubble(&bubbles[i]);
        bubbles[i].y = irand(LINES);
    }
}

/* ------------------------------------------------------------------ */

static void setup_colors(void)
{
    if (!has_colors())
        return;
    start_color();
    use_default_colors();
    /*                      fg            bg */
    init_pair(C_WATER,  COLOR_WHITE,   COLOR_BLUE);
    init_pair(C_FISH1,  COLOR_YELLOW,  COLOR_BLUE);
    init_pair(C_FISH2,  COLOR_RED,     COLOR_BLUE);
    init_pair(C_FISH3,  COLOR_CYAN,    COLOR_BLUE);
    init_pair(C_FISH4,  COLOR_MAGENTA, COLOR_BLUE);
    init_pair(C_JELLY,  COLOR_WHITE,   COLOR_BLUE);
    init_pair(C_BUBBLE, COLOR_CYAN,    COLOR_BLUE);
    init_pair(C_WEED,   COLOR_GREEN,   COLOR_BLUE);
    init_pair(C_SURF,   COLOR_WHITE,   COLOR_BLUE);
    init_pair(C_SAND,   COLOR_YELLOW,  COLOR_BLUE);

    bkgd(COLOR_PAIR(C_WATER));
}

static void usage(const char *p)
{
    fprintf(stderr,
            "usage: %s [-f fps] [-h]\n"
            "  -f N   frames per second (default 10)\n"
            "  -h     this help\n"
            "keys:  q quit   + faster   - slower\n", p);
}

int main(int argc, char **argv)
{
    int ch, i, running = 1;
    int surface_y = 0, sand_y;
    const char *prog = "aquarium";

    if (argc > 0 && argv[0])
        prog = argv[0];

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
            usage(prog);
            return 0;
        } else if (!strcmp(argv[i], "-f") && i + 1 < argc) {
            int fps = atoi(argv[++i]);
            if (fps >= 1 && fps <= 60)
                frame_ms = 1000 / fps;
        }
    }

    srand((unsigned)time(NULL) ^ (unsigned)getpid());

    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    nodelay(stdscr, TRUE);
    curs_set(0);
    setup_colors();
    signal(SIGWINCH, on_winch);

    while (running) {
        if (resized) {
            endwin();
            refresh();
            clear();
            resized = 0;
            surface_y = 1;
            sand_y = LINES - 1;
            init_all();
        }

        /* --- simulate --- */
        for (i = 0; i < nfish; i++) {
            struct fish *f = &fishes[i];
            int w, h;
            sprite_dims(&SPRITES[f->sp], &w, &h);
            (void)h;
            f->x += f->dir * f->speed;
            if (f->dir > 0 && f->x > SP(COLS))
                spawn_fish(i, 0);
            else if (f->dir < 0 && f->x < -SP(w) - SP(1))
                spawn_fish(i, 0);
        }

        for (i = 0; i < MAX_BUBBLE; i++) {
            struct bubble *b = &bubbles[i];
            if (!b->alive) {
                if (irand(12) == 0)
                    spawn_bubble(b);
                continue;
            }
            b->y -= b->speed;
            if (b->y <= surface_y + 1)
                b->alive = 0;
        }

        for (i = 0; i < nweed; i++)
            weeds[i].phase += 1;

        /* --- draw --- */
        erase();
        draw_surface(surface_y);
        draw_weed(sand_y);
        draw_sand(sand_y);

        for (i = 0; i < MAX_BUBBLE; i++) {
            struct bubble *b = &bubbles[i];
            if (!b->alive)
                continue;
            if (b->y > surface_y && b->y < sand_y) {
                attron(COLOR_PAIR(C_BUBBLE));
                mvaddch(b->y, b->x, (b->speed > 1) ? 'O' : 'o');
                attroff(COLOR_PAIR(C_BUBBLE));
            }
        }

        for (i = 0; i < nfish; i++) {
            struct fish *f = &fishes[i];
            const struct sprite *s = &SPRITES[f->sp];
            draw_sprite(f->y, f->x / FIX, s, f->dir, s->color);
        }

        refresh();

        /* --- input --- */
        switch (ch = getch()) {
        case 'q': case 'Q': case 27:
            running = 0;
            break;
        case '+': case '=':
            if (frame_ms > 16)
                frame_ms -= 10;
            break;
        case '-': case '_':
            if (frame_ms < 500)
                frame_ms += 10;
            break;
        case KEY_RESIZE:
            resized = 1;
            break;
        default:
            break;
        }

        usleep((useconds_t)frame_ms * 1000);
    }

    endwin();
    return 0;
}
