-- (c) Copyright 2007 Rapid Deployment Software - See License.txt
--
-- Euphoria 3.1
-- Scanner (low-level parser)

include machine.e
include file.e
include get.e

include global.e
include reswords.e
include error.e
include symtab.e
include scientific.e
constant INCLUDE_LIMIT = 30   -- maximum depth of nested includes 
constant MAX_FILE = 256       -- maximum number of source files

-- Single-byte codes used by (legacy) binder/shrouder
-- update when keyword or builtin added 
-- see also keylist.e, euphoria\bin\keywords.e
constant NUM_KEYWORDS = 24 
constant NUM_BUILTINS = 64 
constant KEYWORD_BASE = 128  -- 129..152  must be one-byte values - no overlap
constant BUILTIN_BASE = 170  -- 171..234  N.B. can't use: 253,254,255
							 -- Note: we did not include the latest multitasking
							 -- builtins, since we now have a new method of
							 -- binding/shrouding that does not use single-byte
							 -- codes
-- global variables
global sequence main_path         -- path of main file being executed 
global integer src_file           -- the source file 
global sequence new_include_name  -- name of file to be included at end of line
global symtab_index new_include_space -- new namespace qualifier or NULL

boolean start_include   -- TRUE if we should start a new file at end of line
start_include = FALSE

boolean export_include -- TRUE if we should pass along exported includes

global integer LastLineNumber  -- last global line number (avoid dups in line tab)
LastLineNumber = -1     

global object shebang              -- #! line (if any) for Linux/FreeBSD
shebang = 0

sequence default_namespaces

-- Local variables
sequence char_class  -- character classes, some are negative
sequence id_char     -- char that could be in an identifier
sequence IncludeStk  -- stack of include file info

-- IncludeStk entry
constant FILE_NO = 1,           -- file number
		 LINE_NO = 2,           -- local line number
		 FILE_PTR = 3,          -- open file number 
		 FILE_START_SYM = 4,    -- symbol before start of file
		 OP_WARNING = 5,        -- save/restore with/without options
		 OP_TRACE = 6,         
		 OP_TYPE_CHECK = 7,
		 OP_PROFILE_TIME = 8,
		 OP_PROFILE_STATEMENT = 9,
		 OP_DEFINES = 10        -- ifdef defines

-- list of source lines & execution counts 

global procedure InitLex()
-- initialize lexical analyzer 
	gline_number = 0
	line_number = 0
	IncludeStk = {}
	char_class = repeat(ILLEGAL_CHAR, 255)  -- we screen out the 0 character

	char_class['0'..'9'] = DIGIT
	char_class['a'..'z'] = LETTER
	char_class['A'..'Z'] = LETTER
	char_class[KEYWORD_BASE+1..KEYWORD_BASE+NUM_KEYWORDS] = KEYWORD
	char_class[BUILTIN_BASE+1..BUILTIN_BASE+NUM_BUILTINS] = BUILTIN

	char_class[' '] = BLANK
	char_class['\t'] = BLANK
	char_class['+'] = PLUS
	char_class['-'] = MINUS
	char_class['*'] = MULTIPLY
	char_class['/'] = DIVIDE
	char_class['='] = EQUALS
	char_class['<'] = LESS
	char_class['>'] = GREATER
	char_class['\''] = SINGLE_QUOTE
	char_class['"'] = DOUBLE_QUOTE
	char_class['.'] = DOT
	char_class[':'] = COLON
	char_class['\r'] = NEWLINE
	char_class['\n'] = NEWLINE
	char_class['!'] = BANG
	char_class['{'] = LEFT_BRACE
	char_class['}'] = RIGHT_BRACE
	char_class['('] = LEFT_ROUND
	char_class[')'] = RIGHT_ROUND
	char_class['['] = LEFT_SQUARE
	char_class[']'] = RIGHT_SQUARE
	char_class['$'] = DOLLAR
	char_class[','] = COMMA
	char_class['&'] = CONCAT
	char_class['?'] = QUESTION_MARK
	char_class['#'] = NUMBER_SIGN
	
	-- 26 character can't appear in a text file
	char_class[END_OF_FILE_CHAR] = END_OF_FILE 

	-- helps speed up scanner a bit
	id_char = repeat(FALSE, 255)
	for i = 1 to 255 do
		if i = '_' or find(char_class[i], {LETTER, DIGIT}) then
			id_char[i] = TRUE
		end if
	end for
	
	default_namespaces = {0}
end procedure

global procedure ResetTP()
-- turn off all trace/profile flags 
	OpTrace = FALSE
	OpProfileStatement = FALSE
	OpProfileTime = FALSE
	AnyStatementProfile = FALSE
	AnyTimeProfile = FALSE
end procedure

