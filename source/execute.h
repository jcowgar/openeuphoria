/*****************************************************************************/
/*                                                                           */
/*                    INCLUDE FILE FOR RUN TIME DATA TYPES                   */
/*                                                                           */
/*****************************************************************************/

		  /* Euphoria object format v1.2 and later */

/* an object is represented as a 32-bit value as follows:

		unused  : 011xxxxx xxxxxxxx xxxxxxxx xxxxxxxx 
		unused  : 010xxxxx xxxxxxxx xxxxxxxx xxxxxxxx

		TOO_BIG:  01000000 00000000 00000000 00000000   (just too big for INT)
		
	   +ATOM-INT: 001vvvvv vvvvvvvv vvvvvvvv vvvvvvvv   (31-bit integer value)
	   +ATOM-INT: 000vvvvv vvvvvvvv vvvvvvvv vvvvvvvv   (31-bit integer value)
	   -ATOM-INT: 111vvvvv vvvvvvvv vvvvvvvv vvvvvvvv   (31-bit integer value)
	   -ATOM-INT: 110vvvvv vvvvvvvv vvvvvvvv vvvvvvvv   (31-bit integer value)

		NO VALUE: 10111111 11111111 11111111 11111111   (undefined object)

		ATOM-DBL: 101ppppp pppppppp pppppppp pppppppp   (29-bit pointer)

		SEQUENCE: 100ppppp pppppppp pppppppp pppppppp   (29-bit pointer)

   We ensure 8-byte alignment for s1 and dbl blocks - lower 3 bits 
   aren't needed - only 29 bits are stored.
*/

/* NO VALUE objects can occur only in a few well-defined places,
   so we can simplify some tests. For speed we first check for ATOM-INT
   since that's what most objects are. */ 

#define NOVALUE      ((long)0xbfffffffL)
#define TOO_BIG_INT  ((long)0x40000000L)
#define HIGH_BITS    ((long)0xC0000000L)
#define IS_ATOM_INT(ob)       (((long)(ob)) > NOVALUE)
#define IS_ATOM_INT_NV(ob)    ((long)(ob) >= NOVALUE)

/* these are obsolete */
#define INT_VAL(x)        ((int)(x))
#define MAKE_INT(x)       ((object)(x))

/* N.B. the following distinguishes DBL's from SEQUENCES -
   must eliminate the INT case first */
#define IS_ATOM_DBL(ob)         (((object)(ob)) >= (long)0xA0000000)

#define IS_ATOM(ob)             (((long)(ob)) >= (long)0xA0000000)
#define IS_SEQUENCE(ob)         (((long)(ob))  < (long)0xA0000000)

#define IS_DBL_OR_SEQUENCE(ob)  (((long)(ob)) < NOVALUE)

#undef MININT
#define MININT     (long)0xC0000000
#define MAXINT     (long)0x3FFFFFFF
#define MININT_VAL MININT
#define MININT_DBL ((double)MININT_VAL)
#define MAXINT_VAL MAXINT
#define MAXINT_DBL ((double)MAXINT_VAL)
#define INT23      (long)0x003FFFFFL
#define INT16      (long)0x00007FFFL
#define INT15      (long)0x00003FFFL
#define ATOM_M1    -1
#define ATOM_0     0
#define ATOM_1     1
#define ATOM_2     2

typedef long object;
typedef object *object_ptr;

typedef void(*cleanup_func)(object);
struct cleanup {
	long type;
	union func_union{
		long rid;
		cleanup_func builtin;
	} func;
};

typedef struct cleanup *cleanup_ptr;

struct s1 {                        /* a sequence header block */
	object_ptr base;               /* pointer to (non-existent) 0th element */
	long length;                   /* number of elements */
	long ref;                      /* reference count */
	long postfill;                 /* number of post-fill objects */
	cleanup_ptr cleanup;           /* custom clean up when sequence is deallocated */
}; /* total 20 bytes */

