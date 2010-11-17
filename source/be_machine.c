/*****************************************************************************/
/*      (c) Copyright - See License.txt       */
/*****************************************************************************/
/*                                                                           */
/*                        C INTERFACE / MACHINE FUNCTION                     */
/*                                                                           */
/*****************************************************************************/

/* It's ok to assume that a machine_func/machine_proc call
   is coming from a standard .e file, as far as arguments being sequences
   versus atoms, but don't assume integers will be in 31-bit
   machine integer format just because of the integer type
   check conversion. We must allow the user to call machine_func/
   machine_proc directly, even if he passes integers in f.p. format */

#define _LARGEFILE64_SOURCE
#include <stdlib.h>

#include "global.h"
#include "alldefs.h"
#include "execute.h"
#include "version.h"
#include "be_runtime.h"
#include "be_rterror.h"
#include "be_main.h"
#include "be_w.h"
#include "be_runtime.h"
#include "be_symtab.h"
#include "be_machine.h"
#include "be_pcre.h"
#include "be_task.h"
#include "be_alloc.h"
#include "be_execute.h"
#include "be_socket.h"

#ifdef ELINUX
#include <malloc.h>
#endif

#ifdef EUNIX

#include <strings.h>
#define stricmp strcasecmp

#ifdef EBSD
#define NAME_MAX 255
#endif

#include <sys/mman.h>

#include <dirent.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <dlfcn.h>
#include <sys/times.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/utsname.h>

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef LOCK_SH
#define LOCK_SH  1 /* shared lock */
#define LOCK_EX  2 /* exclusive lock */
#define LOCK_NB  4 /* don't block when locking */
#define LOCK_UN  8 /* unlock */
#endif

#ifdef ESUNOS
#include <fcntl.h>

int emul_flock(fd, cmd)
	int fd, cmd;
{
	struct flock f;

	memset(&f, 0, sizeof(f));

	if (cmd & LOCK_UN)
		f.l_type = F_UNLCK;
	if (cmd & LOCK_SH)
		f.l_type = F_RDLCK;
	if (cmd & LOCK_EX)
		f.l_type = F_WRLCK;

	return fcntl(fd, (cmd & LOCK_NB) ? F_SETLK : F_SETLKW, &f);
}

#define flock(f,c) emul_flock(f,c)
#endif // ESUNOS

#else // EUNIX

#include <io.h>
#include <direct.h>

#ifdef EWATCOM
#  include <graph.h>
#  include <i86.h>
#endif

#include <dos.h>
#endif  // not EUNIX

#include <time.h>
#include <string.h>

#ifdef EWINDOWS
#include <windows.h>
#endif

#ifdef EMINGW
#include <sys/stat.h>
#include <dirent.h>
#endif

#include <signal.h>


extern char* get_svn_revision(); /* from rev.c */
extern double eustart_time; /* from be_runtime.c */

/*****************/
/* Local defines */
/*****************/
#define C_UNDERLINE    0x0607 /* normal underline cursor */
/* 30-bit magic #s for old Complete & PD Edition binds */
#define COMPLETE_MAGIC ('1' + ('2'<< 8) + ('3' << 16) + ('O' << 24))

/* timer and profile interrupt handler stuff: */
#define TIMERINTR  8
#define MASTER_FREQUENCY 1193181.667

/**********************/
/* Exported variables */
/**********************/
#ifdef EWINDOWS
HINSTANCE winInstance;
#endif

int is_batch = 0; /* batch mode? Should press enter be displayed? 1=no, 0=yes */
char TempBuff[TEMP_SIZE]; /* buffer for error messages */

int c_routine_next = 0;       /* index of next available element */
int c_routine_size = 0;       /* number of c_routine structs allocated */
struct arg_info *c_routine = NULL; /* array of c_routine structs */

int allow_break = TRUE;       /* allow control-c/control-break to kill prog */
int control_c_count = 0;      /* number of control-c/control-break since
								 last call */
int *profile_sample = NULL;
volatile int sample_next = 0;

int line_max; /* current number of text lines on screen */
int col_max;  /* current number of text columns on screen */
#ifdef EUNIX
int consize_ioctl = 0;	/* 1 if line_max or col_max came from ioctl */
#endif

struct videoconfig config;
struct videoconfigEx configEx;

int screen_lin_addr; /* screen segment */
char *crash_msg = NULL;  /* user's crash message or NULL */
volatile int our_clock_ticks = 0; /* number of ticks at current rate */
double clock_frequency = 0.0;    /* current clock interrupt rate. 0.0
									means no interrupt handler installed */
double base_time = 0.0;          /* current base for time() */
double clock_adjust = 0.0;       /* adjustment to clock() value */
unsigned current_fg_color = 7;
unsigned current_bg_color = 0;

extern char **Argv;
extern int Argc;



/********************/
/* Local variables */
/*******************/

char *version_name =
#ifdef EWINDOWS
"WIN32";
#endif

#ifdef EUNIX
"Linux";
#endif


/* cdecl callback - one size fits all */
LRESULT __cdecl cdecl_call_back();

/* stdcall callbacks for each number of args */
LRESULT CALLBACK call_back0();
LRESULT CALLBACK call_back1(unsigned);
LRESULT CALLBACK call_back2(unsigned, unsigned);
LRESULT CALLBACK call_back3(unsigned, unsigned, unsigned);
LRESULT CALLBACK call_back4(unsigned, unsigned, unsigned, unsigned);
LRESULT CALLBACK call_back5(unsigned, unsigned, unsigned, unsigned, unsigned);
LRESULT CALLBACK call_back6(unsigned, unsigned, unsigned, unsigned, unsigned,
							unsigned);
LRESULT CALLBACK call_back7(unsigned, unsigned, unsigned, unsigned, unsigned,
							unsigned, unsigned);
LRESULT CALLBACK call_back8(unsigned, unsigned, unsigned, unsigned, unsigned,
							unsigned, unsigned, unsigned);
LRESULT CALLBACK call_back9(unsigned, unsigned, unsigned, unsigned, unsigned,
							unsigned, unsigned, unsigned, unsigned);

#ifdef EMINGW
#define setenv MySetEnv
static int MySetEnv(const char *name, const char *value, const int overwrite) {
	int len;
	int real_len;
	char *str;

	if (!overwrite && (getenv(name) != NULL))
		return 0;

	len = strlen(name) + 1 + strlen(value);
	str = EMalloc(len + 1); // NOTE: This is deliberately never freed until the application ends.
	if (! str)
		return 0;
	real_len = snprintf(str, len+1, "%s=%s", name, value);
	str[len] = '\0'; // ensure NULL
	len = putenv(str);
	return len;
}
#endif

unsigned long get_pos_int(char *where, object x)
/* return a positive integer value if possible */
{
	if (IS_ATOM_INT(x))
		return INT_VAL(x);
	else if (IS_ATOM(x))
		return (unsigned long)(DBL_PTR(x)->dbl);
	else {
		RTFatal("%s: an integer was expected, not a sequence", where);
	}
}

unsigned IOFF get_pos_off(char *where, object x)
/* return a positive integer value if possible */
{
	if (IS_ATOM_INT(x))
		return (unsigned IOFF) INT_VAL(x);
	else if (IS_ATOM(x))
		return (unsigned IOFF)(DBL_PTR(x)->dbl);
	else {
		RTFatal("%s: an integer was expected, not a sequence", where);
	}
}

IFILE long_iopen(char *name, char *mode)
/* iopen a file. Has support for Windows 95 long filenames */
{
	return iopen(name, mode);
}

int long_open(char *name, int mode)
/* open a file. Has support for Windows 95 long filenames */
{
	return open(name, mode);
}


char *name_ext(char *s)
/* returns a pointer to the 8.3 file name & extension part of a path */
/* Note - forward slash is also legal on DOS/Windows - fix? */
{
	int i;

	i = strlen(s);
	while (i >= 0 && s[i] != '\\' && s[i] != '/') // check for ':' too? ok as used so far
		i--;
	if (i >= 0)
		return s + i + 1;
	else
		return s;
}

long get_int(object x)
/* return an integer value if possible, truncated to 32 bits. */
{
	if (IS_ATOM_INT(x)){
		return x;
	}

	if (IS_ATOM(x)){
		if (DBL_PTR(x)->dbl <= 0.0){
			return (long)(DBL_PTR(x)->dbl);
		}
		else{
			return (unsigned long)(DBL_PTR(x)->dbl);
		}
	}
	RTFatal("an integer was expected, not a sequence");

}

/* Note: side effects could happen from double eval of x */
#define Get_Int(x) (IS_ATOM_INT(x) ? INT_VAL(x) : get_int(x))

#ifdef EUNIX
struct termios savetty; // initial tty state for STDIN
struct termios newtty;  // current tty state for STDIN

void echo_wait()
// sets tty to wait for input and echo keystrokes
{
	newtty.c_lflag |= ICANON;
	newtty.c_lflag |= ECHO;   // turns on echo
	newtty.c_cc[VMIN] = 1;    // wait for input
	tcsetattr(STDIN_FILENO, TCSANOW, &newtty);
}

void noecho(int wait)
// sets tty to not echo keystrokes, and either wait for input or not
{
	newtty.c_lflag &= ~ICANON;
	newtty.c_lflag &= ~ECHO;   // turns off echo
	newtty.c_cc[VMIN] = wait;  // wait for input, if wait = 1
	tcsetattr(STDIN_FILENO, TCSANOW, &newtty);
}
#endif

void InitGraphics()
/* initialize for graphics */
{
#ifdef EUNIX
	// save initial tty state
	tcgetattr(STDIN_FILENO, &savetty);

	// set up tty for no echo
	newtty = savetty;
	newtty.c_cc[VTIME] = 0;
	//noecho(0); // necessary?
#endif

	NewConfig(FALSE);

}

void EndGraphics()
{
#ifdef EWINDOWS
	SetConsoleMode(console_output,
					ENABLE_PROCESSED_OUTPUT | ENABLE_WRAP_AT_EOL_OUTPUT); // back to normal
#endif
#ifdef EUNIX
	tcsetattr(STDIN_FILENO, TCSANOW, &savetty);
#endif
}

void not_supported(char *feature)
/* Report that a feature isn't supported on this platform */
{
	RTFatal("%s is not supported in Euphoria for %s", feature, version_name);
}


#define MODE_19_BASE ((unsigned)0xA0000)
#define MODE_19_WIDTH 320
#define MODE_19_HEIGHT 200


void RestoreConfig()
/* put graphics mode etc back the way it is supposed to be
   e.g. after system call */
{
}