-- source line buffers
-- Storing lines of source in memory buffers saves space and 
-- helps old machines load huge programs more quickly
-- Anyway, the C-coded back-end wants it in this form.
constant SOURCE_CHUNK = 10000 -- size of one chunk (many lines) of source, in bytes
atom current_source  -- current place to store source lines
integer current_source_next -- next position to store lines into
all_source = {}
current_source_next = SOURCE_CHUNK -- forces the first allocation

function pack_source(object src)
-- store the source line (minus \n) in a big block of memory to
-- save time and space. The offset where the line is stored is returned.
	integer start
	
	if equal(src, 0) then
		return 0
	end if

	if length(src) >= SOURCE_CHUNK then
		src = src[1..80] -- enough for trace or profile display
	end if
	
	if current_source_next + length(src) >= SOURCE_CHUNK then
		-- we ran out of space, allocate another chunk
		current_source = allocate(SOURCE_CHUNK)
		if current_source = 0 then
			CompileErr("out of memory - turn off trace and profile")
		end if
		all_source = append(all_source, current_source)
		-- skip first byte, offset 0 means "no source"
		current_source_next = 1 
	end if
	
	start = current_source_next 
	poke(current_source+current_source_next, src)
	current_source_next += length(src)-1
	poke(current_source+current_source_next, 0) -- overwrite \n
	current_source_next += 1
	return start + SOURCE_CHUNK * (length(all_source)-1)
end function

global function fetch_line(integer start)
-- get the line of source stored at offset start (without \n)
	sequence line
	integer c, chunk
	atom p
	
	if start = 0 then
		return ""
	end if
	line = ""
	chunk = 1+floor(start / SOURCE_CHUNK)
	start = remainder(start, SOURCE_CHUNK)
	p = all_source[chunk] + start
	while TRUE do
		c = peek(p)
		if c = 0 then
			exit
		end if
		line &= c
		p += 1
	end while
	return line
end function

global procedure AppendSourceLine()
-- add source line to the list 
	sequence new, old
	integer options
	object src
	
	src = 0
	options = 0
	
	if TRANSLATE or OpTrace or OpProfileStatement or OpProfileTime then
		-- record the options and maybe keep the source line too
		src = ThisLine

		if EUNIX and TRANSLATE and mybsd then
			src = ""  -- save space, only 8Mb available!
		end if

		if OpTrace then
			options = SOP_TRACE
		end if
		if OpProfileTime then
			options = or_bits(options, SOP_PROFILE_TIME)
		end if
		if OpProfileStatement then
			options = or_bits(options, SOP_PROFILE_STATEMENT)
		end if
		if OpProfileStatement or OpProfileTime then
			src = {0,0,0,0} & src
		end if
	end if
	
	if length(slist) then
		old = slist[$-1]
		
		if equal(src, old[SRC]) and 
		   current_file_no = old[LOCAL_FILE_NO] and
		   line_number = old[LINE]+1+slist[$] and  
		   options = old[OPTIONS] then
			-- Just increment repetition count rather than storing new entry.
			-- This works well as long as we are not saving the source lines.
			slist[$] += 1  
		else
			src = pack_source(src)
			new = {src, line_number, current_file_no, options}
			if slist[$] = 0 then
				slist[$] = new
			else
				slist = append(slist, new)
			end if
			slist = append(slist, 0)
		end if
	else
		src = pack_source(src)
		slist = {{src, line_number, current_file_no, options}, 0}
	end if
end procedure

global function s_expand(sequence slist)
-- expand slist to full size if required
	sequence new_slist
	
	new_slist = {}
	
	for i = 1 to length(slist) do
		if sequence(slist[i]) then
			new_slist = append(new_slist, slist[i])
		else
			for j = 1 to slist[i] do
				slist[i-1][LINE] += 1
				new_slist = append(new_slist, slist[i-1]) 
			end for
		end if
	end for
	return new_slist
end function

global procedure read_line()
-- read next line of source  
	integer n
	
	line_number += 1
	gline_number += 1
	
	ThisLine = gets(src_file)
	if atom(ThisLine) then
		ThisLine = {END_OF_FILE_CHAR}
	end if

	bp = 1
	n = length(ThisLine)
	if ThisLine[n] != '\n' then
		ThisLine = append(ThisLine, '\n') -- add missing \n (might happen at end of file)
	end if
	AppendSourceLine()
end procedure

procedure bad_zero()
-- don't allow 0 character in source file   
	CompileErr("illegal character (ASCII 0)")
end procedure

function getch()   
-- return next input character, 1 to 255
	integer c
	
	c = ThisLine[bp]
	if c = 0 then
		bad_zero()
	end if
	bp += 1
	return c   
end function

procedure ungetch() 
-- put input character back 
	bp -= 1               
end procedure

function get_file_path(sequence s)
-- return a directory path from a file path
		for t=length(s) to 1 by -1 do
				if find(s[t],SLASH_CHARS) then
						return s[1..t]
				end if
		end for
		-- if no slashes were found then can't assume it's a directory
		return "." & SLASH
