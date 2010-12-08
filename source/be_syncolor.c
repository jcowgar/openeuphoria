/*****************************************************************************/
/*      (c) Copyright - See License.txt       */
/*****************************************************************************/
/*                                                                           */
/*                          Syntax Color                                     */
/*                                                                           */
/*****************************************************************************/

/* based on syncolor.e */

/******************/
/* Included files */
/******************/
#include <stdlib.h>
#include "be_w.h"
#include "alldefs.h"
#include "be_alloc.h"
#include "be_machine.h"
#include "be_syncolor.h"

unsigned internal_general_call_back(
		  int cb_routine,
						   unsigned arg1, unsigned arg2, unsigned arg3,
						   unsigned arg4, unsigned arg5, unsigned arg6,
						   unsigned arg7, unsigned arg8, unsigned arg9);

int syncolor = -1;

/*********************/
/* Defined functions */
/*********************/

void set_syncolor(object x)
{
	object syn;

	if IS_ATOM(x) {
		RTFatal("set_syncolor expected a sequence");
	}

	if (SEQ_PTR(x)->length != 1) {
		RTFatal("set_syncolor expected a sequence of length 1");
	}

	syn = get_pos_int("set_syncolor", SEQ_PTR(x)->base[1]);

	syncolor = (int)syn;
}

void init_class()
/* set up character classes for easier line scanning */
{
	/* since the Euphoria front end has its own version of this */
	/* and calls it upon initialization, we don't need it here. */
}

void DisplayColorLine(char *pline, int string_color)
/* Display a '\0'-terminated line with colors identifying the various
 * parts of the Euphoria language.
 * Each screen write has a lot of overhead, so we try to minimize
 * the number of them by collecting consecutive characters of the
 * same color into a 'segment' seg_start..seg_end.
 */
{
	int scolor;
	object line;

	scolor = get_pos_int("DisplayColorLine", string_color);
	line = NewString(pline);

	if (syncolor != -1)
	{
		internal_general_call_back(syncolor,
		line,string_color,0, 0,0,0, 0,0,0);
	}
	else
	{
		/* if we don't have the front end code **
		** then we fall back to outputing the line without color */
		screen_output(NULL, pline);
	}
}