void NewConfig(int raise_console)
/* note new video configuration - this doesn't work
   after a system call that changes modes - could be out of sync */
{
#ifdef EWINDOWS
	CONSOLE_SCREEN_BUFFER_INFO info;
	if (raise_console) {
		// properly initializes the console when running in eui mode
		show_console();

		GetConsoleScreenBufferInfo(console_output, &info);
 		configEx.screenrows = info.srWindow.Bottom - info.srWindow.Top + 1;
 		configEx.screencols = info.srWindow.Right - info.srWindow.Left + 1;
		line_max = info.dwSize.Y;
		col_max = info.dwSize.X;
	} else {
		// don't care on startup - this will be initialized later.
		line_max = 25;
		col_max = 80;
		configEx.screenrows = 25;
		configEx.screencols = 80;
	}

	config.numtextrows = line_max;
	config.numtextcols = col_max;

	config.mode = 3;
	config.monitor = _COLOR;
	config.numcolors = 32;
	config.numxpixels = 0;
	config.numypixels = 0;
	config.numvideopages = 1;
#endif

#ifdef EUNIX
	char *env_lines;
	char *env_cols;
	int x;
	struct winsize ws;
	UNUSED(raise_console);

	config.mode = 3;
	config.numxpixels = 0;
	config.numypixels = 0;
	config.numvideopages = 1;
	line_max = 0;
	col_max = 0;
	consize_ioctl = 0;

	env_lines = getenv("LINES");
	if (env_lines != NULL) {
		x = atoi(env_lines);
		if (x > 0 && x < 9999) {
			// value looks reasonable
			line_max = x;
		}
	}
	env_cols = getenv("COLUMNS");
	if (env_cols != NULL) {
		x = atoi(env_cols);
		if (x > 0 && x < 99999) {
			// value looks reasonable
			col_max = x;
		}
	}

	if ( ((col_max == 0) || (line_max == 0)) && !ioctl(STDIN_FILENO, TIOCGWINSZ, &ws))  {
		line_max = ws.ws_row;
		col_max = ws.ws_col;
		consize_ioctl = 1;
	}

	if (line_max < 5 || line_max > 9999 ||
		col_max < 10 || col_max > 99999) {
		// something is wrong - use default pessimistic values
		line_max = 24;  // default value
		col_max = 80;   // default value
		consize_ioctl = 0;
	}

	if (line_max > MAX_LINES)
		line_max = MAX_LINES;
	if (col_max > MAX_COLS)
		col_max = MAX_COLS;

	config.monitor = _COLOR;
	config.numcolors = 16;
	config.numtextrows = line_max;
	config.numtextcols = col_max;
	configEx.screenrows = line_max;
	configEx.screencols = col_max;
#endif

	screen_col = 1;
	if (config.monitor == _MONO ||
		config.monitor == _ANALOGMONO ||
		config.mode == 7)
		screen_lin_addr = (0xb000 << 4);
	else
		screen_lin_addr = (0xb800 << 4);
}

static object Graphics_Mode(object x)
/* x is the graphics mode */
{
	UNUSED(x);
#if defined(EWINDOWS)
	NewConfig(TRUE);
#endif
	return ATOM_0;
}

static object Video_config()
/* video_config built-in */
{
	object_ptr obj_ptr;
	s1_ptr result;
#if defined(EWINDOWS)
	NewConfig(TRUE); // Windows size might have changed since last call.
#endif
	result = NewS1((long)10);
	obj_ptr = result->base;

	obj_ptr[1] = (config.monitor != _MONO) &&
				 (config.monitor != _ANALOGMONO);
	obj_ptr[2] = config.mode;
	obj_ptr[3] = config.numtextrows;
	obj_ptr[4] = config.numtextcols;
	obj_ptr[5] = config.numxpixels;
	obj_ptr[6] = config.numypixels;
	obj_ptr[7] = config.numcolors;
	obj_ptr[8] = config.numvideopages;
	obj_ptr[9] = configEx.screenrows;
	obj_ptr[10] = configEx.screencols;
	return MAKE_SEQ(result);
}

static object Cursor(object x)
/* set style of cursor */
{
	short style;
#ifdef EWINDOWS
	CONSOLE_CURSOR_INFO c;
#endif
	style = get_int(x);
#ifdef EWINDOWS
	c.dwSize = (style == 0x0607) ? 12 :
			   (style == 0x0507) ? 25 :
			   (style == 0x0407) ? 50 :
								  100;
	c.bVisible = (style != 0x02000);
	SetConsoleCursorInfo(console_output, &c);
#endif
#ifdef EUNIX
	// leaveok(stdscr, style != 0x02000); doesn't work very well
#endif
	return ATOM_1;
}

static object TextRows(object x)
/* text_rows built-in */
{

#ifdef EWINDOWS
	COORD newsize;
	int new_rows;

	new_rows = get_int(x);
	NewConfig(TRUE);
	newsize.X = config.numtextcols;
	newsize.Y = new_rows;
	SetConsoleScreenBufferSize(console_output, newsize);
	NewConfig(TRUE);
#else
	UNUSED(x);
#endif
	NewConfig(TRUE);
	return MAKE_INT(line_max);
}

object Wrap(object x)
/* set line wrap mode */
{
	wrap_around = get_int(x);
#if defined(EWINDOWS)
	show_console();
#endif
	return ATOM_1;
}

#ifdef EUNIX
static char *bl20 = "                    ";

void blank_lines(int line, int n)
// Write n blank lines at the specified line (origin 0).
// The cursor is moved.
{
	int b;
	int j;

	for (j = 1; j <= n; j++) {
		b = config.numtextcols;
		SetPosition(++line, 1);
		while (b >= 20) {
			iputs(bl20, stdout); // 20 blanks
			update_screen_string(bl20);
			screen_col += 20;
			b -= 20;
		}
		while (b >= 1) {
			iputs(" ", stdout); // 1 blank
			update_screen_string(" ");
			screen_col += 1;
			b -= 1;
		}
	}
	if (n)
	  iflush(stdout);
}
#endif

void do_scroll(int top, int bottom, int amount)
// scroll the screen from top line to bottom line by amount
// amount is positive => text moves up
{

#ifdef EWINDOWS
	SMALL_RECT src, clip;
	COORD dest;
	CHAR_INFO fill_char;
	CONSOLE_SCREEN_BUFFER_INFO info;

	show_console();
	GetConsoleScreenBufferInfo(console_output, &info);
	src.Left = 0;
//	src.Right = info.dwMaximumWindowSize.X - 1;
	src.Right = info.dwSize.X - 1;
	src.Top = top - 1;
	src.Bottom = bottom - 1;
	clip = src;
	dest.X = 0;
	dest.Y = src.Top - amount; // for now
//	GetConsoleScreenBufferInfo(console_output, &info);
	fill_char.Char.AsciiChar = ' ';
	fill_char.Attributes = info.wAttributes;
	if (abs(amount) > abs(bottom - top)) {
//		EClearLines(top, bottom, info.dwMaximumWindowSize.X - 1, fill_char.Attributes);
		EClearLines(top, bottom, info.dwSize.X - 1, fill_char.Attributes);
	}
	else {
		ScrollConsoleScreenBuffer(console_output,
							  &src,
							  &clip,
							  dest,
							  &fill_char);
	}
#endif

#ifdef EUNIX
	short c1;
	short r1;
	int t;
	int i;
	int j;
	int b;
	int prev_t;
	int prev_b;
	int fg;
	int newl;
	int bg;
	char c;
	char linebuff[200 + 1];
	int lbi;
	// save the current position
	r1 = screen_line;
	c1 = screen_col;
	fg = current_fg_color;
	bg = current_bg_color;
	prev_t = -1;
	prev_b = -1;
	if (abs(amount) > abs(bottom - top)) {
		// clear the window
		blank_lines(top-1, bottom-top+1);
	}
	else if (amount > 0) {
		// copy some lines up
		for (i = top; i <= bottom - amount; i++) {
			SetPosition(i, 1);
			newl = i - 1;
			lbi = 0;
			for (j = 0; j < col_max; j++) {
				screen_image[newl][j] = screen_image[newl+amount][j];
				t = screen_image[newl][j].fg_color;
				b = screen_image[newl][j].bg_color;
				if (t != prev_t) {
					if (lbi) {
					  linebuff[lbi] = 0;
					  iputs(linebuff , stdout);
					  iflush(stdout);
					  lbi = 0;
					}
					SetTColor(t);
					prev_t = t;
				}
				if (b != prev_b) {
					if (lbi) {
					  linebuff[lbi] = 0;
					  iputs(linebuff , stdout);
					  iflush(stdout);
					  lbi = 0;
					}
					SetBColor(b);
					prev_b = b;
				}
				c = screen_image[newl][j].ascii;
				if (c == 0)
				  c = ' ';
                                linebuff[lbi] = c;
				lbi++;
			}
			linebuff[lbi] = 0;
			iputs(linebuff , stdout);
			iflush(stdout);
		}
		// put blank lines at bottom
		SetBColor(bg);
		blank_lines(bottom-amount, amount);
		iflush(stdout);
	}
	else if (amount < 0) {
		// copy some lines down
		for (i = bottom; i >= top-amount; i--) {
			SetPosition(i, 1);
			newl = i - 1;
			lbi = 0;
			for (j = 0; j < col_max; j++) {
				screen_image[newl][j] = screen_image[newl+amount][j];
				t = screen_image[newl][j].fg_color;
				b = screen_image[newl][j].bg_color;
				if (t != prev_t) {
					if (lbi) {
					  linebuff[lbi] = 0;
					  iputs(linebuff , stdout);
					  iflush(stdout);
					  lbi = 0;
					}
					SetTColor(t);
					prev_t = t;
				}
				if (b != prev_b) {
					if (lbi) {
					  linebuff[lbi] = 0;
					  iputs(linebuff , stdout);
					  iflush(stdout);
					  lbi = 0;
					}
					SetBColor(b);
					prev_b = b;
				}
				c = screen_image[newl][j].ascii;
				if (c == 0)
				  c = ' ';
                                linebuff[lbi] = c;
				lbi++;
			}
			linebuff[lbi] = 0;
			iputs(linebuff , stdout);
			iflush(stdout);
		}
		// put blanks lines at top
		SetBColor(bg);
		blank_lines(top-1, -amount);
		iflush(stdout);
	}
	// restore the current position
	SetPosition(r1, c1);
	SetTColor(fg); // bg will be restored already
	current_fg_color = fg;
	current_bg_color = bg;
#endif

}

static object Scroll(object x)
{
	int amount, top, bottom;