struct d {                         /* a double precision number */
	double dbl;                    /* double precision value */
	long ref;                      /* reference count */
	cleanup_ptr cleanup;           /* custom clean up when sequence is deallocated */
}; /* total 16 bytes */

#define D_SIZE (sizeof(struct d))  

/* **** Important Note ****
  The offset of the 'ref' field in the 'struct d' and the 'struct s1' must
  always be the same. This offset is assumed to be the same by the RefDS() macro.
*/

struct free_block {                /* a free storage block */
	struct free_block *next;       /* pointer to next free block */
	long filler;
	long ref;                      /* reference count */
}; /* 12 bytes */

struct symtab_entry;


/* 'routine_list' must always be identical to definition in euphoria\include\euphoria.h
*/
struct routine_list {   
	char *name;
	int (*addr)();
	int seq_num;
	int file_num;
	short int num_args;
	short int convention;
	char scope;
};

struct ns_list {
	char *name;
	int ns_num;
	int seq_num;
	int file_num;
};

typedef struct d  *d_ptr;
typedef struct s1 *s1_ptr;
typedef struct free_block *free_block_ptr;

struct sline {      /* source line table entry */
	char *src;               /* text of line, 
								first 4 bytes used for count when profiling */
	unsigned short line;     /* line number within file */
	unsigned char file_no;   /* file number */
	unsigned char options;   /* options in effect: */
#define OP_TRACE   0x01      /* statement trace */
#define OP_PROFILE_STATEMENT 0x04  /* statement profile */
#define OP_PROFILE_TIME 0x02       /* time profile */
}; /* 8 bytes */

struct op_info {
	object (*intfn)();
	object (*dblfn)();
};

struct replace_block {
	object_ptr copy_to;
	object_ptr copy_from;
	object_ptr start;
	object_ptr stop;
	object_ptr target;
};
typedef struct replace_block *replace_ptr;

#ifdef INT_CODES
typedef int opcode_type;
#define opcode(x) (x)
#else
typedef int *opcode_type;
#define opcode(x) jumptab[x-1]
#endif

#define UNKNOWN -1

#define EXPR_SIZE 200  /* initial size of call stack */

#ifdef EBSD
#define MAX_CACHED_SIZE 0        /* don't use storage cache at all */
#else
#define MAX_CACHED_SIZE 1024     /* this size (in bytes) or less are cached 
									Note: other vars must change if this does */
#endif

/* MACROS */
#define MAKE_DBL(x) ( (object) (((unsigned long)(x) >> 3) + (long)0xA0000000) )
#define DBL_PTR(ob) ( (d_ptr)  (((long)(ob)) << 3) )
#define MAKE_SEQ(x) ( (object) (((unsigned long)(x) >> 3) + (long)0x80000000) )
#define SEQ_PTR(ob) ( (s1_ptr) (((long)(ob)) << 3) ) 

/* ref a double or a sequence (both need same 3 bit shift) */
#define RefDS(a) ++(DBL_PTR(a)->ref)    

/* ref a general object */
#define Ref(a) if (IS_DBL_OR_SEQUENCE(a)) { RefDS(a); }

/* de-ref a double or a sequence */
#define DeRefDS(a) if (--(DBL_PTR(a)->ref) == 0 ) { de_reference((s1_ptr)(a)); }
/* de-ref a double or a sequence in x.c and set tpc (for time-profile) */
#define DeRefDSx(a) if (--(DBL_PTR(a)->ref) == 0 ) {tpc=pc; de_reference((s1_ptr)(a)); }

/* de_ref a sequence already in pointer form */
#define DeRefSP(a) if (--((s1_ptr)(a))->ref == 0 ) { de_reference((s1_ptr)MAKE_SEQ(a)); }

/* de-ref a general object */
#define DeRef(a) if (IS_DBL_OR_SEQUENCE(a)) { DeRefDS(a); }
/* de-ref a general object in x.c and set tpc (for time-profile) */
#define DeRefx(a) if (IS_DBL_OR_SEQUENCE(a)) { DeRefDSx(a); }