end function

include pathopen.e
function path_open()
-- open an include file (new_include_name) according to the include path rules  
	integer absolute, try
	sequence full_path
	sequence errbuff
		sequence currdir
	sequence conf_path
	object scan_result, inc_path
		
	absolute = FALSE
	
	-- skip whitespace not necessary - String Token does it
	
	-- check for leading backslash
	absolute = find(new_include_name[1], SLASH_CHARS) or
			   (not EUNIX and find(':', new_include_name))
	
	if absolute then
		-- open new_include_name exactly as it is
		try = open(new_include_name, "r")
		if try = -1 then
			errbuff = sprintf("can't open %s", new_include_name)
			CompileErr(errbuff)
		end if
		return try
	end if

	-- first try path from current file path
	-- c.k. lester
	currdir = get_file_path( file_name[current_file_no] )
	full_path = currdir & new_include_name
	try = open(full_path, "r")
	
	if try = -1 then
		-- relative path name - first try main_path
		full_path = main_path & new_include_name
		try = open(full_path,  "r")
	end if
 
	if try != -1 then
		new_include_name = full_path
		return try
	end if
	
	scan_result = ConfPath(new_include_name)
	
	if atom(scan_result) then
		scan_result = ScanPath(new_include_name,"EUINC",0)
	end if

	if atom(scan_result) then
		scan_result = ScanPath(new_include_name, "EUDIR",1)
	end if

	if sequence(scan_result) then
		-- successful
		new_include_name = scan_result[1]
		return scan_result[2]
	end if

	if length(main_path) = 0 then
		main_path = "."
	end if
	if find(main_path[$], SLASH_CHARS) then
		main_path = main_path[1..$-1]  -- looks better
	end if

	inc_path = getenv("EUINC")
	conf_path = get_conf_dirs()
	if atom(inc_path) then
		errbuff = sprintf("can't find %s in %s\nor in %s\nor in %s%sinclude",
						  {new_include_name, main_path, conf_path, eudir, SLASH})
	else
		errbuff = sprintf("can't find %s in %s\nor in %s\nor in %s\nor in %s%sinclude",
						  {new_include_name, main_path, conf_path, inc_path, eudir, SLASH})
	end if
	CompileErr(errbuff)
end function

function win_compare(sequence a,sequence b)
	atom conv
	integer rc

	conv=allocate_string(a)
	conv=c_func(char_upper,{conv}) -- conv is unchanged
	a=peek({conv,length(a)})
	poke(conv,b)
	conv=c_func(char_upper,{conv}) -- conv is unchanged
	rc = equal(a,peek({conv,length(a)}))
	free(conv)
	return rc
end function

function dos_compare(sequence a,sequence b)
	integer ai,bi,c
	
	for i=1 to length(a) do
		ai=a[i]
		bi=b[i]
		if ai!=bi then -- do some work
			c = xor_bits(ai,bi)
			if c >= #40 then
			-- either one of the chars is accented and not the other, or one is a letter and not the other
				return FALSE
			end if
			-- both char are allowed in filenames and different
			if ai<128 then  -- unaccented chars
				if c != #20 or and_bits(ai,31)>26 then -- not case insensitive equal
				-- if c=#20, then both chars ar in 'A'..#7F. Hence the need to filter out spurious positives from #7B..#7F.
					return FALSE
				end if
			else  -- accented chars
				if not fc_table then -- no capitalisation supported, chars differ
					return FALSE
				end if
				-- speed things up by not always peeking twice
				c = peek(fc_table+ai)
				if c != ai then -- a[i] is lowercase
					if c != bi then -- b[i] is neither of the allowed two
						return FALSE
					end if
				else -- a[i] is uppercase, so check b[i] directly
					if ai != peek(fc_table+bi) then -- different after uppercasing
						return FALSE
					end if
				end if
			end if
		end if
	end for
	return TRUE
end function

function same_name(sequence a, sequence b)
-- return TRUE if two file names (or paths) are equal
	if EUNIX then
		return equal(a, b) -- case sensitive
	end if
	-- DOS/Windows
	if length(a) != length(b) then
		return FALSE
	elsif EWINDOWS then
		return win_compare(a,b)
	else
		return dos_compare(a,b)
	end if
end function

function NameSpace_declaration(symtab_index sym)
-- add a new namespace symbol to the symbol table.
-- Similar to adding a local constant. 
	integer h
	
	DefinedYet(sym)
	if find(SymTab[sym][S_SCOPE], {SC_GLOBAL, SC_PREDEF}) then
		-- override the global or predefined symbol 
		h = SymTab[sym][S_HASHVAL]
		-- create a new entry at beginning of this hash chain 
		sym = NewEntry(SymTab[sym][S_NAME], 0, 0, VARIABLE, h, buckets[h], 0) 
		buckets[h] = sym
	end if
	SymTab[sym][S_SCOPE] = SC_LOCAL
	SymTab[sym][S_MODE] = M_CONSTANT
	SymTab[sym][S_TOKEN] = NAMESPACE -- [S_OBJ] will get the file number referred-to
	if TRANSLATE then
		num_routines += 1 -- order of ns declaration relative to routines 
						  -- is important
	end if
	return sym