	x = (object)SEQ_PTR(x);
	amount = get_int(*(((s1_ptr)x)->base+1));
	top =    get_int(*(((s1_ptr)x)->base+2));
	// top is higher on the screen, i.e. with a lower line number
	bottom = get_int(*(((s1_ptr)x)->base+3));
	do_scroll(top, bottom, amount);
	return ATOM_1;
}

object SetTColor(object x)
/* SET TEXT COLOR */
{
	short c;
#if defined(EUNIX)
#define STC_buflen (20)
	char buff[STC_buflen];
	int bold;
#endif

#ifdef EWINDOWS
	WORD attribute;
	CONSOLE_SCREEN_BUFFER_INFO con_info;
#endif

	c = get_int(x);
#if defined(EWINDOWS)
	show_console();
	GetConsoleScreenBufferInfo(console_output, &con_info);
	attribute = (c & 0x0f) | (con_info.wAttributes & 0xf0);
	SetConsoleTextAttribute(console_output, attribute);
#endif

#ifdef EUNIX
	current_fg_color = c & 15;
	if (current_fg_color > 7) {
		bold = 1; // BOLD ON (BRIGHT)
		c = 30 + (current_fg_color & 7);
	}
	else {
		bold = 22; // BOLD OFF
		c = 30 + current_fg_color;
	}
	snprintf(buff, STC_buflen, "\E[%d;%dm", bold, c);
	iputs(buff, stdout);
	iflush(stdout);
#endif

	return ATOM_1;
}

object SetBColor(object x)
/* SET BACKGROUND COLOR */
{
	int c;
#if defined(EUNIX)
#define SBC_buflen (20)
	char buff[SBC_buflen];
#endif

#ifdef EWINDOWS
	WORD attribute;
	CONSOLE_SCREEN_BUFFER_INFO con_info;
#endif

	c = get_int(x);
#if defined(EWINDOWS)
	show_console();
	GetConsoleScreenBufferInfo(console_output, &con_info);
	attribute = ((c & 0x0f) << 4) | (con_info.wAttributes & 0x0f);
	SetConsoleTextAttribute(console_output, attribute);
#endif

#ifdef EUNIX
	current_bg_color = c & 15;
	if (current_bg_color > 7) {
		c = 100 + (current_bg_color & 7);
	}
	else {
		c = 40 + current_bg_color;
	}
	snprintf(buff, SBC_buflen, "\E[%dm", c);
	iputs(buff, stdout);
	iflush(stdout);
#endif

	return ATOM_1;
}


static object user_allocate(object x)
/* x is number of bytes to allocate */
{
	int nbytes;
	char *addr;
#ifdef EBSD
	unsigned first, last, gp1;
#endif

	nbytes = get_int(x);
#ifdef EBSD
	addr = EMalloc(nbytes);
	// make it executable
	gp1 = pagesize-1;
	first = (unsigned)addr & (~gp1); // start of page
	last = (unsigned)addr+nbytes-1; // last address
	last = last | gp1; // end of page
	mprotect((void *)first, last - first + 1,
			 PROT_READ+PROT_WRITE+PROT_EXEC);
#elif defined(ELINUX)
	addr = (char*) memalign( pagesize, nbytes );
	mprotect( addr, nbytes, PROT_EXEC | PROT_READ | PROT_WRITE );
#else
	addr = EMalloc(nbytes);
#endif

	return MAKE_UINT(addr);
}

static object Where(object x)
/* x is the file number. return current byte position */
{
	int file_no;
	IOFF result;
	IFILE f;

	file_no = CheckFileNumber(x);
	if (user_file[file_no].mode == EF_CLOSED)
		RTFatal("file must be open for where()");
	f = user_file[file_no].fptr;
#ifdef EWATCOM
	if (user_file[file_no].mode & EF_APPEND)
		iflush(f);  // This fixes a bug in Watcom 10.6 that is fixed in 11.0
#endif
	result = itell(f);
	if (result == (IOFF)-1)
	{
		RTFatal("where() failed on this file");
	}
	if (result > (IOFF)MAXINT || result < (IOFF)MININT)
		result = NewDouble((double)result);  // maximum 2 billion
#if defined(ELINUX) || defined(EWATCOM)
	else
		result = iitell(f); // for better accuracy
#endif
	return result;
}

static object Seek(object x)
/* x is {file number, new position} */
{
	int file_no;
	IOFF pos, result;
	IFILE f;
	object x1, x2;

	x = (object)SEQ_PTR(x);
	x1 = *(((s1_ptr)x)->base+1);
	x2 = *(((s1_ptr)x)->base+2);
	file_no = CheckFileNumber(x1);
	if (user_file[file_no].mode == EF_CLOSED) {
		return ATOM_1; // "file must be open for seek()"
	}
	
	f = user_file[file_no].fptr;
	pos = get_pos_off("seek", x2);
	if (pos == -1)
#if defined(EMINGW)
		result = iseek(f, 0L, SEEK_END);
#else
		result = iiseek(f, 0L, SEEK_END);
#endif
#if defined(ELINUX) || defined(EWATCOM)
	else if (!(pos > (IOFF)MAXINT || pos < (IOFF)MININT))
		result = iiseek(f, pos, SEEK_SET);
#endif
	else
		result = iseek(f, pos, SEEK_SET);
	
	return (!result ? ATOM_0 : ATOM_1);
}

// 2 implementations of dir()


#ifdef EWINDOWS
	// 1 of 2: Windows
static object Dir(object x)
/* x is the name of a directory or file */
{
	char path[MAX_FILE_NAME+1];
	s1_ptr result, row;
	object_ptr obj_ptr;
	char attrs[16];
	char *next_attr;
	char *fp_buf;
	WIN32_FIND_DATA file_info;
	HANDLE next_file;
	SYSTEMTIME file_time;
	SYSTEMTIME local_time;
	int findres;
	int has_wildcards;
/*
typedef struct _WIN32_FIND_DATA {
  DWORD    dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD    nFileSizeHigh;
  DWORD    nFileSizeLow;
  DWORD    dwReserved0;
  DWORD    dwReserved1;
  TCHAR    cFileName[MAX_PATH];
  TCHAR    cAlternateFileName[14];
} WIN32_FIND_DATA, *PWIN32_FIND_DATA, *LPWIN32_FIND_DATA;

typedef struct _BY_HANDLE_FILE_INFORMATION {
  DWORD    dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD    dwVolumeSerialNumber;
  DWORD    nFileSizeHigh;
  DWORD    nFileSizeLow;
  DWORD    nNumberOfLinks;
  DWORD    nFileIndexHigh;
  DWORD    nFileIndexLow;
} BY_HANDLE_FILE_INFORMATION, *PBY_HANDLE_FILE_INFORMATION;

typedef struct _SYSTEMTIME {
  WORD wYear;
  WORD wMonth;
  WORD wDayOfWeek;
  WORD wDay;
  WORD wHour;
  WORD wMinute;
  WORD wSecond;
  WORD wMilliseconds;
} SYSTEMTIME, *PSYSTEMTIME;

*/
	/* x will be sequence if called via dir() */

	if (SEQ_PTR(x)->length > MAX_FILE_NAME)
		RTFatal("name for dir() is too long");

	MakeCString(path, x, MAX_FILE_NAME + 8); // Add a little extra space too.

	// Convert any unix delims to Windows delim
	has_wildcards = 0;
	fp_buf = path;
	while (*fp_buf)
	{
		if (*fp_buf == '/')
		{
			*fp_buf = '\\';
		}
		else
		{
			if (*fp_buf == '*' || *fp_buf == '?')
			{
				has_wildcards = 1;
			}
		}
		fp_buf++;
	}

	// Trim off trailing whitespace
	// N.B. 'fp_buf' should now be pointing to the null terminator at this point.
	fp_buf--;
	while (fp_buf != path)
	{
		if (*fp_buf == ' ' || *fp_buf == '\t')
		{
			fp_buf--;
		}
		else
		{
			break;
		}
	}
	fp_buf++;
	*fp_buf = '\0'; // Mark end of C string

	if (fp_buf == path)
	{
		// Empty path so assume current directory
		strcpy(path, ".\\*");
		has_wildcards = 1;
	}
	else
	{
		if (*(fp_buf-1) == '\\')
		{
			// Special case. If path has trailing slash, append an asterisk.
			*fp_buf = '*';
			has_wildcards = 1;
			fp_buf++;
			*fp_buf = '\0';
		}
	}

	fp_buf = NULL;
	next_file = FindFirstFile( path, &file_info);
	if ( (next_file == INVALID_HANDLE_VALUE) ||
		((file_info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
			(has_wildcards == 0)) )
	{
		// Inital path could be a 'share' folder or
		// a directory when no wildcards were used,
		// so assume the caller wants to see inside the directory.
		FindClose(next_file);
		strcat(path, "\\*");
		has_wildcards = 1;
		next_file = FindFirstFile( path, &file_info);
		if (next_file == INVALID_HANDLE_VALUE)
		{
			return ATOM_M1; /* couldn't open directory (or file) */
		}
	}


	/* start with empty sequence as result */
	result = (s1_ptr)NewString("");

	findres = ~0;
	while (findres != 0) {

		/* create a length-11 sequence */
		row = NewS1((long)11);
		obj_ptr = row->base;
		obj_ptr[1] = NewString(file_info.cFileName);

		next_attr = &attrs[0];

		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_READONLY)
			*next_attr++ = 'r';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN)
			*next_attr++ = 'h';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM)
			*next_attr++ = 's';