/* Reassign Target object as a Sequence */
#define ASSIGN_SEQ(t,s) DeRef(*(t)); *(t) = MAKE_SEQ(s);


#define UNIQUE(seq) (((s1_ptr)(seq))->ref == 1)

/* file modes */
#define EF_CLOSED 0
#define EF_READ   1
#define EF_WRITE  2
#define EF_APPEND 4

struct file_info {
	IFILE fptr;  // C FILE pointer
	int mode;    // file mode
}; 

struct arg_info {
	int (*address)();     // pointer to C function
	s1_ptr name;          // name of routine (for diagnostics)
	s1_ptr arg_size;      // s1_ptr of sequence of argument sizes
	object return_size;   // atom or sequence for return value size
	int convention;       // calling convention
};

#define NOT_INCLUDED     0x0
#define INDIRECT_INCLUDE 0x1
#define DIRECT_INCLUDE   0x2
#define PUBLIC_INCLUDE   0x4
#define DIRECT_OR_PUBLIC_INCLUDE  (PUBLIC_INCLUDE | DIRECT_INCLUDE)
#define ANY_INCLUDE               (INDIRECT_INCLUDE | DIRECT_INCLUDE | PUBLIC_INCLUDE)

struct IL {
	struct symtab_entry *st;
	struct sline *sl;
	int *misc;
	char *lit;
	unsigned char **includes;
	object switches;
	object argv;
};

// Task Control Block - sync with euphoria\include\euphoria.h
struct tcb {
	int rid;         // routine id
	double tid;      // external task id
	int type;        // type of task: T_REAL_TIME or T_TIME_SHARED
	int status;      // status: ST_ACTIVE, ST_SUSPENDED, ST_DEAD
	double start;    // start time of current run
	double min_inc;  // time increment for min
	double max_inc;  // time increment for max 
	double min_time; // minimum activation time
					 // or number of executions remaining before sharing
	double max_time; // maximum activation time (determines task order)
	int runs_left;   // number of executions left in this burst
	int runs_max;    // maximum number of executions in one burst
	int next;        // index of next task of the same kind
	object args;     // args to call task procedure with at startup
	int *pc;         // program counter for this task
	object_ptr expr_stack; // call stack for this task
	object_ptr expr_max;   // current top limit of stack
	object_ptr expr_limit; // don't start a new routine above this
	object_ptr expr_top;   // stack pointer
	int stack_size;        // current size of stack
};

// saved private blocks
struct private_block {
   int task_number;            // internal task number
   struct private_block *next; // pointer to next block
   object block[1];            // variable-length array of saved private data
};

#ifdef EUNIX
#define MAX_LINES 100
#define MAX_COLS 200
struct char_cell {
	char ascii;
	char fg_color;
	char bg_color;
};
#endif

#ifdef EUNIX
#ifdef EBSD
#include <limits.h>
#else
#include <linux/limits.h>
#endif
#else
#include <limits.h>
#endif

#ifdef PATH_MAX
#  define MAX_FILE_NAME PATH_MAX
#else
#  define MAX_FILE_NAME 255
#endif

#define CONTROL_C 3

#define COLOR_DISPLAY   (config.monitor != _MONO &&         \
						 config.monitor != _ANALOGMONO &&   \
						 config.mode != 7 && config.numcolors >= 16)

#define TEXT_MODE (config.numxpixels <= 80 || config.numypixels <= 80)

#define TEMP_SIZE 1040  // size of TempBuff - big enough for 1024 image

#define EXTRA_EXPAND(x) (4 + (x) + ((x) >> 2))

#define DEFAULT_SAMPLE_SIZE 25000

#define MAX_BITWISE_DBL ((double)(unsigned long)0xFFFFFFFF)
#define MIN_BITWISE_DBL ((double)(signed long)  0x80000000)