end function

integer scanner_rid

procedure default_namespace( integer file_no, integer use )
	token tok
	symtab_index sym
	
	tok = call_func( scanner_rid, {} )
	if tok[T_ID] = VARIABLE and equal( SymTab[tok[T_SYM]][S_NAME], "namespace" ) then
		-- add the default namespace
		tok = call_func( scanner_rid, {} )
		if tok[T_ID] != VARIABLE then
			CompileErr("missing default namespace qualifier")
		end if
		
		sym = tok[T_SYM]
		
		-- if it's the main file, file_no will be zero, because
		-- there is no using file		
		if file_no and use then
			
			SymTab[sym][S_FILE_NO] = file_no
			sym  = NameSpace_declaration( sym )
			SymTab[sym][S_OBJ] = current_file_no
		else
			remove_symbol( sym )
		end if
		
		default_namespaces[current_file_no] = SymTab[sym][S_NAME]
		
	else
		-- start over from the beginning of the line
		bp = 1
	end if
	
end procedure


procedure declare_default_namespace( integer namespace_file )
	token s
	
	s = keyfind(default_namespaces[namespace_file], -1)
	if not find(s[T_ID], {VARIABLE, FUNC, TYPE, PROC}) then
		CompileErr(sprintf("default namespace identifier '%s' for %s already defined",
			{default_namespaces[namespace_file], file_name[namespace_file]}))
	end if
	printf(1, "Declaring default namespace '%s' for file '%s' in including file '%s'\n",
		{default_namespaces[namespace_file], file_name[namespace_file], file_name[current_file_no]})
	new_include_space = NameSpace_declaration(s[T_SYM])
	SymTab[new_include_space][S_OBJ] = namespace_file
	SymTab[new_include_space][S_FILE_NO] = current_file_no
end procedure

procedure add_exports( integer from_file, integer to_file )
	sequence exports
	sequence direct
	direct = file_include[to_file]
	exports = file_export[from_file]
	for i = 1 to length(exports) do
		if not find( exports[i], direct ) then
			direct &= exports[i]
		end if
	end for
	file_include[to_file] = direct
end procedure

procedure patch_exports( integer for_file )
	integer export_len
	
	for i = 1 to length(file_include) do
		if find( for_file, file_include[i] ) then
			export_len = length( file_export[i] )
			add_exports( for_file, i )
			if length( file_export[i] ) != export_len then	
				-- propagate the export up the include stack
				patch_exports( i )
			end if
		end if
	end for
end procedure

procedure IncludePush()
-- start reading from new source file with given name  
	integer new_file, old_file_no
	sequence new_name

	start_include = FALSE

	new_file = path_open() -- sets new_include_name to full path 

	new_name = name_ext(new_include_name)
	
	for i = length(file_name) to 1 by -1 do
		-- compare file names first to reduce calls to dir() 
		if same_name(new_name, name_ext(file_name[i])) and
		   equal(dir(new_include_name), dir(file_name[i])) then
			-- can assume we've included this file already
			-- (Thanks to Vincent Howell.)
			-- (currently, in a very rare case, it could be a 
			--  different file in another directory with the 
			--  same name, size and time-stamp down to the second)
			if new_include_space != 0 then
				SymTab[new_include_space][S_OBJ] = i -- but note any namespace
				
			elsif sequence( default_namespaces[i] ) then
				-- no namespace declared, but there is a default namespace
				declare_default_namespace( i )
			end if
			close(new_file)
			
			if not find( i, file_include[current_file_no] ) then
				-- don't reparse the file, but note that it was included here
				file_include[current_file_no] &= i
				
				-- also add anything that file exports
				add_exports( i, current_file_no )
				
				if export_include then
					export_include = FALSE
					if not find( i, file_export[current_file_no] ) then
						file_export[current_file_no] &= i
					end if
				end if
			end if
			
			read_line() -- we can't return without reading a line first
			return -- ignore it  
		end if
	end for
	
	if length(IncludeStk) >= INCLUDE_LIMIT then
		CompileErr("includes are nested too deeply")
	end if
	
	IncludeStk = append(IncludeStk, 
							  {current_file_no,
							   line_number,
							   src_file,
							   file_start_sym,
							   OpWarning,
							   OpTrace,
							   OpTypeCheck,
							   OpProfileTime,
							   OpProfileStatement,
							   OpDefines})
							   
	file_include = append( file_include, {} )
	file_export  = append( file_export, {} )
	file_include[current_file_no] &= length( file_include )
	if export_include then
		file_export[current_file_no] &= length( file_export )
		export_include = FALSE
		patch_exports( current_file_no )
	end if
	
	src_file = new_file
	file_start_sym = last_sym
	if current_file_no >= MAX_FILE then
		CompileErr("program includes too many files")
	end if
	file_name = append(file_name, new_include_name)
	default_namespaces &= 0
	
	old_file_no = current_file_no
	current_file_no = length(file_name)
	line_number = 0
	read_line()	
	
	if new_include_space != 0 then
		SymTab[new_include_space][S_OBJ] = current_file_no
		default_namespace( old_file_no, 0 )
	
	else
		-- look for a default namespace
		default_namespace( old_file_no, 1 )
	end if
	
	
	