// 		if (direntp->d_attr & _A_VOLID)
// 			*next_attr++ = 'v';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
			*next_attr++ = 'd';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE)
			*next_attr++ = 'a';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_COMPRESSED)
			*next_attr++ = 'c';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED)
			*next_attr++ = 'e';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)
			*next_attr++ = 'N';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_DEVICE)
			*next_attr++ = 'D';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_OFFLINE)
			*next_attr++ = 'O';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)
			*next_attr++ = 'R';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_SPARSE_FILE)
			*next_attr++ = 'S';
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY)
			*next_attr++ = 'T';
		#ifndef FILE_ATTRIBUTE_VIRTUAL
		    // This Windows constant is not defined in some older compilers.
            #define FILE_ATTRIBUTE_VIRTUAL  (0x00010000L)
		#endif
		if (file_info.dwFileAttributes & FILE_ATTRIBUTE_VIRTUAL)
				*next_attr++ = 'V';

		*next_attr = '\0';
		obj_ptr[2] = NewString(attrs);

		if (file_info.nFileSizeHigh == 0)
		{
			if (file_info.nFileSizeLow > MAXINT) {
				obj_ptr[3] = NewDouble((double)file_info.nFileSizeLow);
			} else {
				obj_ptr[3] = MAKE_INT((int)file_info.nFileSizeLow);
			}
		}
		else
		{
			obj_ptr[3] = NewDouble((double)file_info.nFileSizeHigh * ((double)(MAXDWORD) + 1.0) +
			                       (double)file_info.nFileSizeLow);
		}

		FileTimeToSystemTime( &file_info.ftLastWriteTime, &file_time);
		SystemTimeToTzSpecificLocalTime(NULL, &file_time, &local_time);

		obj_ptr[4] = local_time.wYear;
		obj_ptr[5] = local_time.wMonth;
		obj_ptr[6] = local_time.wDay;

		obj_ptr[7] = local_time.wHour;
		obj_ptr[8] = local_time.wMinute;
		obj_ptr[9] = local_time.wSecond;
		obj_ptr[10]= local_time.wMilliseconds;

 		if (file_info.cAlternateFileName[0] != '\0')
 		{
			obj_ptr[11]= NewString(file_info.cAlternateFileName);
 		}
 		else
 		{
			obj_ptr[11]= 0;
		}

		/* append row to overall result (ref count 1)*/
		Append((object_ptr)&result, (object)result, MAKE_SEQ(row));

		findres = FindNextFile( next_file, &file_info);
	}
	FindClose(next_file);

	return (object)result;
}
#endif

#if defined(EUNIX)
	// 2 of 2: Unix style with stat()
static object Dir(object x)
/* x is the name of a directory or file */
{
	char path[MAX_FILE_NAME+1];
	s1_ptr result, row;
	struct dirent *direntp;
	object_ptr obj_ptr, temp;

	DIR *dirp;
	int r;
#ifdef ELINUX
	struct stat64 stbuf;
#else
	struct stat stbuf;
#endif
	struct tm *date_time;
// TODO MinGW uses the Windows API version of Dir(), not the stat() version
#if defined(EMINGW)
#define full_name_size (MAX_FILE_NAME + 257)
#else
#define full_name_size (MAX_FILE_NAME + NAME_MAX + 1)
#endif

	char full_name[full_name_size + 1];
	/* x will be sequence if called via dir() */

	if (SEQ_PTR(x)->length > MAX_FILE_NAME)
		RTFatal("name for dir() is too long");

	MakeCString(path, x, MAX_FILE_NAME+1);

	dirp = opendir(path); // on Linux, path *must* be a directory

	if (dirp == NULL) {
#ifdef ELINUX
		r = stat64(path, &stbuf);  // should be a file
#else
		r = stat(path, &stbuf);  // should be a file
#endif
		if (r == -1)
			return ATOM_M1;
	}

	/* start with empty sequence as result */
	result = (s1_ptr)NewString("");

	for (;;) {
		if (dirp != NULL) {
			direntp = readdir(dirp);
			if (direntp == NULL)
				break; /* end of list */
		}

		/* create a length-11 sequence */
		row = NewS1((long)11);
		obj_ptr = row->base;
		if (dirp == NULL)
			obj_ptr[1] = NewString(name_ext(path)); // just the name
		else
			obj_ptr[1] = NewString(direntp->d_name);
		obj_ptr[2] = NewString("");
		temp = &obj_ptr[2];

		// opendir/readdir with stat method
		if (dirp != NULL) {
			snprintf(full_name, full_name_size, "%s/%s", path, direntp->d_name);
			full_name[full_name_size] = 0; // ensure NULL
#ifdef ELINUX
			r = stat64(full_name, &stbuf);
#else
			r = stat(full_name, &stbuf);
#endif
		}
		if (r == -1) {
			obj_ptr[3] = 0;
			obj_ptr[4] = 0;
			obj_ptr[5] = 0;
			obj_ptr[6] = 0;
			obj_ptr[7] = 0;
			obj_ptr[8] = 0;
			obj_ptr[9] = 0;
		}
		else {
			if ((stbuf.st_mode & S_IFMT) == S_IFDIR)
				Append(temp, *temp, MAKE_INT('d'));

			if( stbuf.st_size > MAXINT ){
				obj_ptr[3] = NewDouble( (double) stbuf.st_size );
			}
			else{
				obj_ptr[3] = (object) stbuf.st_size;
			}

			date_time = localtime(&stbuf.st_mtime);
			obj_ptr[4] = date_time->tm_year+1900;
			obj_ptr[5] = date_time->tm_mon+1;
			obj_ptr[6] = date_time->tm_mday;
			obj_ptr[7] = date_time->tm_hour;
			obj_ptr[8] = date_time->tm_min;
			obj_ptr[9] = date_time->tm_sec;

			obj_ptr[10]= 0; // Millisecs not implemented
			obj_ptr[11]= 0; // Alternate name not used.
		}

		/* append row to overall result (ref count 1)*/
		Append((object_ptr)&result, (object)result, MAKE_SEQ(row));
		if (dirp == NULL)
			return (object)result;
	}
	closedir(dirp);

	return (object)result;
}
#endif

static object CurrentDir()
/* return name of current directory */
{
	char *cwd;
	object result;
	char *buff;

	buff = EMalloc(MAX_FILE_NAME+1);
	cwd = getcwd(buff, MAX_FILE_NAME+1);
	if (cwd == NULL)
		RTFatal("current directory not available");
	else {
		result = NewString(cwd);
		EFree(buff);
	}
	return result;
}

static object PutScreenChar(object x)
/* x is {line, col, {c1, a1, c2, a2, ...}} */
{
	unsigned attr, len;
	unsigned line, column;
	unsigned fg, bg;
	s1_ptr args;
	object_ptr p;
#ifdef EUNIX
	unsigned c;
	char s1[2];
	int save_line, save_col;
#endif
#ifdef EWINDOWS
	COORD coords;
	int temp;
	char cc[4];
#endif

#if defined(EWINDOWS)
	show_console();
#endif

	args = SEQ_PTR(x);
	line =   get_int(*(args->base+1));
	column = get_int(*(args->base+2));
	x = *(args->base+3);
	args = SEQ_PTR(x);
	len = args->length;
	if (!IS_SEQUENCE(x) || (len & 1) != 0)
		RTFatal("third argument to put_screen_char() must be a sequence of even length");
	p = args->base+1;

#ifdef EUNIX
	save_line = screen_line;
	save_col = screen_col;
	fg = current_fg_color;
	bg = current_bg_color;
	SetPosition(line, column);
	while (len > 0) {
		c = get_pos_int("put_screen_char()", *p);
		attr = get_pos_int("put_screen_char()", *(p+1));
		SetTColor(attr & 15);
		SetBColor(attr >> 4);
		iputc(c, stdout);
		s1[0] = c;
		s1[1] = 0;
		update_screen_string(s1);
		screen_col++;
		p += 2;
		len -= 2;
	}
	SetPosition(save_line, save_col); // restore cursor location
	
	// reset colors to what they were before this call:
	SetBColor( bg );
	current_bg_color = bg;
	
	SetTColor( fg );
	current_fg_color = fg;
	
	iflush(stdout);
#endif

#ifdef EWINDOWS
	while (len > 0) {
		cc[0] = get_pos_int("put_screen_char()", *p);
		attr  = get_pos_int("put_screen_char()", *(p+1));
		coords.X = column-1;
		coords.Y = line-1;
		column++;
		WriteConsoleOutputCharacter(console_output, (LPTSTR)&cc, 1, coords, (LPDWORD)&temp);
		WriteConsoleOutputAttribute(console_output, (LPWORD)&attr, 1, coords, (LPDWORD)&temp);
		p += 2;
		len -= 2;
	}
#endif
	
	return ATOM_1;
}

static object GetScreenChar(object x)
/* return {character, attributes} at given (line, col) location */
{

	object_ptr obj_ptr;
	s1_ptr result, x1;
	unsigned line, column;

#ifdef EWINDOWS

	int temp, att;
	char ch[4];
	COORD coords;
#endif

	x1 = SEQ_PTR(x);
	line =   get_int(*(x1->base+1));
	column = get_int(*(x1->base+2));
	result = NewS1((long)2);
	obj_ptr = result->base;

#ifdef EWINDOWS
	show_console();

	coords.X = column-1;
	coords.Y = line-1;

	att = 0;
	ReadConsoleOutputCharacter(console_output, (LPTSTR)&ch, 1, coords, (LPDWORD)&temp);
	ReadConsoleOutputAttribute(console_output, (LPWORD)&att, 1, coords, (LPDWORD)&temp);

	obj_ptr[1] = ch[0];
	if ((unsigned)att <= (unsigned)MAXINT)
		obj_ptr[2] = att;
	else
		obj_ptr[2] = NewDouble((double)(unsigned)att);

#endif

#ifdef EUNIX
	if (line >= 1 && line <= (unsigned)line_max &&
		column >= 1 && column <= (unsigned)col_max) {
		obj_ptr[1] = screen_image[line-1][column-1].ascii;
		obj_ptr[2] = (screen_image[line-1][column-1].fg_color & 15) |
					 (screen_image[line-1][column-1].bg_color << 4);
	}
	else {
		obj_ptr[1] = ' ';
		obj_ptr[2] = 0;
	}
#endif
	return MAKE_SEQ(result);
}

static object GetPosition()
/* return {line, column} for cursor */
{
#ifdef EUNIX
	struct rccoord pos;
#endif
	object_ptr obj_ptr;
	s1_ptr result;
#ifdef EWINDOWS
	CONSOLE_SCREEN_BUFFER_INFO console_info;
#endif

	result = NewS1((long)2);
	obj_ptr = result->base;
#ifdef EWINDOWS
	show_console();
	GetConsoleScreenBufferInfo(console_output, &console_info);
	obj_ptr[1] = MAKE_INT(console_info.dwCursorPosition.Y+1);
	obj_ptr[2] = MAKE_INT(console_info.dwCursorPosition.X+1);
#else
	pos = GetTextPositionP();
	obj_ptr[1] = MAKE_INT(pos.row);
	obj_ptr[2] = MAKE_INT(pos.col);
#endif
	return MAKE_SEQ(result);
}

static object flush_file(object x)
/* flush an open user file */
{
	if (x != last_w_file_no) {
		last_w_file_ptr = which_file(x, EF_WRITE);
		if (IS_ATOM_INT(x))
			last_w_file_no = x;
		else
			last_w_file_no = NOVALUE;
	}
	iflush(last_w_file_ptr);
	return ATOM_1;
}