/* .dll argument & return value types */
#define C_TYPE     0x0F000000
#define C_DOUBLE   0x03000008
#define C_FLOAT    0x03000004
#define C_CHAR     0x01000001
#define C_UCHAR    0x02000001
#define C_SHORT    0x01000002
#define C_USHORT   0x02000002
#define E_INTEGER  0x06000004
#define E_ATOM     0x07000004
#define E_SEQUENCE 0x08000004
#define E_OBJECT   0x09000004

#define C_STDCALL 0
#define C_CDECL 1

// multitasking
#define ST_ACTIVE 0
#define ST_SUSPENDED 1
#define ST_DEAD 2

#define LOW_MEMORY_MAX ((unsigned)0x0010FFEF)
// It used to be ((unsigned)0x000FFFFF)
// but I found putsxy accessing ROM font above here 
// successfully on Millennium. It got the address from a DOS interrupt.

#define DOING_SPRINTF -9999999 // indicates sprintf rather than printf

/* Machine Operations - avoid renumbering existing constants */
#define M_COMPLETE            0  /* determine Complete Edition */
#define M_SOUND               1
#define M_LINE                2
#define M_PALETTE             3
#define M_PIXEL               4 // obsolete, but keep for now
#define M_GRAPHICS_MODE       5
#define M_CURSOR              6
#define M_WRAP                7
#define M_SCROLL              8
#define M_SET_T_COLOR         9
#define M_SET_B_COLOR        10
#define M_POLYGON            11
#define M_TEXTROWS           12
#define M_VIDEO_CONFIG       13
#define M_GET_MOUSE          14
#define M_MOUSE_EVENTS       15
#define M_ALLOC              16
#define M_FREE               17
#define M_ELLIPSE            18
#define M_SEEK               19
#define M_WHERE              20
#define M_GET_PIXEL          21 // obsolete, but keep for now
#define M_DIR                22
#define M_CURRENT_DIR        23
#define M_MOUSE_POINTER      24
#define M_GET_POSITION       25
#define M_WAIT_KEY           26
#define M_ALL_PALETTE        27
#define M_GET_DISPLAY_PAGE   28
#define M_SET_DISPLAY_PAGE   29
#define M_GET_ACTIVE_PAGE    30
#define M_SET_ACTIVE_PAGE    31
#define M_ALLOC_LOW          32
#define M_FREE_LOW           33
#define M_INTERRUPT          34
#define M_SET_RAND           35
#define M_USE_VESA           36
#define M_CRASH_MESSAGE      37
#define M_TICK_RATE          38
#define M_GET_VECTOR         39
#define M_SET_VECTOR         40
#define M_LOCK_MEMORY        41
#define M_ALLOW_BREAK        42
#define M_CHECK_BREAK        43
#define M_MEM_COPY           44 // obsolete, but keep for now
#define M_MEM_SET            45 // obsolete, but keep for now
#define M_A_TO_F64           46
#define M_F64_TO_A           47
#define M_A_TO_F32           48
#define M_F32_TO_A           49
#define M_OPEN_DLL           50
#define M_DEFINE_C           51
#define M_CALLBACK           52
#define M_PLATFORM           53 // obsolete, but keep for now
#define M_FREE_CONSOLE       54
#define M_INSTANCE           55
#define M_DEFINE_VAR         56
#define M_CRASH_FILE         57
#define M_GET_SCREEN_CHAR    58
#define M_PUT_SCREEN_CHAR    59
#define M_FLUSH              60
#define M_LOCK_FILE          61
#define M_UNLOCK_FILE        62
#define M_CHDIR              63
#define M_SLEEP              64
#define M_BACKEND            65
#define M_CRASH_ROUTINE      66
#define M_CRASH              67
#define M_PCRE_COMPILE       68
#define M_PCRE_FREE          69
#define M_PCRE_EXEC          70
#define M_WARNING_FILE       71
#define M_SET_ENV            72
#define M_UNSET_ENV          73
#define M_TO_NUMBER          74

enum CLEANUP_TYPES {
	CLEAN_UDT,
	CLEAN_PCRE
};