end procedure


global function IncludePop()
-- stop reading from current source file and restore info for previous file
-- (if any)  
	sequence top
	
	HideLocals()
	
	close(src_file)
	
	if length(IncludeStk) = 0 then 
		return FALSE  -- the end  
	end if
	
	top = IncludeStk[$]
	
	current_file_no    = top[FILE_NO]
	line_number        = top[LINE_NO]
	src_file           = top[FILE_PTR]
	file_start_sym     = top[FILE_START_SYM]
	OpWarning          = top[OP_WARNING]
	OpTrace            = top[OP_TRACE]
	OpTypeCheck        = top[OP_TYPE_CHECK]
	OpProfileTime      = top[OP_PROFILE_TIME]
	OpProfileStatement = top[OP_PROFILE_STATEMENT]
	OpDefines          = top[OP_DEFINES]

	IncludeStk = IncludeStk[1..$-1]
	return TRUE
end function


function MakeInt(sequence text)
-- make a non-negative integer out of a string of digits  
	integer num

	if length(text) > 9 then -- ensure no possibility of overflow  
		return -1            -- use f.p. calculations  
	end if
	
	num = text[1] - '0'
	for i = 2 to length(text) do 
		num = num * 10 + (text[i] - '0')
	end for

	return num
end function        


function EscapeChar(integer c)
-- the escape characters  
	if c = 'n' then
		return '\n'
	
	elsif c = '\\' then
		return '\\'
	
	elsif c = 't' then
		return '\t'
	
	elsif c = '"' then
		return '"'
	
	elsif c = '\''then
		return '\''
	
	elsif c = 'r' then
		return '\r'
	
	else 
		CompileErr("unknown escape character")
	
	end if
end function

						
function my_sscanf(sequence yytext)
-- Converts string to floating-point number
-- based on code in get.e
-- returns {} if number is badly formed
	integer e_sign, ndigits, e_mag
	atom mantissa
	integer c, i
	atom dec
	
	if length(yytext) < 2 then
		CompileErr("number not formed correctly")
	end if
	
	if find( 'e', yytext ) or find( 'E', yytext ) then
		return scientific_to_atom( yytext )
	end if
	mantissa = 0.0
	ndigits = 0
	
	-- decimal integer or floating point
	
	yytext &= 0 -- end marker
	c = yytext[1]
	i = 2
	while c >= '0' and c <= '9' do
		ndigits += 1
		mantissa = mantissa * 10.0 + (c - '0')
		c = yytext[i]
		i += 1
	end while
	
	if c = '.' then
		-- get fraction
		c = yytext[i]
		i += 1
		dec = 10.0
		while c >= '0' and c <= '9' do
			ndigits += 1
			mantissa = mantissa + (c - '0') / dec
			dec = dec * 10.0
			c = yytext[i]
			i += 1
		end while
	end if
	
	if ndigits = 0 then
		return {}  -- no digits
	end if
	
	if c = 'e' or c = 'E' then
		-- get exponent sign
		e_sign = +1
		e_mag = 0
		c = yytext[i]
		i += 1
		if c = '-' then
			e_sign = -1
		elsif c != '+' then
			i -= 1
		end if
		-- get exponent magnitude 
		c = yytext[i]
		i += 1
		if c >= '0' and c <= '9' then
			e_mag = c - '0'
			c = yytext[i]
			i += 1
			while c >= '0' and c <= '9' do
				e_mag = e_mag * 10 + c - '0'
				c = yytext[i]                          
				i += 1
				if e_mag > 1000 then -- avoid int overflow. can only have 
					exit             -- 200-digit mantissa to reduce mag
				end if
			end while
		else 
			return {} -- no exponent
		end if
		e_mag = e_sign * e_mag
		if e_mag > 308 then
			mantissa = mantissa * power(10.0, 308.0)
			e_mag = e_mag - 308
			while e_mag > 0 do
				mantissa = mantissa * 10.0 -- Could crash? No we'll get INF.
				e_mag -= 1
			end while
		else   
			mantissa = mantissa * power(10.0, e_mag)
		end if
	end if
	return mantissa
end function
			