static object lock_file(object x)
/* lock a file. x is {fn, t, {first-byte, last-byte}} */
{
	IFILE f;
	int fd;
	int r;
#ifdef EUNIX
	int t;
#else
	unsigned long first, last;
	object s;
#endif
	object fn;

	// get 1st element of x - file number - assume x is a sequence of length 3
	x = (object)SEQ_PTR(x);
	fn = *(((s1_ptr)x)->base+1);
	f = which_file(fn, EF_READ | EF_WRITE);
	fd = ifileno(f);

#ifdef EUNIX
	// get 2nd element of x - lock type
	t = get_int(*(((s1_ptr)x)->base+2));
	if (t == 1)
		r = flock(fd, LOCK_SH | LOCK_NB);
	else
		r = flock(fd, LOCK_EX | LOCK_NB);
#else // EUNIX
	// get 3rd element of x - range - assume it's a sequence
	s = *(((s1_ptr)x)->base+3);
	s = (object)SEQ_PTR(s);
	if (((s1_ptr)s)->length == 0) {
		first = 0;
		last = 0xFFFFFFFE;
	}
	else if (((s1_ptr)s)->length == 2) {
		first = get_int(*(((s1_ptr)s)->base+1));
		last =  get_int(*(((s1_ptr)s)->base+2));
	}
	else {
		RTFatal("3rd argument to lock_file must be a sequence of length 0 or 2");
	}
	if (last < first)
		return ATOM_0;
#if defined(EMINGW)
	r = 0;  // TODO: FOR NOW!
#else // defined EMINGW
	r = lock(fd, first, last - first + 1);
#endif // defined EMINGW
#endif // EUNIX
	if (r == 0)
		return ATOM_1; // success
	else
		return ATOM_0; // fail
}

static object unlock_file(object x)
/* unlock a file */
{
	IFILE f;
	int fd;
#ifdef EWINDOWS
	unsigned long first, last;
	object s;
#endif
	object fn;

	// get 1st element of x - can assume x is a sequence of length 2
	x = (object)SEQ_PTR(x);
	fn = *(((s1_ptr)x)->base+1);
	f = which_file(fn, EF_READ | EF_WRITE);
	fd = ifileno(f);
#ifdef EUNIX
	flock(fd, LOCK_UN);
#else // EUNIX
	// get 2nd element of x - range - assume it's a sequence
	s = *(((s1_ptr)x)->base+2);
	s = (object)SEQ_PTR(s);
	if (((s1_ptr)s)->length == 0) {
		first = 0;
		last = 0xFFFFFFFE;
	}
	else if (((s1_ptr)s)->length == 2) {
		first = get_int(*(((s1_ptr)s)->base+1));
		last =  get_int(*(((s1_ptr)s)->base+2));
	}
	else {
		RTFatal("2nd argument to unlock_file must be a sequence of length 0 or 2");
	}
#if defined(EMINGW)
	/* do nothing */
#else // defined EMINGW
	if (last >= first)
		unlock(fd, first, last - first + 1);
#endif // EMINGW
#endif // EUNIX
	return ATOM_1; // ignored
}

static object get_rand()
/* Return the random generator's current seed values */
{
	s1_ptr result;

	result = NewS1(2);
	result->base[1] = seed1;
	result->base[2] = seed2;

	return MAKE_SEQ(result);
}

static object set_rand(object x)
/* set random number generator */
{
	long r;
	s1_ptr x_ptr;
	long slen;
	object_ptr obp;

	if (!ASEQ(x)) {
		// Simple case - just a single value supplied.
		r = get_int(x);

		seed1 = r+1;
		seed2 = ~(r) + 999;
	} else {
		// We got a sequence given to us.
		x_ptr = SEQ_PTR(x);
		slen = x_ptr->length;
		if (slen == 0) {
			// Empty sequence means randomize the generator.
			setran();
		} else {
			obp = x_ptr->base;
			// A sequence of two atoms explictly supplies seed1 and seed2 values.
			if ((slen == 2) && !ASEQ(obp[1]) && !ASEQ(obp[2])) {
				seed1 = get_int(obp[1]);
				seed2 = get_int(obp[2]);
			}
			else {
				// Complex case - an arbitary sequence supplied.
				seed1 = get_int(calc_hash(x, slen));
				seed2 = get_int(calc_hash(slen, make_atom32(seed1)));
			}
		}
	}

	rand_was_set = TRUE;

	return ATOM_1;
}

static object use_vesa(object x)
/* turn on/off vesa flag */
{
	UNUSED(x);
	not_supported("use_vesa()");
	return ATOM_1;
}

static object crash_message(object x)
/* record user's message in case of a crash */
{
	if (crash_msg != NULL) {
		EFree(crash_msg);
	}

	if (!IS_SEQUENCE(x) || SEQ_PTR(x)->length == 0) {
		crash_msg = NULL;
	}
	else {
		crash_msg = EMalloc(SEQ_PTR(x)->length + 1);
		MakeCString(crash_msg, x, SEQ_PTR(x)->length + 1);
	}
	return ATOM_1;
}

static object crash_file(object x)
/* record user's alternate path for ex.err */
/* assume x is a sequence */
{
	if (TempErrName) {
		EFree(TempErrName);
	}
	TempErrName = EMalloc(SEQ_PTR(x)->length + 1);
	MakeCString(TempErrName, x, SEQ_PTR(x)->length + 1);
	return ATOM_1;
}

static object warning_file(object x)
/* record user's alternate path for a warning file log */
{
	if (TempWarningName != NULL) {
		EFree(TempWarningName);
	}
	if IS_ATOM(x) {
		TempWarningName = NULL;
		if (!IS_ATOM_INT(x)) x = (long)(DBL_PTR(x)->dbl);
		display_warnings = (INT_VAL(x) >= 0)?1:0;
	}
	else {
		TempWarningName = EMalloc(SEQ_PTR(x)->length + 1);
		MakeCString(TempWarningName, x, SEQ_PTR(x)->length + 1);
	}
	return ATOM_1;
}

static void do_crash(object x)
{
	char *message;

	message = EMalloc(SEQ_PTR(x)->length + 1);
	MakeCString(message, x, SEQ_PTR(x)->length + 1);
	RTFatal(message);
}

static object change_dir(object x)
/* change to a new current directory */
/* assume x is a sequence */
{
	char *new_dir;
	int r;

	new_dir = EMalloc(SEQ_PTR(x)->length + 1);
	MakeCString(new_dir, x, SEQ_PTR(x)->length + 1);
	r = chdir(new_dir);
	EFree(new_dir);
	if (r == 0)
		return ATOM_1;
	else
		return ATOM_0;
}

static object e_sleep(object x)
/* sleep for x seconds */
{
	double t;

	if IS_ATOM(x) {
		if (IS_ATOM_INT(x)) {
			t = (double)INT_VAL(x);
		} else {
			t = DBL_PTR(x)->dbl;
		}
	}
	Wait(t);
	return ATOM_1;
}

double current_time()
/* return value for time() function */
{
#ifdef EUNIX
	struct tms buf;
#endif
	if (clock_frequency == 0.0) {
		/* no handler */
		return (double)
#ifdef EUNIX
		times(&buf) / clk_tck
#else
		clock() / (double)clocks_per_sec
#endif
		 + clock_adjust;
	}
	else {
		/* our handler is installed */
		return base_time + our_clock_ticks / clock_frequency;
	}
}


#ifndef ERUNTIME
#ifdef EWINDOWS
DWORD WINAPI WinTimer(LPVOID lpParameter)
{
	LARGE_INTEGER freq,lcount,ncount;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&lcount);
	while(sample_next < sample_size){
		lcount.QuadPart=((double)lcount.QuadPart)+((double)freq.QuadPart)*0.001;
		QueryPerformanceCounter(&ncount);
		if(ncount.QuadPart<lcount.QuadPart){
			Sleep((((double)(lcount.QuadPart-ncount.QuadPart))/((double)freq.QuadPart))*1000.0);
		}
		if (Executing && ProfileOn) {
			profile_sample[sample_next++] = (int)tpc;
		}
	}
	return 0;
}
#endif
#endif


//void ESetTimer(void (__interrupt __far *handler)())
///* Do some initialization */
//{
//}

object tick_rate(object x)
/* Set new system clock tick (interrupt) rate.
   x may be int or double, >= 0. 0 means restore 18.2 rate. */
{
	UNUSED(x);
	return ATOM_1;
}

static object float_to_atom(object x, int flen)
/* convert a sequence of 4 or 8 bytes in IEEE format to an atom */
{
	int len, i;
	object_ptr obj_ptr;
	char fbuff[8];
	double d;
	s1_ptr s;

	s = SEQ_PTR(x);
	len = s->length;
	if (len != flen)
		RTFatal("sequence has wrong length");
	obj_ptr = s->base+1;
	for (i = 0; i < len; i++) {
		fbuff[i] = (char)obj_ptr[i];
	}
	if (flen == 4)
		d = (double)*((float *)&fbuff);
	else
		d = *((double *)&fbuff);
	return NewDouble(d);
}

static object fpsequence(unsigned char *fp, int len)
/* return a sequence of bytes for a floating-point number */
{
	s1_ptr result;
	object_ptr obj_ptr;
	int i;

	if (len == 0)
		RTFatal("in machine_func an atom was expected, not a sequence");
	result = NewS1(len);
	obj_ptr = result->base+1;

	for (i = 0; i < len; i++) {
		obj_ptr[i] = fp[i];
	}
	return MAKE_SEQ(result);
}

static object atom_to_float64(object x)
/* convert an atom to a sequence of 8 bytes IEEE format */
{
	double d;
	int len;

	len = 8;
	if (IS_ATOM_INT(x)) {
		d = (double)INT_VAL(x);
	}
	else if (IS_ATOM(x)) {
		d = DBL_PTR(x)->dbl;
	}
	else
		len = 0;
	return fpsequence((uchar *)&d, len);
}

static object atom_to_float32(object x)
/* convert an atom to a sequence of 4 bytes in IEEE format */
{
	float f;
	int len;

	len = 4;
	if (IS_ATOM_INT(x)) {
		f = (float)INT_VAL(x);
	}
	else if (IS_ATOM(x)) {
		f = (float)(DBL_PTR(x)->dbl);
	}
	else
		len = 0;
	return fpsequence((uchar *)&f, len);
}

object memory_copy(object d, object s, object n)
/* Fast memory to memory copy - called from x.c or machine.c */
{
	char *dest;
	char *src;
	unsigned nbytes;

	dest   = (char *)get_pos_int("mem_copy", d);
	src    = (char *)get_pos_int("mem_copy", s);
	nbytes = get_pos_int("mem_copy", n);

	memmove(dest, src, nbytes); /* overlapping regions handled correctly */
	return ATOM_1;
}

