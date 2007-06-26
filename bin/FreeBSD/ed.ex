-- special version for FreeBSD
-- should try to merge with standard ed.ex for DOS/WIN/Linux

	----------------------------------------------------------
	--       This Euphoria Editor was developed by          --
	--            Rapid Deployment Software.                --
	--                                                      --
	-- Permission is freely granted to anyone to modify     --
	-- and/or redistribute this editor (ed.ex, syncolor.e). --
	----------------------------------------------------------

-- This program can be run with:
--     ex ed
-- or
--     exu ed.ex
-- or
--     exwc ed.ex (quicker response but some control-key combinations aren't recognized)
--
-- How it Works:
-- * Using gets(), ed reads and appends each line of text into a 2-d "buffer",
--   i.e. a sequence of sequences where each (sub)sequence contains one line.
-- * ed waits for you to press a key, and then fans out to one of many small
--   routines that each perform one editing operation.
-- * Each editing operation is responsible for updating the 2-d buffer variable
--   containing the lines of text, and for updating the screen to reflect any
--   changes. This code is typically fairly simple, but there can be a lot
--   of special cases to worry about.
-- * Finally, ed writes back each line, using puts()
-- * How multiple-windows works: When you switch to a new window, all the 
--   variables associated with the current window are bundled together and 
--   saved in a sequence, along with the 2-d text buffer for that window.
--   When you switch back, all of these state variables, plus the 2-d text
--   buffer variable for that window are restored. Most of the code in ed is 
--   not even "aware" that there can be multiple-windows.

without type_check -- makes it a bit faster

include graphics.e
include get.e
include file.e
include wildcard.e
include dll.e

constant TRUE = 1,
	 FALSE = 0

-- special input characters
constant CONTROL_B = 2,
	 CONTROL_C = 3,
	 CONTROL_D = 4,   -- alternate key for line-delete  
	 CONTROL_L = 12,
	 CONTROL_P = 16,  -- alternate key for PAGE-DOWN in Linux.
			  -- DOS uses this key for printing or something.
	 CONTROL_R = 18,
	 CONTROL_T = 20,
	 CONTROL_U = 21   -- alternate key for PAGE-UP in Linux

integer ESCAPE, CR, BS, HOME, END, CONTROL_HOME, CONTROL_END,
	PAGE_UP, PAGE_DOWN, INSERT, 
	DELETE, XDELETE, ARROW_LEFT, ARROW_RIGHT,
	CONTROL_ARROW_LEFT, CONTROL_ARROW_RIGHT, ARROW_UP, ARROW_DOWN,
	F1, F10, F11, F12, 
	CONTROL_DELETE  -- key for line-delete 
			-- (not available on some systems)
sequence delete_cmd, compare_cmd
integer SLASH
integer SAFE_CHAR -- minimum ASCII char that's safe to display
	 
if platform() = LINUX then
    SLASH = '/'
    SAFE_CHAR = 32
    delete_cmd = "rm "
    compare_cmd = "diff "
    ESCAPE = 27
    CR = 10
    BS = 8--127  --263
    HOME = 262 
    END = 360 
    CONTROL_HOME = CONTROL_T -- (top)
    CONTROL_END = CONTROL_B  -- (bottom)
    PAGE_UP = 339 
    PAGE_DOWN = 338 
    INSERT = 331
    DELETE = 127--330
    XDELETE = -999 -- 127 in xterm
    ARROW_LEFT = 260
    ARROW_RIGHT = 261
    CONTROL_ARROW_LEFT = CONTROL_L  -- (left)
    CONTROL_ARROW_RIGHT = CONTROL_R -- (right)
    ARROW_UP = 259
    ARROW_DOWN = 258
    F1 = 265
    F10 = 274
    F11 = 275
    F12 = 276
    CONTROL_DELETE = DELETE -- key for line-delete 
			    -- (not available on some systems)
else
    -- DOS/Windows
    SLASH = '\\'
    SAFE_CHAR = 14
    delete_cmd = "del "
    compare_cmd = "fc /T "
    ESCAPE = 27
    CR = 13
    BS = 8
    HOME = 327
    END = 335
    CONTROL_HOME = 375
    CONTROL_END = 373
    PAGE_UP = 329
    PAGE_DOWN = 337
    INSERT = 338
    DELETE = 339
    XDELETE = -999 -- never
    ARROW_LEFT = 331
    ARROW_RIGHT = 333
    CONTROL_ARROW_LEFT = 371
    CONTROL_ARROW_RIGHT = 372
    ARROW_UP = 328
    ARROW_DOWN = 336
    F1 = 315
    F10 = 324
    if platform() = WIN32 then
	F11 = 343
	F12 = 344
    else
	F11 = 389
	F12 = 390
    end if
    CONTROL_DELETE = 403 -- key for line-delete 
			 -- (not available on some systems)
end if



-------- START OF USER-MODIFIABLE PARAMETERS ---------------------------------- 

-- make your own specialized macro command(s):
constant CUSTOM_KEY = F12
constant CUSTOM_KEYSTROKES = HOME & "-- " & ARROW_DOWN

constant PROG_INDENT = 4  -- tab width for editing program source files
			  -- (tab width is 8 for other files)
-- Euphoria files:
constant E_FILES = {".e", ".ex", ".ew", ".exw", ".eu", ".exu", ".pro"}  
-- program indent files:
constant PROG_FILES = E_FILES & {".c", ".h", ".bas"} 

constant WANT_COLOR_SYNTAX  = TRUE -- FALSE if you don't want
				   -- color syntax highlighting

constant WANT_AUTO_COMPLETE = TRUE -- FALSE if you don't want 
				   -- auto-completion of Euphoria statements

constant HOT_KEYS = TRUE  -- FALSE if you want to hit Enter after each command

-- cursor style: 
constant ED_CURSOR = THICK_UNDERLINE_CURSOR
		     -- UNDERLINE_CURSOR
		     -- HALF_BLOCK_CURSOR
		     -- BLOCK_CURSOR
		   
-- number of lines on screen: (25,28,43 or 50)
constant INITIAL_LINES = 43,  -- when editor starts up
	 FINAL_LINES = 43     -- when editor is finished

-- colors
constant TOP_LINE_TEXT_COLOR = BLACK,
	 TOP_LINE_BACK_COLOR = BROWN, 
	 TOP_LINE_DIM_COLOR = BLUE,
	 BACKGROUND_COLOR = WHITE

-- colors needed by syncolor.e:
-- Adjust to suit your monitor and your taste.
global constant NORMAL_COLOR = BLACK,   -- GRAY might look better
		COMMENT_COLOR = RED,
		KEYWORD_COLOR = BLUE,
		BUILTIN_COLOR = MAGENTA,
		STRING_COLOR = GREEN,   -- BROWN might look better
		BRACKET_COLOR = {NORMAL_COLOR, YELLOW, BRIGHT_WHITE, 
				 BRIGHT_BLUE, BRIGHT_RED, BRIGHT_CYAN, 
				 BRIGHT_GREEN}

-- number of characters to shift left<->right when you move beyond column 80
constant SHIFT = 4   -- 1..78 should be ok

-- name of edit buffer temp file for Esc m command
constant TEMPFILE = "editbuff.tmp" 

-------- END OF USER-MODIFIABLE PARAMETERS ------------------------------------


-- Special keys that we can handle. Some are duplicates.
-- If you add more, you should list them here:
constant SPECIAL_KEYS = {ESCAPE, BS, DELETE, XDELETE, PAGE_UP, PAGE_DOWN,
			 CONTROL_P, CONTROL_U, CONTROL_T, CONTROL_B,
			 CONTROL_R, CONTROL_L,
			 INSERT, CONTROL_DELETE, 
			 CONTROL_D, ARROW_LEFT, ARROW_RIGHT, ARROW_UP, 
			 ARROW_DOWN, CONTROL_ARROW_LEFT, CONTROL_ARROW_RIGHT,
			 HOME, END, CONTROL_HOME, CONTROL_END,
			 F1, F1+1, F1+2, F1+3, F1+4, F1+5,
			 F1+6, F1+7, F1+8, F10, CUSTOM_KEY}

-- output device:
constant SCREEN = 1

constant CONTROL_CHAR = 254 -- change funny control chars to this

constant STANDARD_TAB_WIDTH = 8

constant MAX_WINDOWS = 10 -- F1..F10

type boolean(integer x)
    return x = TRUE or x = FALSE
end type

type natural(integer x)
    return x >= 0
end type

type positive_int(integer x)
    return x >= 1
end type

sequence buffer -- In-memory buffer where the file is manipulated.
-- This is a sequence where each element is a sequence
-- containing one line of text. Each line of text ends with '\n'

positive_int screen_length  -- number of lines on physical screen
positive_int screen_width

global sequence BLANK_LINE 

positive_int window_base    -- location of first line of current window 
			    -- (status line)
window_base = 1
positive_int window_length  -- number of lines of text in current window

sequence window_list -- state info for all windows
window_list = {0}

sequence buffer_list -- all buffers
buffer_list = {}

type window_id(integer x)
    return x >= 1 and x <= length(window_list)
end type

type buffer_id(integer x)
    return x >= 0 and x <= length(buffer_list)
end type

type window_line(integer x)
-- a valid line in the current window
    return x >= 1 and x <= window_length
end type

type screen_col(integer x)
-- a valid column on the screen
    return x >= 1 
end type

type buffer_line(integer x)
-- a valid buffer line
    return (x >= 1 and x <= length(buffer)) or x = 1
end type

type char(integer x)
-- a character (including special key codes)
    return x >= 0 and x <= 511
end type

type extended_char(integer x)
    return char(x) or x = -1
end type

type file_number(integer x)
    return x >= -1
end type

sequence file_name   -- name of the file that we are editing

-- These are the critical state variables that all editing operations
-- must update:
buffer_line  b_line  -- current line in buffer
positive_int b_col   -- current character within line in buffer
window_line  s_line  -- line on screen corresponding to b_line
screen_col   s_col   -- column on screen corresponding to b_col
natural s_shift      -- how much the screen has been shifted (for >80)
s_shift = 0

boolean stop         -- indicates when to stop processing current buffer

sequence kill_buffer -- kill buffer of deleted lines or characters
kill_buffer = {}

boolean adding_to_kill  -- TRUE if still accumulating deleted lines/chars

boolean multi_color     -- use colors for keywords etc.
boolean auto_complete   -- perform auto completion of statements
boolean dot_e           -- TRUE if this is a .e/.ex file
boolean modified        -- TRUE if file has been modified

boolean editbuff        -- TRUE if temp file exists (Esc m)
editbuff = FALSE

atom buffer_version,    -- version of buffer contents
     my_buffer_version  -- last version used by current window

boolean control_chars,  -- binary file - view but don't save
	cr_removed      -- Linux: CR's were removed from DOS file (CR-LF)

natural start_line, start_col

sequence error_message

sequence file_history, command_history, search_history, replace_history
file_history = {}
command_history = {}
search_history = {}
replace_history = {}

sequence config -- video configuration

window_id window_number -- current active window
window_number = 1

buffer_id buffer_number -- current active buffer
buffer_number = 0

sequence key_queue -- queue of input characters forced by ed
key_queue = {}

procedure delay(atom n)
-- an n second pause while a message is on the screen
    atom t

    t = time()
    while time() < t + n do
    end while
end procedure

procedure set_modified()
-- buffer differs from file
    modified = TRUE
    cursor(NO_CURSOR) -- hide cursor while we update the screen
    buffer_version += 1
end procedure

procedure clear_modified()
-- buffer is now same as file
    modified = FALSE
end procedure


natural edit_tab_width 

function tab(natural tab_width, positive_int pos)
-- compute new column position after a tab
    return (floor((pos - 1) / tab_width) + 1) * tab_width + 1
end function

function expand_tabs(natural tab_width, sequence line)
-- replace tabs by blanks in a line of text
    natural tab_pos, column, ntabs

    column = 1
    while TRUE do
	tab_pos = find('\t', line[column..length(line)])
	if tab_pos = 0 then
	    -- no more tabs
	    return line
	else
	    tab_pos += column - 1
	end if
	column = tab(tab_width, tab_pos)
	ntabs = 1
	while line[tab_pos+ntabs] = '\t' do
	    ntabs += 1
	    column += tab_width
	end while
	-- replace consecutive tabs by blanks
	line = line[1..tab_pos-1] & 
	       repeat(' ', column - tab_pos) &
	       line[tab_pos+ntabs..length(line)]            
    end while
end function

function indent_tabs(natural tab_width, sequence line)
-- replace leading blanks of a line with tabs
    natural i, blanks

    if length(line) < tab_width then
	return line
    end if
    i = 1
    while line[i] = ' ' do
	i += 1
    end while    
    blanks = i - 1    
    return repeat('\t', floor(blanks / tab_width)) & 
	   BLANK_LINE[1..remainder(blanks, tab_width)] &
	   line[i..length(line)]
end function

function convert_tabs(natural old_width, natural new_width, sequence line)
-- retabulate a line for a new tab size
    if old_width = new_width then
	return line
    end if
    return indent_tabs(new_width, expand_tabs(old_width, line))
end function

-- color display of lines
include syncolor.e

procedure reverse_video()
-- start inverse video
    text_color(TOP_LINE_TEXT_COLOR)
    bk_color(TOP_LINE_BACK_COLOR)
end procedure

procedure normal_video()
-- end inverse video
    text_color(NORMAL_COLOR)
    bk_color(BACKGROUND_COLOR)
end procedure

procedure ClearLine(window_line sline)
-- clear the current line on screen
    scroll(1, window_base + sline, window_base + sline)
end procedure

procedure ClearWindow()
-- clear the current window
    scroll(window_length, window_base+1, window_base+window_length)
end procedure

procedure ScrollUp(positive_int top, positive_int bottom)
-- move text up one line on screen
    scroll(+1, window_base + top, window_base + bottom)
end procedure

procedure ScrollDown(positive_int top, positive_int bottom)
-- move text down one line on screen
    scroll(-1, window_base + top, window_base + bottom)
end procedure

procedure set_absolute_position(natural window_line, positive_int column)
-- move cursor to a line and an absolute (non-shifted) column within
-- the current window
    position(window_base + window_line, column)
end procedure

procedure DisplayLine(buffer_line bline, window_line sline, boolean all_clear)
-- display a buffer line on a given line on the screen
    sequence this_line, color_line, text
    natural last, last_pos, color, len
    
    this_line = expand_tabs(edit_tab_width, buffer[bline])
    last = length(this_line) - 1
    set_absolute_position(sline, 1)
    if multi_color then
	-- color display
	color_line = SyntaxColor(this_line)
	last_pos = 0
	
	for i = 1 to length(color_line) do
	    -- display the next colored text segment
	    color = color_line[i][1]
	    text = color_line[i][2]
	    len = length(text)
	    if last_pos >= s_shift then
		text_color(color)
		puts(SCREEN, text)
	    elsif last_pos+len > s_shift then
		-- partly left-of-screen
		text_color(color)
		puts(SCREEN, text[1+(s_shift-last_pos)..len])
		last_pos += len
	    else
		-- left-of-screen
		last_pos += len
	    end if
	end for
    else
	-- monochrome display
	if last > s_shift then
	    puts(SCREEN, this_line[1+s_shift..last])
	end if
    end if
    if last-s_shift > screen_width then
	-- line extends beyond right margin 
	set_absolute_position(sline, screen_width)
	text_color(BACKGROUND_COLOR)
	bk_color(NORMAL_COLOR)
	puts(SCREEN, this_line[screen_width+s_shift])
	normal_video()
    elsif not all_clear then
	puts(SCREEN, BLANK_LINE)
    end if
end procedure

--without warning
procedure DisplayWindow(positive_int bline, window_line sline)
-- print a series of buffer lines, starting at sline on screen
-- and continue until the end of screen, or end of buffer
    boolean all_clear
    
    if sline = 1 then 
	ClearWindow()
	all_clear = TRUE
    else
	all_clear = FALSE
    end if

    for b = bline to length(buffer) do
	DisplayLine(b, sline, all_clear)
	if sline = window_length then
	    return
	else
	    sline += 1
	end if
    end for
    -- blank any remaining screen lines after end of file
    for s = sline to window_length do
	ClearLine(s)
    end for
end procedure
with warning

procedure set_position(natural window_line, positive_int column)
-- Move cursor to a logical screen position within the window.
-- The window will be shifted left<->right if necessary.
-- window_line 0 is status line, window_line 1 is first line of text
    natural s
    
    if window_line = 0 then
	-- status line
	position(window_base + window_line, column)
    else
	s = s_shift
	while column-s_shift > screen_width do
	    s_shift += SHIFT
	end while
	while column-s_shift < 1 do
	    s_shift -= SHIFT
	end while
	if s_shift != s then
	    -- display shifted window
	    DisplayWindow(b_line - s_line + 1, 1)
	end if
	position(window_base + window_line, column-s_shift)
    end if
end procedure

without warning
function clean(sequence line)
-- replace control characters with a graphics character
-- Linux: replace CR-LF with LF (for now)
    integer c
    
    for i = 1 to length(line) do
	c = line[i]
	if c < SAFE_CHAR and c != '\n' and c != '\t' then
	    if c != '\r' or platform() != LINUX then
		line[i] = CONTROL_CHAR  -- replace with displayable character
		control_chars = TRUE
	    end if
	end if
    end for
    if line[length(line)] != '\n' then
	line &= '\n'
    end if
    if platform() = LINUX and 
       length(line) > 1 and 
       line[length(line)-1] = '\r' then
       -- DOS file: remove CR
       cr_removed = TRUE
       line = line[1..length(line)-2] & '\n'
    end if
    return line
end function
with warning

function add_line(file_number file_no)
-- add a new line to the buffer
    object line

    line = gets(file_no)
    
    if atom(line) then
	-- end of file
	return FALSE 
    end if
    
    line = convert_tabs(STANDARD_TAB_WIDTH, edit_tab_width, clean(line))
    buffer = append(buffer, line)
    return TRUE
end function

procedure new_buffer()
-- make room for a new (empty) buffer
    buffer_list &= 0 -- place holder for new buffer
    buffer_number = length(buffer_list) 
    buffer = {}
end procedure

procedure read_file(file_number file_no)
-- read the entire file into buffer variable
    
    -- read and immediately display the first screen-full
    for i = 1 to window_length do
	if not add_line(file_no) then
	    exit
	end if
    end for
    DisplayWindow(1, 1)

    -- read the rest
    while add_line(file_no) do
    end while

end procedure

procedure set_top_line(sequence message)
-- print message on top line
    set_position(0, 1)
    reverse_video()
    puts(SCREEN, message & BLANK_LINE)
    set_position(0, length(message)+1)
end procedure

procedure arrow_right()
-- action for right arrow key

    if b_col < length(buffer[b_line]) then
	if buffer[b_line][b_col] = '\t' then
	    s_col = tab(edit_tab_width, s_col)
	else
	    s_col += 1
	end if
	b_col += 1
    end if
end procedure

procedure arrow_left()
-- action for left arrow key

    positive_int old_b_col

    old_b_col = b_col
    b_col = 1
    s_col = 1
    for i = 1 to old_b_col - 2 do
	arrow_right()
    end for
end procedure
	
procedure skip_white()
-- set cursor to first non-whitespace in line    
    positive_int temp_col
    
    while find(buffer[b_line][b_col], " \t") do
	temp_col = s_col
	arrow_right()
	if s_col = temp_col then
	    return -- can't move any further right
	end if
    end while
end procedure

procedure goto_line(integer new_line, integer new_col)
-- move to a specified line and column
-- refresh screen if line is 0
    integer new_s_line
    boolean refresh

    if length(buffer) = 0 then
	ClearWindow()
	s_line = 1
	s_col = 1
	return
    end if
    if new_line = 0 then
	new_line = b_line
	refresh = TRUE
    else
	refresh = FALSE
    end if
    if new_line < 1 then
	new_line = 1
    elsif new_line > length(buffer) then
	new_line = length(buffer)
    end if
    new_s_line = new_line - b_line + s_line
    b_line = new_line
    if not refresh and window_line(new_s_line) then
	-- new line is on the screen
	s_line = new_s_line
    else
	-- new line is off the screen, or refreshing
	s_line = floor((window_length+1)/2)
	if s_line > b_line or length(buffer) < window_length then
	    s_line = b_line
	elsif b_line > length(buffer) - window_length + s_line then
	    s_line = window_length - (length(buffer) - b_line)
	end if
	DisplayWindow(b_line - s_line + 1, 1)
    end if
    b_col = 1
    s_col = 1
    for i = 1 to new_col-1 do
	arrow_right()
    end for
    set_position(s_line, s_col)
end procedure

function plain_text(char c)
-- defines text for next_word, previous_word 
    return (c >= '0' and c <= '9') or
	   (c >= 'A' and c <= 'Z') or
	   (c >= 'a' and c <= 'z') or
	   c = '_'
end function

procedure next_word()
-- move to start of next word in line
    char c
    positive_int col
	
    -- skip plain text
    col = b_col
    while TRUE do
	c = buffer[b_line][col]
	if not plain_text(c) then
	    exit
	end if
	col += 1
    end while
    
    -- skip white-space and punctuation
    while c != '\n' do
	c = buffer[b_line][col]
	if plain_text(c) then
	    exit
	end if
	col += 1
    end while
    goto_line(b_line, col)
end procedure

procedure previous_word()
-- move to start of previous word in line    
    char c
    natural col
    
    -- skip white-space & punctuation
    col = b_col - 1
    while col > 1 do
	c = buffer[b_line][col]
	if plain_text(c) then
	    exit
	end if
	col -= 1
    end while

    -- skip plain text
    while col > 1 do
	c = buffer[b_line][col-1]
	if not plain_text(c) then
	    exit
	end if
	col -= 1
    end while

    goto_line(b_line, col)
end procedure


procedure arrow_up()
-- action for up arrow key

    b_col = 1
    s_col = 1
    if b_line > 1 then
	b_line -= 1
	if s_line > 1 then
	    s_line -= 1
	else
	    -- move all lines down, display new line at top
	    ScrollDown(1, window_length)
	    DisplayLine(b_line, 1, TRUE)
	    set_position(1, 1)
	end if
	skip_white()
    end if
end procedure

procedure arrow_down()
-- action for down arrow key
    b_col = 1
    s_col = 1
    if b_line < length(buffer) then
	b_line += 1
	if s_line < window_length then
	    s_line += 1
	else
	    -- move all lines up, display new line at bottom
	    ScrollUp(1, window_length)
	    DisplayLine(b_line, window_length, TRUE)
	end if
	skip_white()
    end if
end procedure

function numeric(sequence string)
-- convert digit string to an integer
    atom n

    n = 0
    for i = 1 to length(string) do
	if string[i] >= '0' and string[i] <= '9' then
	    n = n * 10 + string[i] - '0'
	    if not integer(n) then
		return 0
	    end if
	else
	    exit
	end if
    end for
    return n
end function

procedure page_down()
-- action for page-down key
    buffer_line prev_b_line

    if length(buffer) <= window_length then
	return
    end if
    prev_b_line = b_line
    b_col = 1
    s_col = 1
    if b_line + window_length + window_length - s_line <= length(buffer) then
	b_line = b_line + window_length
    else
	b_line = length(buffer) - (window_length - s_line)
    end if
    if b_line != prev_b_line then
	DisplayWindow(b_line - s_line + 1, 1)
    end if
end procedure

procedure page_up()
-- action for page-up key
    buffer_line prev_b_line

    if length(buffer) <= window_length then
	return
    end if
    prev_b_line = b_line
    b_col = 1
    s_col = 1
    if b_line - window_length >= s_line then
	b_line = b_line - window_length
    else
	b_line = s_line
    end if
    if b_line != prev_b_line then
	DisplayWindow(b_line - s_line + 1, 1)
    end if
end procedure

procedure set_f_line(natural w, sequence comment)
-- show F-key & file_name
    sequence f_key, text
    
    if length(window_list) = 1 then
	f_key = ""
    elsif w = 10 then
	f_key = "F10: "
    else
	f_key = 'F' & ('0' + w) & ": "
    end if
    set_top_line("")
    puts(SCREEN, ' ' & f_key & file_name & comment)
    text = "Esc for commands"
    set_position(0, screen_width - length(text))
    puts(SCREEN, text)
end procedure

constant W_BUFFER_NUMBER = 1,
	 W_MY_BUFFER_VERSION = 2,
	 W_WINDOW_BASE = 3,
	 W_WINDOW_LENGTH = 4,
	 W_B_LINE = 11

procedure save_state()
-- save current state variables for a window
    window_list[window_number] = {buffer_number, buffer_version, window_base, 
				  window_length, auto_complete, multi_color, 
				  dot_e, control_chars, cr_removed, file_name, 
				  b_line, b_col, s_line, s_col, s_shift, 
				  edit_tab_width}
    buffer_list[buffer_number] = {buffer, modified, buffer_version}
end procedure

procedure restore_state(window_id w)
-- restore state variables for a window
    sequence state
    sequence buffer_info

    -- set up new buffer
    state = window_list[w]
    window_number = w
    buffer_number =  state[W_BUFFER_NUMBER]
    buffer_info = buffer_list[buffer_number]
    buffer = buffer_info[1]
    modified = buffer_info[2]
    buffer_version = buffer_info[3]
    buffer_list[buffer_number] = 0 -- save space
    
    -- restore other variables
    my_buffer_version = state[2]
    window_base = state[3]
    window_length = state[4]
    auto_complete = state[5]
    multi_color = state[6]
    dot_e = state[7]
    control_chars = state[8]
    cr_removed = state[9]
    file_name = state[10]
    edit_tab_width = state[16]
    set_f_line(w, "")
    normal_video()
    if buffer_version != my_buffer_version then
	-- buffer has changed since we were last in this window
	-- or window size has changed
	if state[W_B_LINE] > length(buffer) then
	    if length(buffer) = 0 then
		b_line = 1
	    else
		b_line = length(buffer)
	    end if
	else
	    b_line = state[W_B_LINE]
	end if
	s_shift = 0
	goto_line(0, 1)
    else
	b_line = state[W_B_LINE]
	b_col = state[12]
	s_line = state[13]
	s_col = state[14]
	s_shift = state[15]
	set_position(s_line, s_col)
    end if
end procedure

procedure refresh_other_windows(positive_int w)
-- redisplay all windows except w
    
    normal_video()
    for i = 1 to length(window_list) do
	if i != w then
	    restore_state(i)
	    set_f_line(i, "")
	    normal_video()
	    goto_line(0, b_col)
	    save_state()
	end if
    end for
end procedure

procedure set_window_size()
-- set sizes for windows
    natural nwindows, lines, base, size
    
    nwindows = length(window_list)
    lines = screen_length - nwindows
    base = 1
    for i = 1 to length(window_list) do
	size = floor(lines / nwindows)
	window_list[i][W_WINDOW_BASE] = base
	window_list[i][W_WINDOW_LENGTH] = size
	window_list[i][W_MY_BUFFER_VERSION] = -1 -- force redisplay
	base += size + 1
	nwindows -= 1
	lines -= size
    end for
end procedure

procedure clone_window()
-- set up a new window that is a clone of the current window
-- save state of current window
    window_id w
    
    if length(window_list) >= MAX_WINDOWS then
	return
    end if
    save_state()
    -- create a place for new window
    window_list = window_list[1..window_number] & 
		  {window_list[window_number]} &  -- the new clone window
		  window_list[window_number+1..length(window_list)]
    w = window_number + 1
    set_window_size()
    refresh_other_windows(w)
    restore_state(w) 
end procedure

procedure switch_window(integer new_window_number)
-- switch context to a new window on the screen
    
    if new_window_number != window_number then
	save_state()
	restore_state(new_window_number)
    end if
end procedure

function delete_window()
-- delete the current window    
    boolean buff_in_use
    
    buffer_list[buffer_number] = {buffer, modified, buffer_version}
    window_list = window_list[1..window_number-1] & 
		  window_list[window_number+1..length(window_list)]
    buff_in_use = FALSE
    for i = 1 to length(window_list) do
	if window_list[i][W_BUFFER_NUMBER] = buffer_number then
	    buff_in_use = TRUE
	    exit
	end if
    end for 
    if not buff_in_use then
	buffer_list[buffer_number] = 0 -- discard the buffer
    end if
    if length(window_list) = 0 then
	return TRUE
    end if
    set_window_size()
    refresh_other_windows(1)
    window_number = 1
    restore_state(window_number)
    set_position(s_line, s_col)
    return FALSE
end function

procedure add_queue(sequence keystrokes)
-- add to artificial queue of keystrokes
    key_queue &= keystrokes
end procedure

function next_key()
-- return the next key from the user, or from our 
-- artificial queue of keystrokes. Check for control-c.
    extended_char c, c2
    
    if length(key_queue) then
	-- read next artificial keystroke
	c = key_queue[1]
	key_queue = key_queue[2..length(key_queue)]
    else
	-- read a new keystroke from user
	c = wait_key()
	if check_break() then
	    c = CONTROL_C
	end if
	if c = ESCAPE then
	    -- process escape sequence
	    c = get_key()
	    
	    if c = -1 then
		return ESCAPE -- it was just the Esc key

	    elsif c = 79 then
		c = wait_key()
		if c = 0 then
		    return HOME
		elsif c = 101 then
		    return END
		elsif c = 80 then
		    return F1
		elsif c = 81 then
		    return F1+1 -- F2
		elsif c = 82 then
		    return F1+2 -- F3
		elsif c = 83 then
		    return F1+3 -- F4
		else
		    add_queue({79, c})
		end if

	    elsif c = 91 then
		c = get_key() 

		if c >= 65 and c <= 68 then
		    if c = 65 then
			return ARROW_UP
		    elsif c = 66 then
			return ARROW_DOWN
		    elsif c = 67 then
			return ARROW_RIGHT
		    else
			return ARROW_LEFT
		    end if

		elsif c >= 49 and c <= 54 then
		    c2 = get_key()
		    if c = 49 then 
			if c2 = 126 then
			    return INSERT
			elsif c2 >= 49 and c2 <= 53 then
			    if get_key() then --126
			    end if
			    return F1+c2-49
			elsif c2 >= 55 and c2 <= 57 then
			    if get_key() then -- 126
			    end if
			    return F1+c2-50
			end if
		    elsif c = 50 then
			if c2 = 126 then
			    return HOME
			elsif c2 >= 48 and c2 <= 52 then
			    if get_key() then -- 126
			    end if
			    -- F11,F12 are not totally standard
			    if c2 = 51 then
				return F11 -- some systems
			    elsif c2 = 52 then
				return F12 -- some systems
			    else
				return F1+c2-40 -- other systems
			    end if
			end if
		    elsif c = 51 then
			return PAGE_UP
		    elsif c = 52 then
			return END
		    elsif c = 53 then
			return END
		    elsif c = 54 then
			return PAGE_DOWN
		    else
			-- F1..F4 might overlap with the above special keys
			return F1+c-49  
		    end if
		
		elsif c = 72 then
		    return HOME
		
		elsif c = 70 then
		    return END
		
		else -- obsolete?
		    c = get_key()
		    if get_key() then -- 126
		    end if
		    add_queue({91, 49, c, 126})
		end if
	    else
		add_queue({c})
	    end if
	    return ESCAPE
	end if
    end if
    return c
end function

procedure refresh_all_windows()
-- redisplay all the windows
    window_id w

    w = window_number
    save_state()
    refresh_other_windows(w)
    restore_state(w)
end procedure

function key_gets(sequence hot_keys, sequence history)
-- Return an input string from the keyboard.
-- Handles special editing keys. 
-- Some keys are "hot" - no Enter required.
-- A list of "history" strings can be supplied,
-- and accessed by the user using up/down arrow.
    sequence input_string
    integer line, init_column, column, char, col, h
    sequence cursor
    boolean first_key
   
    if not HOT_KEYS then
	hot_keys = ""
    end if
    cursor = get_position()
    line = cursor[1]
    init_column = cursor[2]
    history = append(history, "")
    h = length(history)
    if h > 1 then
       h -= 1  -- start by offering the last choice
    end if
    input_string = history[h]
    column = init_column
    first_key = TRUE
    
    while TRUE do
	position(line, init_column)
	puts(SCREEN, input_string)
	puts(SCREEN, BLANK_LINE)
	position(line, column)
	
	char = next_key()
	
	if char = CR or char = 10 then
	    exit
	    
	elsif char = BS then
	    if column > init_column then
		column -= 1
		col = column-init_column
		input_string = input_string[1..col] & 
			       input_string[col+2..length(input_string)]
	    end if
	
	elsif char = ARROW_LEFT then
	    if column > init_column then
		column -= 1
	    end if
	
	elsif char = ARROW_RIGHT then
	    if column < init_column+length(input_string) and
	       column < screen_width then
		column += 1
	    end if      
	
	elsif char = ARROW_UP then
	    if h > 1 then
		h -= 1
	    else
		h = length(history)
	    end if
	    input_string = history[h]
	    column = init_column + length(input_string)
	
	elsif char = ARROW_DOWN then
	    if h < length(history) then
		h += 1
	    else
		h = 1
	    end if
	    input_string = history[h]
	    column = init_column + length(input_string)
	    
	elsif char = DELETE or char = XDELETE then
	    if column - init_column < length(input_string) then
		col = column-init_column
		input_string = input_string[1..col] & 
			       input_string[col+2..length(input_string)]
	    end if
	
	elsif char = HOME then
	    column = init_column
	    
	elsif char = END then
	    column = init_column+length(input_string)
		
	elsif (char >= 32 and char <= 255) or char = '\t' then
	    -- normal key
	    if first_key then
		input_string = ""
	    end if
	    if column < screen_width then
		if char = '\t' then
		    char = ' '
		end if
		column += 1
		if column - init_column > length(input_string) then
		    input_string = append(input_string, char)
		    if column = init_column + 1 and find(char, hot_keys) then
			exit
		    end if
		else
		    col = column-init_column
		    input_string = input_string[1..col-1] &
				   char &
				   input_string[col..length(input_string)]
		end if
	    end if
	
	elsif char = CONTROL_C then
	    -- refresh screen, treat as Enter key
	    refresh_all_windows()
	    goto_line(0, b_col)
	    input_string &= CR
	    exit
	end if
	
	first_key = FALSE
    end while
    
    return input_string
end function

procedure new_screen_length()
-- set new number of lines on screen
    natural nlines
    window_id w
    
    set_top_line("How many lines on screen? (25, 28, 43, 50) ")
    nlines = numeric(key_gets("", {}))
    if nlines then
	screen_length = text_rows(nlines)
	if screen_length != nlines then
	    sound(500)
	end if
	w = window_number
	save_state()
	set_window_size()
	refresh_other_windows(w)
	restore_state(w)
	if screen_length != nlines then
	    sound(0)
	end if
    end if
end procedure


-- searching/replacing variables
boolean searching, replacing, match_case
searching = FALSE
replacing = FALSE
match_case = TRUE

sequence find_string -- current (default) string to look for
find_string = ""

sequence replace_string -- current (default) string to replace with
replace_string = ""

procedure replace()
-- replace find_string by replace_string
-- we are currently positioned at the start of an occurrence of find_string
    sequence line

    set_modified()
    line = buffer[b_line]
    line = line[1..b_col-1] & replace_string & line[b_col+length(find_string)..
						length(line)]
    buffer[b_line] = line
    -- position at end of replacement string
    for i = 1 to length(replace_string)-1 do
	arrow_right()
    end for
    DisplayLine(b_line, s_line, FALSE)
end procedure

function alphabetic(object s)
-- does s contain alphabetic characters?
    return find(TRUE, (s >= 'A' and s <= 'Z') or
		      (s >= 'a' and s <= 'z')) 
end function

function case_match(sequence string, sequence text)
-- Find string in text with
-- either case-sensitive or non-case-sensitive comparison
    if match_case then
	return match(string, text)
    else
	return match(lower(string), lower(text))
    end if
end function

function update_history(sequence history, sequence string)
-- update a history variable - string will be placed at the end
    integer f
    
    f = find(string, history) 
    if f then
	-- delete it
	history = history[1..f-1] & history[f+1..length(history)]
    end if
    -- put it at the end
    return append(history, string)
end function

function search(boolean continue)
-- find a string from here to the end of the file
-- return TRUE if string is found
    natural col
    sequence pos, temp_string
    
    set_top_line("")
    if length(buffer) = 0 then
	puts(SCREEN, "buffer empty")
	return FALSE
    end if
    puts(SCREEN, "searching for: ")
    if continue then
	puts(SCREEN, find_string)
    else
	pos = get_position()
	temp_string = find_string
	find_string = key_gets("", search_history)
	if length(find_string) > 0 then
	    if not equal(temp_string, find_string) then
		-- new string typed in
		search_history = update_history(search_history, find_string)
		if alphabetic(find_string) and length(find_string) < 40 then
		    set_position(0, pos[2]+length(find_string)+3)
		    puts(SCREEN, "match case? n")
		    pos = get_position()
		    set_position(0, pos[2] - 1)
		    match_case = find('y', key_gets("", {}))
		end if
	    end if
	    if replacing then
		set_top_line("")
		puts(SCREEN, "replace with: ")
		replace_string = key_gets("", replace_history)
		replace_history = update_history(replace_history, 
						 replace_string)
	    end if
	end if
    end if

    normal_video()
    if length(find_string) = 0 then
	return FALSE
    end if
    col = case_match(find_string, buffer[b_line][b_col+1..length(buffer[b_line])])
    if col then
	-- found it on this line after current position
	for i = 1 to col do
	    arrow_right()
	end for
	if replacing then
	    replace()
	end if
	return TRUE
    else
	-- check lines following this one
	for b = b_line+1 to length(buffer) do
	    col = case_match(find_string, buffer[b])
	    if col then
		goto_line(b, 1)
		for i = 1 to col - 1 do
		   arrow_right()
		end for
		if replacing then
		    replace()
		end if
		set_top_line("")
		printf(SCREEN, "searching for: %s", {find_string})
		return TRUE
	    end if
	end for
	set_top_line("")
	printf(SCREEN, "\"%s\" not found", {find_string})
	if alphabetic(find_string) then
	    if match_case then
		puts(SCREEN, "  (case must match)")
	    else
		puts(SCREEN, "  (any case)")
	    end if
	end if
    end if
    return FALSE
end function

procedure show_message()
-- display error message from ex.err
    if length(error_message) > 0 then
	set_top_line("")
	puts(SCREEN, error_message)
	normal_video()
    end if
    set_position(s_line, s_col)
end procedure

procedure set_err_pointer()
-- set cursor at point of error 
    
    for i = 1 to screen_width*5 do -- prevents infinite loop
	if s_col >= start_col then
	    exit
	end if
	arrow_right()
    end for
end procedure

function delete_trailing_white(sequence name)
-- get rid of blanks, tabs, newlines at end of string
    while length(name) > 0 do
	if find(name[length(name)], "\n\r\t ") then
	    name = name[1..length(name)-1]
	else
	    exit
	end if
    end while
    return name
end function

function get_err_line()
-- try to get file name & line number from ex.err
-- returns file_name, sets start_line, start_col, error_message

    file_number err_file
    sequence file_name
    sequence err_lines
    object temp_line
    natural colon_pos

    err_file = open("ex.err", "r")
    if err_file = -1 then
	error_message = ""
    else
	-- read the top of the ex.err error message file
	err_lines = {}
	while length(err_lines) < 5 do
	    temp_line = gets(err_file)
	    if atom(temp_line) then
		exit
	    end if
	    err_lines = append(err_lines, temp_line)
	end while
	close(err_file)
	-- look for file name, line, column and error message
	if length(err_lines) > 0 then
	    if sequence(err_lines[1]) then
		colon_pos = match(".e", lower(err_lines[1]))
		if colon_pos then
		    if find(err_lines[1][colon_pos+2], "xXwWuU") then
			colon_pos += 1
			if find(err_lines[1][colon_pos+2], "wWuU") then
			    colon_pos += 1
			end if
		    end if
		    file_name = err_lines[1][1..colon_pos+1]
		    start_line = numeric(err_lines[1][colon_pos+3..
							  length(err_lines[1])])
		    error_message = delete_trailing_white(err_lines[2])
		    if length(err_lines) > 3 then
			start_col = find('^', expand_tabs(STANDARD_TAB_WIDTH, 
					      err_lines[length(err_lines)-1]))
		    end if
		    return file_name
		end if
	    end if
	end if
    end if
    return ""
end function

function last_use()
-- return TRUE if current buffer 
-- is only referenced by the current window
    natural count

    count = 0
    for i = 1 to length(window_list) do
	if window_list[i][W_BUFFER_NUMBER] = buffer_number then
	    count += 1
	    if count = 2 then
		return FALSE
	    end if
	end if
    end for
    return TRUE
end function


procedure save_file(sequence save_name)
-- write buffer to the disk file
    file_number file_no
    boolean strip_cr
    sequence line
    
    if control_chars then
	set_top_line("")
	printf(SCREEN, "%s: control chars were changed to " & CONTROL_CHAR &
		       " - save anyway? ", {save_name})
	if not find('y', key_gets("yn", {})) then
	    stop = FALSE
	    return
	end if
    end if
    strip_cr = FALSE
    if cr_removed then
	set_top_line("")
	printf(SCREEN, "%s: Convert CR-LF (DOS-style) to LF (Linux-style)? ", 
		     {save_name})
	strip_cr = find('y', key_gets("yn", {}))
    end if
    set_top_line("")
    file_no = open(save_name, "w")
    if file_no = -1 then
	printf(SCREEN, "Can't save %s - write permission denied", 
	      {save_name})
	stop = FALSE
	return
    end if
    printf(SCREEN, "saving %s ... ", {save_name})
    for i = 1 to length(buffer) do
	line = buffer[i]
	if cr_removed and not strip_cr then
	    -- He wants CR's - put them back.
	    -- All lines have \n at the end.
	    if length(line) < 2 or line[length(line)-1] != '\r' then
		line = line[1..length(line)-1] & "\r\n"
	    end if
	end if
	puts(file_no, convert_tabs(edit_tab_width, STANDARD_TAB_WIDTH, line))
    end for
    close(file_no)
    if strip_cr then
	-- the file doesn't have CR's
	cr_removed = FALSE 
    end if
    puts(SCREEN, "ok")
    if equal(save_name, file_name) then
	clear_modified()
    end if
    stop = TRUE
end procedure

procedure shell(sequence command)
-- run an external command
    
    bk_color(BLACK)
    text_color(WHITE)
    clear_screen()
    system(command, 1)
    normal_video()
    while get_key() != -1 do
	-- clear the keyboard buffer
    end while
    refresh_all_windows()
end procedure

procedure first_bold(sequence string)
-- highlight first char
    text_color(TOP_LINE_TEXT_COLOR)
    puts(SCREEN, string[1])
    text_color(TOP_LINE_DIM_COLOR)
    puts(SCREEN, string[2..length(string)])
end procedure

procedure delete_editbuff()
-- Shutting down. Delete EDITBUFF.TMP
    if editbuff then
	system(delete_cmd & TEMPFILE, 2)
    end if
end procedure

procedure get_escape(boolean help)
-- process escape command
    sequence command, answer
    natural line
    object self_command

    cursor(ED_CURSOR)

    set_top_line("")
    if help then
	command = "h"
    else
	first_bold("help ")
	first_bold("clone ")
	first_bold("quit ")
	first_bold("save ")
	first_bold("write ")
	first_bold("new ")
	if dot_e then
	    if platform() = LINUX then
		first_bold("exu ")
	    else
		first_bold("ex ")
	    end if
	end if
	first_bold("dos ")
	first_bold("find ")
	first_bold("replace ")
	first_bold("lines ")
	first_bold("mods ")
	text_color(TOP_LINE_TEXT_COLOR)
	puts(SCREEN, "ddd CR: ")
	command = key_gets("hcqswnedfrlm", {}) & ' '
    end if

    if command[1] = 'f' then
	replacing = FALSE
	searching = search(FALSE)

    elsif command[1] = 'r' then
	replacing = TRUE
	searching = search(FALSE)

    elsif command[1] = 'q' then
	if modified and last_use() then
	    set_top_line("quit without saving changes? ")
	    if find('y', key_gets("yn", {})) then
		stop = delete_window()
	    end if
	else
	    stop = delete_window()
	end if
    
    elsif command[1] = 'c' then
	clone_window()
	
    elsif command[1] = 'n' then
	if modified and last_use() then
	    while TRUE do
		set_top_line("")
		printf(SCREEN, "save changes to %s? ", {file_name})
		answer = key_gets("yn", {})
		if find('y', answer) then
		    save_file(file_name)
		    exit
		elsif find('n', answer) then
		    exit
		end if
	    end while
	end if
	save_state()
	set_top_line("new file name: ")
	answer = delete_trailing_white(key_gets("", file_history))
	if length(answer) != 0 then
	    file_name = answer
	    stop = TRUE
	end if

    elsif command[1] = 'w' then
	save_file(file_name)
	stop = FALSE

    elsif command[1] = 's' then
	save_file(file_name)
	if stop then
	    stop = delete_window()
	end if

    elsif command[1] = 'e' and dot_e then
	if modified then
	    save_file(file_name)
	    stop = FALSE
	end if
	-- execute the current file & return
	if sequence(dir("ex.err")) then
	    if platform() = LINUX then
		system(delete_cmd & "ex.err", 0)
	    else
		system(delete_cmd & "ex.err > NUL", 0)
	    end if
	end if
	if platform() = LINUX then
	    shell("exu " & "\"" & file_name & "\"")
	elsif match(".exw", lower(file_name)) or 
	      match(".ew",  lower(file_name)) then
	    shell("exw " & file_name)
	else
	    shell("ex " & file_name)
	end if
	goto_line(0, b_col)
	if equal(file_name, get_err_line()) then
	    goto_line(start_line, 1)
	    set_err_pointer()
	    show_message()
	end if

    elsif command[1] = 'd' then
	if platform() = LINUX then
	    set_top_line("Linux command? ")
	else
	    set_top_line("DOS command? ")
	end if
	command = key_gets("", command_history)
	if length(delete_trailing_white(command)) > 0 then
	    shell(command)
	    command_history = update_history(command_history, command)
	end if
	normal_video()
	goto_line(0, b_col) -- refresh screen
    
    elsif command[1] = 'm' then
	-- show differences between buffer and file on disk
	save_file(TEMPFILE)
	if stop then
	    stop = FALSE
	    shell(compare_cmd & file_name & " " & TEMPFILE & " | more")
	    normal_video()
	    goto_line(0, b_col)
	    editbuff = TRUE
	end if
	
    elsif command[1] = 'h' then
	self_command = getenv("EUDIR")
	if atom(self_command) then
	    -- Euphoria hasn't been installed yet 
	    set_top_line("EUDIR not set. See install.doc")
	else    
	    if HOT_KEYS then
		self_command = {ESCAPE, 'c', ESCAPE, 'n'} & self_command 
	    else
		self_command = {ESCAPE, 'c', '\n', ESCAPE, 'n', '\n'} & self_command 
	    end if
	    self_command &= SLASH & "doc"
	    if help then
		set_top_line(
		"That key does nothing - do you want to view the help text? ")
		answer = key_gets("yn", {}) & ' '
		if answer[1] != 'n' and answer[1] != 'N' then
		    answer = "e"
		end if
	    else
		set_top_line("ed.doc, refman.doc, or library.doc? (e, r or l): ")
		answer = key_gets("erl", {}) & ' '
	    end if
	    if answer[1] = 'r' then
		add_queue(self_command & SLASH & "refman.doc" & CR)
	    elsif answer[1] = 'e' then
		add_queue(self_command & SLASH & "ed.doc" & CR)
	    elsif answer[1] = 'l' then
		add_queue(self_command & SLASH & "library.doc" & CR)
	    else
		normal_video()
	    end if
	end if

    elsif command[1] = 'l' then
	new_screen_length()

    elsif command[1] >= '0' and command[1] <= '9' then
	line = numeric(command)
	normal_video()
	goto_line(line, 1)
	if not buffer_line(line) then
	    set_top_line("")
	    printf(SCREEN, "lines are 1..%d", length(buffer))
	end if

    else
	set_top_line("")
	if length(buffer) = 0 then
	    puts(SCREEN, "empty buffer")
	else
	    printf(SCREEN, "%s line %d of %d, column %d of %d, ",
		       {file_name, b_line, length(buffer), s_col,
			length(expand_tabs(edit_tab_width, buffer[b_line]))-1})
	    if modified then
		puts(SCREEN, "modified")
	    else
		puts(SCREEN, "not modified")
	    end if
	end if
    end if

    normal_video()
end procedure

procedure insert(char key)
-- insert a character into the current line at the current position

    sequence tail

    set_modified()
    tail = buffer[b_line][b_col..length(buffer[b_line])]
    if key = CR or key = '\n' then
	-- truncate this line and create a new line using tail
	buffer[b_line] = buffer[b_line][1..b_col-1] & '\n'
	
	-- make room for new line:
	buffer = append(buffer, 0)
	for i = length(buffer)-1 to b_line+1 by -1 do
	    buffer[i+1] = buffer[i]
	end for
	
	-- store new line
	buffer[b_line+1] = tail
	
	if s_line = window_length then
	    arrow_down()
	    arrow_up()
	else
	    ScrollDown(s_line+1, window_length)
	end if
	if window_length = 1 then
	    arrow_down()
	else
	    DisplayLine(b_line, s_line, FALSE)
	    b_line += 1
	    s_line += 1
	    DisplayLine(b_line, s_line, FALSE)
	end if
	s_col = 1
	b_col = 1
    else
	if key = '\t' then
	    s_col = tab(edit_tab_width, s_col)
	else
	    s_col += 1
	end if
	buffer[b_line] = buffer[b_line][1..b_col-1] & key & tail
	DisplayLine(b_line, s_line, TRUE)
	b_col += 1
    end if
    set_position(s_line, s_col)
end procedure

procedure insert_string(sequence text)
-- insert a bunch of characters at the current position
    natural save_line, save_col

    save_line = b_line
    save_col = b_col
    for i = 1 to length(text) do
	if text[i] = CR or text[i] = '\n' then
	    insert(text[i])
	else
	    buffer[b_line] = buffer[b_line][1..b_col-1] & text[i] &
			     buffer[b_line][b_col..length(buffer[b_line])]
	    b_col += 1
	    if i = length(text) then
		DisplayLine(b_line, s_line, FALSE)
	    end if
	end if
    end for
    goto_line(save_line, save_col)
end procedure

-- expandable words & corresponding text
constant expand_word = {"if", "for", "while", "elsif",
			"procedure", "type", "function"},

	 expand_text = {" then",  "=  to  by  do",  " do",  " then",
			"()",  "()",  "()" 
		       }

procedure try_auto_complete(char key)
-- check for a keyword that can be automatically completed
    sequence word, this_line, white_space, leading_white, begin
    natural first_non_blank, wordnum

    if key = ' ' then
	insert(key)
    end if
    this_line = buffer[b_line]
    white_space = this_line = ' ' or this_line = '\t'
    first_non_blank = find(0, white_space) -- there's always '\n' at end
    leading_white = this_line[1..first_non_blank - 1]         
    if auto_complete and first_non_blank < b_col - 2 then
	if not find(0, white_space[b_col..length(white_space)-1]) then
	    word = this_line[first_non_blank..b_col - 1 - (key = ' ')]
	    wordnum = find(word, expand_word)           
	    
	    if key = CR and equal(word, "else") then    
		 leading_white &= '\t'
	    
	    elsif wordnum > 0 then
		sound(1000)
		-- expandable word (only word on line)

		begin = expand_text[wordnum] & CR & leading_white
		
		if equal(word, "elsif") then
		    insert_string(begin & '\t')
		   
		elsif find(word, {"function", "type"}) then
		    insert_string(begin & CR & 
				  leading_white & "\treturn" & CR &
				  "end " & expand_word[wordnum])
		else
		    insert_string(begin & '\t' & CR &
				  leading_white &
				  "end " & expand_word[wordnum])
		end if
		delay(0.07) -- or beep is too short
		sound(0)
	    end if
	end if
    end if
    if key = CR then
	if b_col >= first_non_blank then
	    buffer[b_line] = buffer[b_line][1..b_col-1] & leading_white &
			     buffer[b_line][b_col..length(buffer[b_line])]
	    insert(CR)
	    skip_white()
	else
	    insert(CR)
	end if
    end if
end procedure

procedure insert_kill_buffer()
-- insert the kill buffer at the current position
-- kill buffer could be a sequence of lines or a sequence of characters

    if length(kill_buffer) = 0 then
	return
    end if
    set_modified()
    if atom(kill_buffer[1]) then
	-- inserting a sequence of chars
	insert_string(kill_buffer)
    else
	-- inserting a sequence of lines
	buffer = buffer[1..b_line - 1] &
		 kill_buffer &
		 buffer[b_line..length(buffer)]
	DisplayWindow(b_line, s_line)
	b_col = 1
	s_col = 1
    end if
end procedure

procedure delete_line(buffer_line dead_line)
-- delete a line from the buffer and update the display if necessary

    integer x

    set_modified()
    -- move up all lines coming after the dead line
    for i = dead_line to length(buffer)-1 do
	buffer[i] = buffer[i+1]
    end for
    buffer = buffer[1..length(buffer)-1]
    
    x = dead_line - b_line + s_line
    if window_line(x) then
	-- dead line is on the screen at line x
	ScrollUp(x, window_length)
	if length(buffer) - b_line >= window_length - s_line then
	    -- show new line at bottom
	    DisplayLine(b_line + window_length - s_line, window_length, TRUE)
	end if
    end if
    if b_line > length(buffer) then
	arrow_up()
    else
	b_col = 1
	s_col = 1
    end if
    adding_to_kill = TRUE
end procedure

procedure delete_char()
-- delete the character at the current position
    char dchar
    sequence head
    natural save_b_col

    set_modified()
    dchar = buffer[b_line][b_col]
    head = buffer[b_line][1..b_col - 1]
    if dchar = '\n' then
	if b_line < length(buffer) then
	    -- join this line with the next one and delete the next one
	    buffer[b_line] = head & buffer[b_line+1]
	    DisplayLine(b_line, s_line, FALSE)
	    save_b_col = b_col
	    delete_line(b_line + 1)
	    for i = 1 to save_b_col - 1 do
		arrow_right()
	    end for
	else
	    if length(buffer[b_line]) = 1 then
		delete_line(b_line)
	    else
		arrow_left() -- a line must always end with \n
	    end if
	end if
    else
	buffer[b_line] = head & buffer[b_line][b_col+1..length(buffer[b_line])]
	if length(buffer[b_line]) = 0 then
	    delete_line(b_line)
	else
	    DisplayLine(b_line, s_line, FALSE)
	    if b_col > length(buffer[b_line]) then
		arrow_left()
	    end if
	end if
    end if
    adding_to_kill = TRUE
end procedure

function good(extended_char key)
-- return TRUE if key should be processed
    if find(key, SPECIAL_KEYS) then
	return TRUE
    elsif key >= ' ' and key <= 255 then
	return TRUE
    elsif key = '\t' or key = CR then
	return TRUE
    else
	return FALSE
    end if
end function

procedure edit_file()
-- edit the file in buffer
    extended_char key

    if length(buffer) > 0 then
	if start_line > 0 then
	    if start_line > length(buffer) then
		start_line = length(buffer)
	    end if
	    goto_line(start_line, 1)
	    set_err_pointer()
	    show_message()
	end if
    end if
    
    -- to speed up keyboard repeat rate:
    -- system("mode con rate=30 delay=2", 2)
    
    cursor(ED_CURSOR)
    stop = FALSE

    while not stop do

	key = next_key()
	if key = CONTROL_C then
	    refresh_all_windows()
	    goto_line(0, b_col)
	end if
	
	if good(key) then
	    -- normal key
	    
	    if key = CUSTOM_KEY then
		add_queue(CUSTOM_KEYSTROKES)

	    elsif key >= F1 and key <= F10 then
		if key < F1 + length(window_list) then
		    switch_window(key - F1 + 1)
		else
		    set_top_line("")
		    printf(SCREEN, "F%d is not an active window", key - F1 + 1)
		    normal_video()
		end if
		adding_to_kill = FALSE
		
	    elsif length(buffer) = 0 and key != ESCAPE then
		-- empty buffer
		-- only allowed action is to insert something
		if key = INSERT or not find(key, SPECIAL_KEYS) then
		    -- initialize buffer
		    buffer = {{'\n'}} -- one line with \n
		    b_line = 1
		    b_col = 1
		    s_line = 1
		    s_col = 1
		    if key = INSERT then
			insert_kill_buffer()
		    else
			insert(key)
		    end if
		    DisplayLine(1, 1, FALSE)
		end if

	    elsif key = DELETE or key = XDELETE then
		if not adding_to_kill then
		    kill_buffer = {buffer[b_line][b_col]}
		elsif sequence(kill_buffer[1]) then
		    -- we were building up deleted lines,
		    -- but now we'll switch to chars
		    kill_buffer = {buffer[b_line][b_col]}
		else
		    kill_buffer = append(kill_buffer, buffer[b_line][b_col])
		end if
		delete_char()

	    elsif key = CONTROL_DELETE or key = CONTROL_D then
		if not adding_to_kill then
		    kill_buffer = {buffer[b_line]}
		elsif atom(kill_buffer[1]) then
		    -- we were building up deleted chars,
		    -- but now we'll switch to lines
		    kill_buffer = {buffer[b_line]}
		else
		    kill_buffer = append(kill_buffer, buffer[b_line])
		end if
		delete_line(b_line)

	    else
		if key = PAGE_DOWN or key = CONTROL_P then
		    page_down()

		elsif key = PAGE_UP or key = CONTROL_U then
		    page_up()

		elsif key = ARROW_LEFT then
		    arrow_left()

		elsif key = ARROW_RIGHT then
		    arrow_right()

		elsif key = CONTROL_ARROW_LEFT or key = CONTROL_L then
		    previous_word()
		    
		elsif key = CONTROL_ARROW_RIGHT or key = CONTROL_R then
		    next_word()
		    
		elsif key = ARROW_DOWN then
		    arrow_down()

		elsif key = ARROW_UP then
		    arrow_up()

		elsif key = ' ' then
		    try_auto_complete(key)

		elsif key = INSERT then
		    insert_kill_buffer()

		elsif key = BS then
		    arrow_left()
		    delete_char()

		elsif key = HOME then
		    b_col = 1
		    s_col = 1
		
		elsif key = END then
		    goto_line(b_line, length(buffer[b_line]))
		
		elsif key = CONTROL_HOME or key = CONTROL_T then
		    goto_line(1, 1)

		elsif key = CONTROL_END or key = CONTROL_B then
		    goto_line(length(buffer), length(buffer[length(buffer)]))

		elsif key = ESCAPE then
		    -- special command
		    get_escape(FALSE)

		elsif key = CR then
		    if searching then
			searching = search(TRUE)
			normal_video()
			searching = TRUE -- avoids accidental <CR> insertion
		    else
			try_auto_complete(key)
		    end if
		
		else
		    insert(key)

		end if

		adding_to_kill = FALSE

	    end if

	    if key != CR and key != ESCAPE then
		searching = FALSE
	    end if
	    cursor(ED_CURSOR)
	
	else
	    -- illegal key pressed
	    get_escape(TRUE)  -- give him some help
	end if
	set_position(s_line, s_col)
    end while
end procedure

procedure ed(sequence command)
-- editor main procedure 
-- start editing a new file
-- ed.ex is executed by ed.bat
-- command line will be:
--    ex ed.ex              - get filename from ex.err, or user
--    ex ed.ex filename     - filename specified

    file_number file_no

    start_line = 0
    start_col = 0

    if length(command) >= 3 then
	file_name = command[3]
	if platform() != LINUX then
	    file_name = lower(file_name)
	end if
    else
	file_name = get_err_line()
    end if
    wrap(0)
    if length(file_name) = 0 then
	-- we still don't know the file name - so ask user
	puts(SCREEN, "file name: ")
	cursor(ED_CURSOR)
	file_name = key_gets("", file_history)
	puts(SCREEN, '\n')
    end if
    file_name = delete_trailing_white(file_name)
    if length(file_name) = 0 then
	abort(1) -- file_name was just whitespace - quit
    end if
    file_history = update_history(file_history, file_name)
    file_no = open(file_name, "r")

    -- turn off multi_color & auto_complete for non .e files
    multi_color = WANT_COLOR_SYNTAX
    auto_complete = WANT_AUTO_COMPLETE
    if not config[VC_COLOR] or config[VC_MODE] = 7 then
	multi_color = FALSE -- mono monitor
    end if
    file_name &= ' '
    dot_e = FALSE
    for i = 1 to length(E_FILES) do
	if match(E_FILES[i] & ' ', file_name) then
	    dot_e = TRUE
	end if
    end for
    if not dot_e then
	multi_color = FALSE
	auto_complete = FALSE
    end if
    
    -- use PROG_INDENT tab width for Euphoria & other languages:
    edit_tab_width = STANDARD_TAB_WIDTH
    for i = 1 to length(PROG_FILES) do
       if match(PROG_FILES[i] & ' ', file_name) then
	   edit_tab_width = PROG_INDENT
	   exit
       end if
    end for
    
    if multi_color then
	init_class()
    end if

    file_name = file_name[1..length(file_name)-1] -- remove ' '
    adding_to_kill = FALSE
    clear_modified()
    buffer_version = 0
    control_chars = FALSE
    cr_removed = FALSE
    new_buffer()
    s_line = 1
    s_col = 1
    b_line = 1
    b_col = 1
    save_state()
    while get_key() != -1 do
	-- clear the keyboard buffer 
	-- to reduce "key bounce" problems
    end while
    if file_no = -1 then
	set_f_line(window_number, " <new file>")
	normal_video()
	ClearWindow()
    else
	set_f_line(window_number, "")
	normal_video()
	set_position(1, 1)
	cursor(NO_CURSOR)
	read_file(file_no)
	close(file_no)
    end if
    set_position(1, 1)
    edit_file()
end procedure

procedure ed_main()
-- startup and shutdown of ed()
    sequence cl
    
    allow_break(FALSE)
    
    config = video_config()

    if config[VC_XPIXELS] > 0 then
	if graphics_mode(3) then
	end if
	config = video_config()
    end if

    if config[VC_LINES] != INITIAL_LINES then
	screen_length = text_rows(INITIAL_LINES)
	config = video_config()
    end if
    screen_length = config[VC_LINES]
    screen_width = config[VC_COLUMNS]
    BLANK_LINE = repeat(' ', screen_width)
    window_length = screen_length - 1

    cl = command_line()

    while length(window_list) > 0 do
	ed(cl)
	cl = {"ex", "ed.ex" , file_name}
    end while

    -- exit editor
    delete_editbuff()
    if screen_length != FINAL_LINES then
	screen_length = text_rows(FINAL_LINES)
    end if
    cursor(UNDERLINE_CURSOR)
    bk_color(BLACK)
    text_color(WHITE)
    position(screen_length, 1)
    puts(SCREEN, BLANK_LINE)
    position(screen_length, 1)
    puts(SCREEN, "\n")
end procedure

ed_main()
-- This abort statement reduces the chance of 
-- a syntax error when you edit ed.ex using itself: 
free_console()
--abort(0) 