global function Scanner()
-- The scanner main routine: returns a lexical token  
	integer ch, i, sp
	sequence yytext, namespaces  -- temporary buffer for a token
	atom d
	token tok
	integer is_int, class
	sequence name

	while TRUE do
		ch = ThisLine[bp]  -- getch inlined (in all the "hot" spots)
		bp += 1
		while ch = ' ' or ch = '\t' do
			ch = ThisLine[bp]  -- getch inlined
			bp += 1
		end while
		if ch = 0 then
			bad_zero()
		end if
			
		class = char_class[ch]
			
		-- if/elsif cases have been sorted so most common ones come first
		if class = LETTER then 
			sp = bp
			ch = ThisLine[bp]  -- getch
			bp += 1 
			if ch = 0 then
				bad_zero()
			end if
			while id_char[ch] do
				ch = ThisLine[bp] -- getch
				bp += 1
				if ch = 0 then
					bad_zero()
				end if
			end while
			yytext = ThisLine[sp-1..bp-2]
			bp -= 1  -- ungetch
			tok = keyfind(yytext, -1)
			if tok[T_ID] = NAMESPACE then
				-- skip whitespace
				namespaces = yytext
				ch = getch()
				while ch = ' ' or ch = '\t' do
					ch = getch()
				end while
						
				if ch = ':' then
					-- skip whitespace
					ch = getch()
					while ch = ' ' or ch = '\t' do
						ch = getch()
					end while
					yytext = ""
					while id_char[ch] do
						yytext &= ch
						ch = getch()
					end while 
					ungetch()
						
					if length(yytext) = 0 then
						CompileErr("an identifier is expected here")
					end if  
					
					-- must look in chosen file.
					-- can't create a new variable in s.t.
						
				    if Parser_mode = PAM_RECORD then
		                Recorded = append(Recorded,yytext)
		                Ns_recorded = append(Ns_recorded,namespaces)
		                return {RECORDED,length(Recorded)}
				    else
						tok = keyfind(yytext, SymTab[tok[T_SYM]][S_OBJ])
	
						if tok[T_ID] = VARIABLE then
							tok[T_ID] = QUALIFIED_VARIABLE
						elsif tok[T_ID] = FUNC then
							tok[T_ID] = QUALIFIED_FUNC
						elsif tok[T_ID] = PROC then
							tok[T_ID] = QUALIFIED_PROC
						elsif tok[T_ID] = TYPE then
							tok[T_ID] = QUALIFIED_TYPE
						end if
					end if
				else
					ungetch()
				    if Parser_mode = PAM_RECORD then
		                Recorded = append(Recorded,yytext)
		                Ns_recorded &= 0
		                tok = {RECORDED,length(Recorded)}
		            end if
				end if
			else
			    if Parser_mode = PAM_RECORD then
	                Recorded = append(Recorded,yytext)
	                Ns_recorded &= 0
	                tok = {RECORDED,length(Recorded)}
	            end if
			end if
			return tok
			
		elsif class <= ILLEGAL_CHAR then
			return {class, 0}  -- brackets, punctuation, eof, illegal char etc.

		elsif class = NEWLINE then
			if start_include then
				IncludePush()
			else
				read_line()
			end if
			

		elsif class = EQUALS then
			return {class, 0}  

		elsif class = DOT or class = DIGIT then
			if class = DOT then
				if getch() = '.' then
					return {SLICE, 0}
				else
					ungetch()
				end if
			end if
			
			is_int = TRUE
			yytext = {ch}
			if ch = '.' then
				is_int = FALSE
			end if
			ch = ThisLine[bp] -- getch
			if ch = 0 then
				bad_zero()
			end if
			bp += 1
			while char_class[ch] = DIGIT do 
				yytext &= ch
				ch = ThisLine[bp] -- getch
				if ch = 0 then
					bad_zero()
				end if
				bp += 1
			end while
			if ch = '.' then
				ch = getch()
				if ch = '.' then
					-- put back slice  
					ungetch()
				else 
					is_int = FALSE
					if yytext[1] = '.' then
						CompileErr("only one decimal point allowed")
					else
						yytext &= '.'
					end if
					if char_class[ch] = DIGIT then
						yytext &= ch
						ch = getch()
						while char_class[ch] = DIGIT do
							yytext &= ch
							ch = getch()
						end while
					else 
						CompileErr("fractional part of number is missing")
					end if
				end if
			end if
				
			if ch = 'e' or ch = 'E' then
				is_int = FALSE
				yytext &= ch
				ch = getch()
				if ch = '-' or ch = '+' or char_class[ch] = DIGIT then
					yytext &= ch
				else  
					CompileErr("exponent not formed correctly")
				end if
				ch = getch()
				while char_class[ch] = DIGIT do
					yytext &= ch
					ch = getch()
				end while
			end if
				
			bp -= 1  --ungetch
				
			i = MakeInt(yytext)
			if is_int and i != -1 then
				return {ATOM, NewIntSym(i)}
			else 
				-- f.p. or large int  
				d = my_sscanf(yytext)
				if sequence(d) then
					CompileErr("number not formed correctly")
				elsif is_int and d <= MAXINT_DBL then
					return {ATOM, NewIntSym(d)}  -- 1 to 1.07 billion
				else 
					return {ATOM, NewDoubleSym(d)}
				end if
			end if
		
		elsif class = MINUS then
			ch = ThisLine[bp] -- getch
			bp += 1
			if ch = '-' then 
				-- comment
				if start_include then
					IncludePush()
				else
					read_line()
				end if
				
			elsif ch = '=' then
				return {MINUS_EQUALS, 0}
			else 
				bp -= 1
				return {MINUS, 0}
			end if
			
		elsif class = DOUBLE_QUOTE then  
			ch = ThisLine[bp]  -- getch
			bp += 1
			yytext = ""
			while ch != '\n' and ch != '\r' do -- can't be EOF
				if ch = '"' then 
					exit
				elsif ch = '\\' then
					yytext &= EscapeChar(getch())
				elsif ch = '\t' then
					CompileErr("tab character found in string - use \\t instead")
				elsif ch = 0 then
					bad_zero()
				else
					yytext &= ch
				end if
				ch = ThisLine[bp]  -- getch
				bp += 1
			end while
			if ch = '\n' or ch = '\r' then
				CompileErr("end of line reached with no closing \"")
			end if
			return {STRING, NewStringSym(yytext)}
				  
		elsif class = PLUS then
			ch = getch()
			if ch = '=' then
				return {PLUS_EQUALS, 0}
			else 
				ungetch()
				return {PLUS, 0}
			end if
			
		elsif class = CONCAT then
			ch = getch()
			if ch = '=' then
				return {CONCAT_EQUALS, 0}
			else 
				ungetch()
				return {CONCAT, 0}
			end if
		
		elsif class = NUMBER_SIGN then
			i = 0
			is_int = -1
			while i < MAXINT_VAL/32 do             
				ch = getch()
				if char_class[ch] = DIGIT then
					i = i * 16 + ch - '0'
					is_int = TRUE
				elsif ch >= 'A' and ch <= 'F' then   
					i = (i * 16) + ch - ('A'-10)
					is_int = TRUE
				else
					exit 
				end if
			end while
				
			if is_int = -1 then
				if ch = '!' then
					if line_number > 1 then
						CompileErr(
						"#! may only be on the first line of a program")
					end if
					-- treat as a comment (Linux command interpreter line)
					shebang = ThisLine
					if start_include then
						IncludePush()
					end if
					read_line()
				else
					CompileErr("hex number not formed correctly")
				end if
			
			else
				if i >= MAXINT_VAL/32 then
					d = i
					is_int = FALSE
					while TRUE do
						ch = getch()  -- eventually END_OF_FILE_CHAR or new-line 
						if char_class[ch] = DIGIT then
							d = (d * 16) + ch - '0'
						elsif ch >= 'A' and ch <= 'F' then   
							d = (d * 16) + ch - ('A'- 10)
						else
							exit 
						end if
					end while
				end if
				
				ungetch()
				if is_int then
					return {ATOM, NewIntSym(i)}
				else 
					if d <= MAXINT_DBL then            -- d is always >= 0
						return {ATOM, NewIntSym(d)} 
					else
						return {ATOM, NewDoubleSym(d)}
					end if
				end if
			end if
			
		elsif class = MULTIPLY then
			ch = getch()
			if ch = '=' then
				return {MULTIPLY_EQUALS, 0}
			else 
				ungetch()
				return {MULTIPLY, 0}
			end if
			
		elsif class = DIVIDE then
			ch = getch()
			if ch = '=' then
				return {DIVIDE_EQUALS, 0}
			else 
				ungetch()
				return {DIVIDE, 0}
			end if
			
		elsif class = SINGLE_QUOTE then
			ch = getch()
			if ch = '\\' then 
				ch = EscapeChar(getch())
			elsif ch = '\t' then
				CompileErr("tab character found in string - use \\t instead")
			elsif ch = '\'' then
				CompileErr("single-quote character is empty")
			end if
			if getch() != '\'' then
				CompileErr("character constant is missing a closing '")
			end if
			return {ATOM, NewIntSym(ch)}

		elsif class = LESS then
			if getch() = '=' then
				return {LESSEQ, 0}
			else 
				ungetch()
				return {LESS, 0}
			end if

		elsif class = GREATER then
			if getch() = '=' then
				return {GREATEREQ, 0}
			else 
				ungetch()
				return {GREATER, 0}
			end if

		elsif class = BANG then
			if getch() = '=' then 
				return {NOTEQ, 0}
			else 
				ungetch()
				return {BANG, 0}
			end if       

		elsif class = KEYWORD then
			return {keylist[ch - KEYWORD_BASE][K_TOKEN], 0}

		elsif class = BUILTIN then
			name = keylist[ch - BUILTIN_BASE + NUM_KEYWORDS][K_NAME]
			return keyfind(name, -1)
			
		else
			InternalErr("Scanner()")  
		
		end if
   end while