object memory_set(object d, object v, object n)
/* Fast memory set - called from x.c or machine.c */
{
	char *dest;
	int value;
	unsigned nbytes;

	dest   = (char *)get_pos_int("mem_set", d);
	value  = (int)get_pos_int("mem_set", v);
	nbytes = get_pos_int("mem_set", n);
	memset(dest, value, nbytes);
	return ATOM_1;
}

#ifdef EWINDOWS
HINSTANCE *open_dll_list = NULL;
int open_dll_size = 0;
int open_dll_count = 0;
#endif

object OpenDll(object x)
{

	s1_ptr dll_ptr;
	static char message[81];
	char *dll_string;
	HINSTANCE lib;
	int message_len;

	/* x will be a sequence if called via open_dll() */

	dll_ptr = SEQ_PTR(x);
	dll_string = TempBuff;
	message_len = strlen("name for open_dll() is too long."
			"  The name started with \"\".")+1;
	MakeCString(dll_string, (object)x, TEMP_SIZE);
	if (dll_ptr->length >= TEMP_SIZE) {
		dll_string[80 - message_len]='\0';
		snprintf(message,80,"name for open_dll() is too long."
			"  The name started with \"%s\".", dll_string);
		RTFatal(message);
	}
#ifdef EWINDOWS
	lib = (HINSTANCE)LoadLibrary(dll_string);
	// add to dll list so we can close it at end of execution
	if (lib != NULL) {
		if (open_dll_count >= open_dll_size) {
			size_t newsize;

			open_dll_size += 100;
			newsize = open_dll_size * sizeof(HINSTANCE);
			if (open_dll_list == NULL) {
				open_dll_list = (HINSTANCE *)EMalloc(newsize);
			}
			else {
				open_dll_list = (HINSTANCE *)ERealloc((char *)open_dll_list, newsize);
			}
			if (open_dll_list == NULL) {
				RTFatal("Cannot allocate RAM (%d bytes) for dll list to add %s", newsize, dll_string);
			}
		}
		open_dll_list[open_dll_count++] = lib;
	}
#else
	// Linux

	lib = (HINSTANCE)dlopen(dll_string, RTLD_LAZY | RTLD_GLOBAL);

#endif
	return MAKE_UINT(lib);
}

object DefineCVar(object x)
/* Get the address of a C variable, or return -1 */
{
	HINSTANCE lib;
	object variable_name;
	s1_ptr variable_ptr;
	char *variable_string;
	char *variable_address;

	unsigned addr;

	// x will be a sequence if called from define_c_func/define_c_proc
	x = (object)SEQ_PTR(x);

	lib = (HINSTANCE)*(((s1_ptr)x)->base+1);
	lib = (HINSTANCE)get_pos_int("define_c_proc/func", (object)lib);

	variable_name =  *(((s1_ptr)x)->base+2);
	if (IS_ATOM(variable_name))
		RTFatal("variable name must be a sequence");

	variable_ptr = SEQ_PTR(variable_name);
	if (variable_ptr->length >= TEMP_SIZE)
		RTFatal("variable name is too long");
	variable_string = TempBuff;
	MakeCString(variable_string, variable_name, TEMP_SIZE);
#ifdef EWINDOWS
	//Ray Smith says this works.
	variable_address = (char *)(int (*)())GetProcAddress((void *)lib, variable_string);
	if (variable_address == NULL)
		return ATOM_M1;
#else
	// Linux
	variable_address = (char *)dlsym((void *)lib, variable_string);
	if (dlerror() != NULL)
		return ATOM_M1;
#endif
	addr = (unsigned)variable_address;
	return MAKE_UINT(addr);
}


object DefineC(object x)
/* define a C routine: x is {lib, name, arg_sizes, return_type or 0}
   alternatively, x is {"", address or {'+', address}, arg_sizes, return_type or 0}
   Return -1 on failure. */
{
	HINSTANCE lib;
	object routine_name;
	s1_ptr routine_ptr;
	char *routine_string;
	int (*proc_address)();
	object arg_size, return_size;
	object_ptr arg;
	int convention, t, raw_addr;

	// x will be a sequence if called from define_c_func/define_c_proc
	x = (object)SEQ_PTR(x);

	lib = (HINSTANCE)*(((s1_ptr)x)->base+1);
	raw_addr = FALSE;

	if (IS_SEQUENCE(lib)) {
		/* machine code: must be length-0, implies 2nd arg is
		   address or {'+', address} */
		if (SEQ_PTR(lib)->length != 0)
			RTFatal("first argument of define_c_proc/func must be an atom or an empty sequence");
		raw_addr = TRUE;
	}
	else {
		/* 32-bit address of lib was supplied */
		lib = (HINSTANCE)get_pos_int("define_c_proc/func", (object)lib);
	}

	routine_name = *(((s1_ptr)x)->base+2);
	convention = C_STDCALL;

	if (raw_addr) {
		/* machine code routine */
		if (IS_ATOM(routine_name)) {
			/* addr */
			proc_address = (int (*)())get_pos_int("define_c_proc/func",
										(object)routine_name);
		}
		else {
			/* {'+', addr} */
			if (SEQ_PTR(routine_name)->length != 2)
				RTFatal("expected {'+', address} as second argument of define_c_proc/func");
			proc_address = (int (*)())*(SEQ_PTR(routine_name)->base+2);
			proc_address = (int (*)())get_pos_int("define_c_proc/func", (object)proc_address);
#ifdef EWINDOWS
			t = (int)*(SEQ_PTR(routine_name)->base+1);
			t = get_pos_int("define_c_proc/func", (object)t);
			if (t == '+')
				convention = C_CDECL;
			else
				RTFatal("unsupported calling convention - use '+' for CDECL");
#endif
		}
		/* assign a sequence value to routine_ptr */
		snprintf(TempBuff, TEMP_SIZE, "machine code routine at %p", proc_address);
		TempBuff[TEMP_SIZE-1] = 0; // ensure NULL
		routine_name = NewString(TempBuff);
		routine_ptr = SEQ_PTR(routine_name);
	}

	else {
		/* C .dll routine */
		if (IS_ATOM(routine_name))
			RTFatal("routine name must be a sequence");
		routine_ptr = SEQ_PTR(routine_name);
		Ref(routine_name);
		if (routine_ptr->length >= TEMP_SIZE)
			RTFatal("routine name is too long");
		routine_string = TempBuff;
		MakeCString(routine_string, routine_name, TEMP_SIZE);
#ifdef EWINDOWS
		if (routine_string[0] == '+') {
			routine_string++;
			convention = C_CDECL;
		}
		proc_address = (int (*)())GetProcAddress((void *)lib, routine_string);
		if (proc_address == NULL)
			return ATOM_M1;

#else
#ifdef EUNIX
		proc_address = (int (*)())dlsym((void *)lib, routine_string);
		if (dlerror() != NULL)
			return ATOM_M1;
#endif
#endif
	}

	if (c_routine_next >= c_routine_size) {
		if (c_routine == NULL) {
			c_routine_size = 20;
			c_routine = (struct arg_info *)EMalloc(c_routine_size * sizeof(struct arg_info));
		}
		else {
			c_routine_size *= 2;
			c_routine = (struct arg_info *)ERealloc((char *)c_routine,
								 c_routine_size * sizeof(struct arg_info));
		}
	}

	arg_size = *(((s1_ptr)x)->base+3);
	if (IS_ATOM(arg_size))
		RTFatal("argument size list must be a sequence");
	RefDS(arg_size);

	arg = SEQ_PTR(arg_size)->base+1;
	while (*arg != NOVALUE) {
		if (IS_ATOM_INT(*arg)) {
			t = *arg;
		}
		else if (IS_ATOM(*arg)) {
			t = (unsigned long)DBL_PTR(*arg)->dbl;
		}
		else
			RTFatal("argument type may not be a sequence");

		if (t >= E_INTEGER && t <= E_OBJECT)
			eu_dll_exists = TRUE;
		else if (t < C_CHAR || t > C_DOUBLE)
			RTFatal("Invalid argument type");

		arg++;
	}

	return_size = *(((s1_ptr)x)->base+4);

	if (IS_ATOM_INT(return_size)) {
		t = return_size;
	}
	else if (IS_ATOM(return_size)) {
		t = (unsigned long)DBL_PTR(return_size)->dbl;
	}
	else
		RTFatal("return type must be an atom");

	if (t >= E_INTEGER && t <= E_OBJECT)
		eu_dll_exists = TRUE;
	else if (t != 0 && (t < C_CHAR || t > C_DOUBLE))
		RTFatal("Invalid return type");

	c_routine[c_routine_next].address = proc_address;
	c_routine[c_routine_next].name = routine_ptr;
	c_routine[c_routine_next].arg_size = SEQ_PTR(arg_size);
	c_routine[c_routine_next].return_size = t;
	c_routine[c_routine_next].convention = convention;
	return c_routine_next++;
}

#ifdef EOSX
#define CALLBACK_SIZE (108)
#else
#if __GNUC__ == 4
#define CALLBACK_SIZE (96)
#else
#define CALLBACK_SIZE (80)
#endif
#endif

#define EXECUTABLE_ALIGNMENT (4)

#ifdef EWINDOWS
typedef void * (__stdcall *VirtualAlloc_t)(void *, unsigned int size, unsigned int flags, unsigned int protection);
#endif

/* Return the smallest multiple of p_radix that is at least as big as p_v.

	Assumptions: p_radix must be a power of two.
				p_v and p_radix must be < power(2,31)
*/
inline signed int roundup(unsigned int p_v, unsigned int p_radix) {
	signed int radix = (signed int)p_radix;
	signed int v = (signed int)p_v;

	return - (-radix & -v);
}

typedef unsigned char * page_ptr;

unsigned char * new_page() {
#ifdef EWINDOWS
	return VirtualAlloc( NULL, CALLBACK_SIZE, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE );
#elif ELINUX
	return memalign( pagesize, pagesize );
#elif EUNIX
	return mmap(NULL, pagesize, PROT_EXEC|PROT_WRITE|PROT_READ, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);			
#endif
}

void set_page_to_read_execute_only(page_ptr page_addr) {
#ifdef EWINDOWS
	static unsigned long oldprot;
	static unsigned long * oldprotptr = &oldprot;
	VirtualProtect(page_addr, pagesize, PAGE_EXECUTE_READ, oldprotptr);
#elif EUNIX
	mprotect(page_addr, pagesize, PROT_EXEC|PROT_READ);
#endif
}

void set_page_to_read_write_execute(page_ptr page_addr) {
#ifdef EWINDOWS
	static unsigned long oldprot;
	static unsigned long * oldprotptr = &oldprot;
	VirtualProtect(page_addr, pagesize, PAGE_EXECUTE_READWRITE, oldprotptr);
#elif EUNIX
	mprotect(page_addr, pagesize, PROT_EXEC | PROT_READ | PROT_WRITE );
#endif
}

object CallBack(object x)
/* return either a call-back address for routine id x
   x can be the routine id for stdcall, or {'+', routine_id} for cdecl

   or return a three element sequence containing a Read-Only machine address, the replace value
   needed (sym tab pointer), and the call_back size respectively so the caller can make its *own*
   call-back address.  In this case x must be a sequence containing only a routine_id:
   {routine_id} or a sequence containing a two element sequence {{'+',routine_id}} for cdecl.   And
   the caller must search for the bytes {#78,#56,#34,#12}, allocate enough memory (call_back size)
   and to copy what is pointed to by the said address and then replace the searched for bytes with
   the replace value in the allocated memory.
   
   Assumption: pagesize is much bigger than CALLBACK_SIZE.
   
   */
{
	static unsigned char *page_addr = NULL;
	static unsigned int page_offset = 0;
	static long call_increment = 0;
	static long last_block_offset = 0;
	unsigned addr;
	int routine_id, i, num_args;
	unsigned char *copy_addr;
#ifndef ERUNTIME
	symtab_ptr routine;
#endif
	int not_patched;
	s1_ptr x_ptr;
	int convention;
	int res;
	convention = C_CDECL;
	not_patched = 1;
	/* Handle whether it is {'+', routine_id} or {routine_id}:
	 * Set flags and extract routine id value. */
	if (IS_SEQUENCE(x)) {
		x_ptr = SEQ_PTR(x);
		if (x_ptr->length != 2){
			RTFatal("call_back() argument must be routine_id, or {'+', routine_id}");
		}
		if (get_int( x_ptr->base[1] ) != '+')
			RTFatal("for cdecl, use call_back({'+', routine_id})");
		routine_id = get_int( x_ptr->base[2] );
	}
	else {
		routine_id = get_int(x);
#if defined(EWINDOWS)
		convention = C_STDCALL;
#endif
	}

	/* Check routine_id value and get the number of arguments */
#ifdef ERUNTIME
	num_args = rt00[routine_id].num_args;
#else
	if (routine_id >= e_routine_next)
		RTFatal("call_back: bad routine id\n");
	routine = e_routine[routine_id];

	if (routine->token == PROC)
		RTFatal("call-back routine must be a function or type");
	num_args = routine->u.subp.num_args;
#endif

	/* Get the address of the template to be modified. */
	if (convention == C_CDECL) {
		// cdecl allows var args - only one template needed
		addr = (unsigned)&cdecl_call_back;
	}
	else {
		switch (num_args) {
			case 0: addr = (unsigned)&call_back0;
					break;
			case 1: addr = (unsigned)&call_back1;
					break;
			case 2: addr = (unsigned)&call_back2;
					break;
			case 3: addr = (unsigned)&call_back3;
					break;
			case 4: addr = (unsigned)&call_back4;
					break;
			case 5: addr = (unsigned)&call_back5;
					break;
			case 6: addr = (unsigned)&call_back6;
					break;
			case 7: addr = (unsigned)&call_back7;
					break;
			case 8: addr = (unsigned)&call_back8;
					break;
			case 9: addr = (unsigned)&call_back9;
					break;
			default:
					RTFatal("routine has too many parameters for call-back");
		}
	}

	/* Now allocate memory that is executable or at least can be made to be ... */
	
	/*	Here allocate and manage memory for 4kB is a lot to use when you
		only use 92B.  Memory is allocated by /pagesize/ bytes at a time.
		So, we give pieces of this page on each call until there is not enough to complete
		up to /CALLBACK_SIZE/ bytes.
		*/
	if (page_addr != NULL) {
		if (page_offset < last_block_offset) {
			// Grab next sub-block from the current block.
			page_offset += call_increment;
		} else {
			// Allocate a new block
			page_addr = new_page();
			page_offset = 0;
		}
	} else {
		// Set up 'constants' and initial block allocation
		call_increment = roundup(CALLBACK_SIZE, EXECUTABLE_ALIGNMENT);
		last_block_offset = (pagesize - 2 * call_increment);

		page_addr = new_page(); //VirtualAlloc( NULL, CALLBACK_SIZE, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE );
		page_offset = 0;
	}
	
	copy_addr = page_addr + page_offset;
#	ifdef EWINDOWS		   
	/* Assume we are running under some Windows that
	   supports VirtualAlloc() always returning 0. 
	   This has happened before in testing.  */
	if (copy_addr == NULL)
		copy_addr = (unsigned char *)EMalloc(CALLBACK_SIZE);	
#	endif /* def EWINDOWS */


	/* Check if the memory allocation worked. */	
	if (copy_addr == NULL) {
		SpaceMessage();
	}

	/* Copy memory of the template to the newly allocated memory.
	 * First we have to make the memory writable.
	 */
	set_page_to_read_write_execute(page_addr);
    res = memcopy(copy_addr, CALLBACK_SIZE, (char *)addr, CALLBACK_SIZE);
	if (res != 0) {
		RTFatal("Internal error: CallBack memcopy failed (%d).", res);
	}
	

	// Plug in the symtab pointer
	// Find 78 56 34 12
	for (i = 4; i < CALLBACK_SIZE-4; i++) {
		if (copy_addr[i]   == 0x078 &&
			copy_addr[i+1] == 0x056) {
#ifdef ERUNTIME
			*(int *)(copy_addr+i) = routine_id;
#else
			*(symtab_ptr *)(copy_addr+i) = e_routine[routine_id];
#endif
			not_patched = 0;
			break;
		}
	}
	/* We're done writing, so protect the memory again...*/
	set_page_to_read_execute_only(page_addr);
	
	if (not_patched) {
		RTFatal("Internal error: CallBack routine id patch failed: missing magic.");
	}
	
	addr = (unsigned long)copy_addr;

	/* Return new address. */
	return MAKE_UINT(addr);
}

int *crash_list = NULL;    // list of routines to call when there's a crash
int crash_routines = 0;    // number of routines
int crash_size = 0;        // space allocated for crash_list

static object crash_routine(object x)
/* add a new routine id to the list to be called if there's a crash */
{
	int r;

	r = get_int(x);
	if (r < 0 || r >=
#ifdef ERUNTIME
	1000000
#else
	e_routine_next
#endif
	   )
		RTFatal("invalid routine id passed to crash_routine()");

#ifndef ERUNTIME
	if (e_routine[r]->token == PROC)
	{
		RTFatal("procedure's routine id passed to crash_routine()");
	}
#endif

	if (crash_list == NULL) {
#ifdef ERUNTIME
		// Interpreter does this in InitExecute()
#ifndef EDEBUG
		signal(SIGILL,  Machine_Handler);
		signal(SIGSEGV, Machine_Handler);
#endif
#endif
		crash_size = 5;
		crash_list = (int *)EMalloc(sizeof(int) * crash_size);
	}
	else if (crash_routines >= crash_size) {
		crash_size += 10;
		crash_list = (int *)ERealloc((char *)crash_list, sizeof(int) * crash_size);
	}
	crash_list[crash_routines++] = r;

	return ATOM_1;
}

object eu_info()
{
	s1_ptr s1;
	s1 = NewS1(6);
	s1->base[1] = MAJ_VER;
	s1->base[2] = MIN_VER;
	s1->base[3] = PAT_VER;
	s1->base[4] = NewString(REL_TYPE);
	s1->base[5] = NewString(get_svn_revision());
        s1->base[6] = NewDouble(eustart_time);
        return MAKE_SEQ(s1);
}

object eu_uname()
{
#ifdef EUNIX
	int ret;
	struct utsname buf;
	s1_ptr s1;

	ret = uname(&buf);
	if (ret < 0)
		return ATOM_M1;

#ifdef _GNU_SOURCE
	s1 = NewS1(6);
#else
	s1 = NewS1(5);
#endif
	s1->base[1] = NewString(buf.sysname);
	s1->base[2] = NewString(buf.nodename);
	s1->base[3] = NewString(buf.release);
	s1->base[4] = NewString(buf.version);
	s1->base[5] = NewString(buf.machine);
#ifdef _GNU_SOURCE
	s1->base[6] = NewString(buf.domainname);
#endif
	return MAKE_SEQ(s1);
#else
	return ATOM_0;
#endif
}

#ifdef EWINDOWS
long __stdcall Win_Machine_Handler(LPEXCEPTION_POINTERS p) {
	return EXCEPTION_EXECUTE_HANDLER;
}
#endif

void Machine_Handler(int sig_no)
/* illegal instruction, segmentation violation */
{
#ifdef WINDOWS
	is_batch = console_application();
#endif
#ifdef ERUNTIME
	RTFatal("A machine-level exception occurred during execution of your program");
#else
	RTFatal("A machine-level exception occurred during execution of this statement");
#endif
}

#ifndef ERUNTIME
extern struct IL fe;

object start_backend(object x)
/* called by Euphoria-written front-end to run the back-end
 *
 * x is {symtab, topcode, subcode, names, line_table, miscellaneous }
 */
{
	long switch_len, i;
	s1_ptr x_ptr;
	char *w;



	w = "backend";

	x_ptr = SEQ_PTR(x);

	if (IS_ATOM(x) || x_ptr->length != 7)
		RTFatal("BACKEND requires a sequence of length 7");

	fe.st = (symtab_ptr)     get_pos_int(w, *(x_ptr->base+1));
	fe.sl = (struct sline *) get_pos_int(w, *(x_ptr->base+2));
	fe.misc = (int *)        get_pos_int(w, *(x_ptr->base+3));
	fe.lit = (char *)        get_pos_int(w, *(x_ptr->base+4));
	fe.includes = (unsigned char **) get_pos_int(w, *(x_ptr->base+5));
	fe.switches = x_ptr->base[6];
	fe.argv = x_ptr->base[7];

#if defined(EUNIX) || defined(EMINGW)
	do_exec(NULL);  // init jumptable
#endif

	fe_set_pointers(); /* change some fe indexes into pointers */

	/* Look at the switches for any information pertient to the backend */
	switch_len = SEQ_PTR(fe.switches)->length;

	for (i=1; i <= switch_len; i++) {
		x_ptr = (s1_ptr)(SEQ_PTR(fe.switches)->base[i]);
		w = (char *)EMalloc(SEQ_PTR(x_ptr)->length + 1);
		MakeCString(w, (object) x_ptr, SEQ_PTR(x_ptr)->length + 1);

		if (stricmp(w, "-batch") == 0) {
			is_batch = 1;
		}
		EFree(w);
	}

	be_init(); //earlier for DJGPP

	Execute(TopLevelSub->u.subp.code);

	return ATOM_1;
}
#endif