end function
scanner_rid = routine_id("Scanner")

global procedure eu_namespace()
-- add the "eu" namespace
	token eu_tok
	symtab_index eu_ns
	
	eu_tok = keyfind("eu", -1)
	-- create a new entry at beginning of this hash chain
	eu_ns  = NameSpace_declaration(eu_tok[T_SYM])
	SymTab[eu_ns][S_OBJ] = 0
	SymTab[eu_ns][S_SCOPE] = SC_GLOBAL
end procedure

global function StringToken()
-- scans until blank, tab, end of line, or end of file. 
-- returns a raw string - leading whitespace ignored, 
-- comment chopped off.
-- no escape characters are processed 
	integer ch, m
	sequence gtext
	
	-- skip leading whitespace  
	ch = getch()
	while ch = ' ' or ch = '\t' do
		ch = getch()
	end while

	gtext = ""
	while not find(ch,  {' ', '\t', '\n', '\r', END_OF_FILE_CHAR}) do 
		gtext &= ch
		ch = getch()
	end while
	ungetch()
	m = match("--", gtext)
	if m then
		gtext = gtext[1..m-1]
		if ch = ' ' or ch = '\t' then
			read_line()
		end if
	end if
	return gtext
end function

global function IntegerToken()
	integer ch
	sequence gtext
	
	-- skip leading whitespace  
	ch = getch()
	while ch = ' ' or ch = '\t' do
		ch = getch()
	end while

	gtext = ""
	-- 1st ch can have #, + or -
	if find(ch, "#+-0123456789") then
		gtext &= ch
		ch = getch()
	end if
	while find(ch,  "0123456789") do
		gtext &= ch
		ch = getch()
	end while
	ungetch()

	gtext = value(gtext)

	if gtext[1] != GET_SUCCESS then
		CompileErr("Integer expected")
	end if

	return gtext[2]