object machine(object opcode, object x)
/* Machine-specific function "machine". It is passed an opcode and
   a general Euphoria object as its parameters and it returns a
   Euphoria object as a result. */
{
	char *addr;
	int temp;
	char *dest;
	char *src;


	double d;

	while (TRUE) {
		switch(opcode) {  /* tricky - could be atom or sequence */
			case M_COMPLETE:
				return MAKE_INT(COMPLETE_MAGIC);
				break;
			case M_SET_T_COLOR:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return SetTColor(x);
				break;
			case M_SET_B_COLOR:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return SetBColor(x);
				break;
			case M_GRAPHICS_MODE:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return Graphics_Mode(x);
				break;
			case M_VIDEO_CONFIG:
				return Video_config(); /* 0 args */
				break;
			case M_CURSOR:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return Cursor(x);
				break;
			case M_TEXTROWS:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return TextRows(x);
				break;
			case M_WRAP:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return Wrap(x);
				break;
			case M_SCROLL:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return Scroll(x);
				break;
			case M_WAIT_KEY:
#if defined(EWINDOWS)
				show_console();
#endif
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return ATOM_0 + get_key(TRUE);
				break;
			case M_ALLOC:
				return user_allocate(x);
				break;
			case M_FREE:
				addr = (char *)get_pos_int("free", x);
				if (addr != NULL) {
					EFree(addr);
				}
				return ATOM_0;
				break;
			case M_SEEK:
				return Seek(x);
				break;
			case M_WHERE:
				return Where(x);
				break;
			case M_DIR:
				return Dir(x);
				break;
			case M_CURRENT_DIR:
				return CurrentDir();
				break;
			case M_GET_POSITION:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return GetPosition();
				break;
			case M_GET_SCREEN_CHAR:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return GetScreenChar(x);
				break;
			case M_PUT_SCREEN_CHAR:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				return PutScreenChar(x);
				break;
			case M_SET_RAND:
				return set_rand(x);
				break;
			case M_GET_RAND:
				return get_rand();
				break;
			case M_USE_VESA:
				return use_vesa(x);
				break;
			case M_CRASH_MESSAGE:
				return crash_message(x);
				break;
			case M_TICK_RATE:
				return tick_rate(x);
				break;
			case M_ALLOW_BREAK:
				allow_break = get_int(x);
				return ATOM_1;
				break;
			case M_CHECK_BREAK:
				temp = control_c_count;
				control_c_count = 0;
				return MAKE_INT(temp);
				break;
			case M_MEM_COPY:
				/* obsolete, but keep it */
				x = (object)SEQ_PTR(x);
				return memory_copy(*(((s1_ptr)x)->base+1),
								   *(((s1_ptr)x)->base+2),
								   *(((s1_ptr)x)->base+3));
				break;
			case M_MEM_SET:
				/* obsolete, but keep it */
				x = (object)SEQ_PTR(x);
				return memory_set(*(((s1_ptr)x)->base+1),
								  *(((s1_ptr)x)->base+2),
								  *(((s1_ptr)x)->base+3));
				break;
			case M_A_TO_F64:
				return atom_to_float64(x);
				break;
			case M_A_TO_F32:
				return atom_to_float32(x);
				break;
			case M_F64_TO_A:
				return float_to_atom(x, 8);
				break;
			case M_F32_TO_A:
				return float_to_atom(x, 4);
				break;

			case M_OPEN_DLL:
				return OpenDll(x);
				break;

			case M_DEFINE_C:
				return DefineC(x);
				break;

			case M_CALLBACK:
				return CallBack(x);
				break;

			case M_PLATFORM:
				/* obsolete, but keep it */
#ifdef ENETBSD
				return 7;
#else
#ifdef EOPENBSD
				return 6;
#else
#ifdef ESUNOS
				return 5;
#else
#ifdef EOSX
				return 4;
#else
#ifdef EBSD // FreeBSD by this point
				return 8;
#else
#ifdef ELINUX
				return 3;  // (UNIX, called Linux for backwards compatibility)
#else
#ifdef EWINDOWS
				return 2;  // WIN32
#else
				return 1; // Unknown platform
#endif
#endif
#endif
#endif
#endif
#endif
#endif

				break;

			case M_INSTANCE:
			{
				unsigned int inst = 0;
#ifdef EUNIX
				inst = (unsigned)getpid();
#endif
#ifdef EWINDOWS
				inst = (unsigned)winInstance;
#endif

				if (inst <= (unsigned)MAXINT)
					return inst;
				else
					return NewDouble((double)inst);
				break;
			}

			case M_FREE_CONSOLE:
				if (current_screen != MAIN_SCREEN)
					MainScreen();
				if (have_console) {
#ifndef EUNIX
					FreeConsole();
#endif
					have_console = FALSE;
				}
				// no-op in DOS
				return ATOM_1;
				break;

			case M_DEFINE_VAR:
				return DefineCVar(x);
				break;

			case M_CRASH_FILE:
				return crash_file(x);
				break;

			case M_WARNING_FILE:
				return warning_file(x);
				break;

			case M_FLUSH:
				return flush_file(x);
				break;

			case M_LOCK_FILE:
				return lock_file(x);
				break;

			case M_UNLOCK_FILE:
				return unlock_file(x);
				break;

			case M_CRASH:
				do_crash(x);
				return ATOM_M1;
				break;

			case M_CHDIR:
				return change_dir(x);
				break;

			case M_SLEEP:
				return e_sleep(x);
				break;

#ifndef ERUNTIME
			case M_BACKEND:
				return start_backend(x);
				break;
#endif
			case M_CRASH_ROUTINE:
				return crash_routine(x);
				break;

			case M_SET_ENV:
				x = (object)SEQ_PTR(x);
				src = EMalloc(SEQ_PTR(((s1_ptr) x)->base[1])->length + 1);
				dest = EMalloc(SEQ_PTR(((s1_ptr) x)->base[2])->length + 1);
				MakeCString(src, (object) *(((s1_ptr)x)->base+1),
							SEQ_PTR(((s1_ptr) x)->base[1])->length + 1);
				MakeCString(dest, (object) *(((s1_ptr)x)->base+2),
							SEQ_PTR(((s1_ptr) x)->base[2])->length + 1);
				temp = setenv(src, dest, *(((s1_ptr)x)->base+3));
				EFree(dest);
				EFree(src);
				return !temp;
				break;

			case M_UNSET_ENV:
				x = (object) SEQ_PTR(x);
				src = EMalloc(SEQ_PTR(((s1_ptr) x)->base[1])->length + 1);
				MakeCString(src, (object) *(((s1_ptr)x)->base+1),
							SEQ_PTR(((s1_ptr) x)->base[1])->length + 1);
#ifdef EWATCOM
				temp = setenv(src, NULL, 1);
#else
#ifdef EMINGW
				dest = EMalloc(strlen(src) + 2);
				strcpy(dest, src);
				strcat(dest, "=");
				/* on MinGW, putenv("var=") will unset the
				 * variable. On any other system, use unsetenv()
				 * as putenv("var=") will create an empty
				 * environment variable.MinGW() lacks unsetenv()
				 */
				temp = putenv(dest);
				EFree(dest);
#else
#ifdef EUNIX
#ifdef ELINUX
				temp = unsetenv(src);
#else
				unsetenv(src);
				temp = 0;
#endif /* ELINUX */
#endif /* EUNIX */
#endif /* EMINGW */
#endif /* EWATCOM */

				EFree(src);
				return !temp;
				break;

			case M_PCRE_COMPILE:
				x = (object)SEQ_PTR(x);
				return compile_pcre(*(((s1_ptr)x)->base+1),
							 *(((s1_ptr)x)->base+2));
				break;

			case M_PCRE_EXEC:
				return exec_pcre(x);
				break;

			case M_PCRE_REPLACE:
				return find_replace_pcre(x);

			case M_PCRE_ERROR_MESSAGE:
				return pcre_error_message(x);

			case M_PCRE_GET_OVECTOR_SIZE:
				return get_ovector_size(x);
				break;
			case M_EU_INFO:
				return eu_info();

			case M_UNAME:
				return eu_uname();

			case M_SOCK_INFO:
				return eusock_info(x);

			case M_SOCK_GETSERVBYNAME:
				return eusock_getservbyname(x);

			case M_SOCK_GETSERVBYPORT:
				return eusock_getservbyport(x);

			case M_SOCK_GETHOSTBYNAME:
				return eusock_gethostbyname(x);

			case M_SOCK_GETHOSTBYADDR:
				return eusock_gethostbyaddr(x);

			case M_SOCK_ERROR_CODE:
				return eusock_error_code();

			case M_SOCK_SOCKET:
				return eusock_socket(x);

			case M_SOCK_CLOSE:
				return eusock_close(x);

			case M_SOCK_SHUTDOWN:
				return eusock_shutdown(x);

			case M_SOCK_CONNECT:
				return eusock_connect(x);

			case M_SOCK_SEND:
				return eusock_send(x);

			case M_SOCK_RECV:
				return eusock_recv(x);

			case M_SOCK_BIND:
				return eusock_bind(x);

			case M_SOCK_LISTEN:
				return eusock_listen(x);

			case M_SOCK_ACCEPT:
				return eusock_accept(x);

			case M_SOCK_GETSOCKOPT:
				return eusock_getsockopt(x);

			case M_SOCK_SETSOCKOPT:
				return eusock_setsockopt(x);

			case M_SOCK_SELECT:
				return eusock_select(x);

            case M_SOCK_SENDTO:
                return eusock_sendto(x);

            case M_SOCK_RECVFROM:
                return eusock_recvfrom(x);

			/* remember to check for MAIN_SCREEN wherever appropriate ! */
			default:
				/* could be out-of-range int, or double, or sequence */
				if (IS_ATOM_INT(opcode)) {
					RTFatal("machine_proc/func(%d,...) not supported", opcode);
				}
				else if (IS_ATOM(opcode)) {
					d = DBL_PTR(opcode)->dbl;
					if (d < 0.0 || d >= MAXINT_DBL)
						RTFatal("the first argument of machine_proc/func must be a small positive integer");
					opcode = (long)d;
				}
				else {
					RTFatal("the first argument of machine_proc/func must be an integer");
				}
				/* try again at top of while loop */
		}
	}
}