end function

global procedure IncludeScan( integer exported )
-- Special scan for an include statement:
-- include filename as namespace
   
-- We need a special scan because include statements:
--    - have special rules regarding filename syntax
--    - must fit on one line by themselves (to avoid tricky issues)
--    - we don't want to introduce "as" as a new scanning keyword
 
	integer ch
	sequence gtext
	token s
	
	-- we have just seen the "include" keyword  
	
	-- skip leading whitespace  
	ch = getch()
	while ch = ' ' or ch = '\t' do
		ch = getch()
	end while

	-- scan required filename into gtext  
	gtext = ""
	
	if ch = '"' then
		-- quoted filename  
		ch = getch()
		while not find(ch, {'\n', '\r', '"', END_OF_FILE_CHAR}) do         
			if ch = '\\' then
				ch = EscapeChar(getch())
			end if
			gtext &= ch
			ch = getch()
		end while
		if ch != '"' then
			CompileErr("missing closing quote on file name")
		end if
	else 
		-- unquoted filename  
		while not find(ch, {' ', '\t', '\n', '\r', END_OF_FILE_CHAR}) do  
			gtext &= ch
			ch = getch()
		end while
		ungetch()
	end if
	
	if length(gtext) = 0 then
		CompileErr("file name is missing")
	end if
	
	-- record the new filename  
	new_include_name = gtext  

	-- skip whitespace  
	ch = getch()
	while ch = ' ' or ch = '\t' do
		ch = getch()
	end while   
	
	new_include_space = 0
	
	if ch = 'a' then
		-- scan optional "as" clause  
		ch = getch()
		if ch = 's' then
			ch = getch()
			if ch = ' ' or ch = '\t' then
				
				-- skip whitespace  
				ch = getch()
				while ch = ' ' or ch = '\t' do
					ch = getch()
				end while
				
				-- scan namespace identifier  
				if char_class[ch] = LETTER then
					gtext = {ch}
					ch = getch()
					while char_class[ch] = LETTER or
						  char_class[ch] = DIGIT or
						  ch = '_' do
						gtext &= ch
						ch = getch()
					end while
					
					ungetch()
					s = keyfind(gtext, -1)
					if not find(s[T_ID], {VARIABLE, FUNC, TYPE, PROC}) then
						CompileErr("a new namespace identifier is expected here")
					end if
					new_include_space = NameSpace_declaration(s[T_SYM])
				else 
					CompileErr("missing namespace qualifier")
				end if
			else 
				CompileErr("improper syntax for include-as")
			end if
		else 
			CompileErr("improper syntax for include-as")
		end if
	else 
		ungetch()
	end if
	
	start_include = TRUE -- let scanner know
	export_include = exported
end procedure


-- start parsing the main file
global procedure main_file()
	read_line()
	default_namespace( 0, 0 )
end procedure
