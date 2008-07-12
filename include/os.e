-- (c) Copyright 2008 Rapid Deployment Software - See License.txt
--
--****
-- == Operating System Helpers
-- **Page Contents**
--
-- <<LEVELTOC depth=2>>
--

include sequence.e
include math.e
include text.e

ifdef !DOS32 then
include dll.e
end ifdef
include machine.e

constant M_SLEEP = 64, M_SET_ENV = 73, M_UNSET_ENV = 74

--****
-- === Constants
--
-- ==== Operating System Constants
--
-- These constants are returned by the [[:platform]] function.
--
-- * DOS32 - Host operating system is DOS
-- * WIN32 - Host operating system is Windows
-- * LINUX - Host operating system is Linux **or** FreeBSD
-- * FREEBSD - Host operating system is Linux **or** FreeBSD
-- * OSX - Host operating system is Mac OS X
--
-- Note:
-- Via the [[:platform]] call, there is no way to determine if you are on Linux
-- or FreeBSD. This was done to provide a generic UNIX return value for
-- [[:platform]].
--
-- In most situations you are better off to test the host platform by using
-- the [[:ifdef statement]]. It is both more accurate and faster.
--

global constant
	DOS32	= 1, -- ex.exe
	WIN32	= 2, -- exw.exe
	LINUX	= 3, -- exu
	FREEBSD = 3, -- exu
	OSX		= 4  -- exu

export constant
	NO_PARAMETER = 0,
	HAS_PARAMETER = 1,
	NO_CASE = 0,
	HAS_CASE = 1

enum
	SINGLE,
	DOUBLE,
	HELP,
	PARAM,
	RID,
	USECASE


--****
-- === Routines
--

--**
-- Show help message for the given opts.
--
-- Parameters:
-- # ##opts##: a sequence of options. See the Comments: section for details
-- # ##add_help_rid##: an integer, the routine_id of a procedure that will be called on
--     completion. Defaults to -1 (no call).
--
-- Comments:
-- If ##add_help_rid## is specified, it must be the id of a procedure that takes no arguments.
--
-- ##opts## is a sequence of records, each of which describes a command line option for a program.
-- The name of the program is fetched from the command line. Each option record is a 5 element
-- sequence
-- # a sequence representing some text following a "-". Use an atom if not relevant;
-- # a sequence representing some text following a "--". Use an atom if not relevant;
-- # a sequence, some help text which concerns the above synonymous options.
-- # either 1 to denote a parameter of the options, or anything else if none.
-- # an integer, a routine_id. Currently not used by this procedure.
--
-- When the second element is specified and there is a parameter, the syntax "=x" is used. When
-- the first element is specified, the " x" syntax is used.
--
-- Example 1:
-- <eucode>
-- -- in myfile.ex
-- show_help({
--      {"q", "silent", "Suppresses any output to console", NO_PARAMETER, 0},
--      {"r", 0, "Sets how many lines the console should display", HAS_PARAMETER, 1}})
-- </eucode>
--
-- myfile.ex options:
-- -q, --silent		Suppresses any output to console
-- -r x				Sets how many lines the console should display

export procedure show_help(sequence opts, integer add_help_rid=-1)
	integer pad_size, this_size
	sequence cmds, cmd

	cmds = command_line()

	pad_size = 0
	for i = 1 to length(opts) do
		this_size = 0
		if sequence(opts[i][SINGLE]) then this_size += length(opts[i][SINGLE]) + 1 end if
		if sequence(opts[i][DOUBLE]) then this_size += length(opts[i][DOUBLE]) + 2 end if

		if equal(opts[i][PARAM],HAS_PARAMETER) then
			this_size += 4
		end if

		pad_size = max({pad_size, this_size + 6})
	end for

	printf(1, "%s options:\n", {cmds[2]})
	for i = 1 to length(opts) do
		cmd = ""
		if sequence(opts[i][SINGLE]) then
			cmd &= '-' & opts[i][SINGLE]
			if equal(opts[i][PARAM],HAS_PARAMETER) then
				cmd &= " x"
			end if
		end if
		if sequence(opts[i][DOUBLE]) then
			if length(cmd) > 0 then cmd &= ", " end if
			cmd &= "--" & opts[i][DOUBLE]
			if equal(opts[i][PARAM], HAS_PARAMETER) then
				cmd &= "=x"
			end if
		end if
		puts(1, "     " & pad_tail(cmd, pad_size))
		puts(1, " " & opts[i][HELP] & '\n')
	end for

	if add_help_rid >= 0 then
		puts(1, "\n")
		call_proc(add_help_rid, {})
	end if
end procedure

function find_opt(sequence opts, integer typ, object name)
	integer slash
	sequence lResult
	integer lPos = 0
	sequence lOptName
	object lOptParam

	lOptName = repeat(' ', length(name))
	lOptParam = 0
	for i = 1 to length(name) do
		if name[i] = '"' then
			lPos = i
		elsif find(name[i], ":=") then
			if lPos = 0 then
				lPos = i
				lOptName = lOptName[1..lPos-1]
				lOptParam = name[lPos + 1 .. $]
				exit
			end if
		end if

		lOptName[i] = name[i]
	end for


	slash = 0 -- should we check both single char and words?
	if typ = 3 then
		slash = 1
		typ = 2
	end if

	for i = 1 to length(opts) do
		if length(opts[i]) > 5 then
			if equal(opts[i][6], NO_CASE) then
				if equal(lower(lOptName), lower(opts[i][typ])) or 
					(slash and equal(lower(lOptName), lower(opts[i][1]))) 
				then
					return {i, lOptParam}
				end if
			end if
		end if

		if equal(lOptName, opts[i][typ]) or (slash and equal(lOptName, opts[i][1])) then
			return {i, lOptParam}
		end if
	end for

	return {0, "Unrecognised"}
end function

--**
-- Parse command line options, and optionally call procedures that relate to these options
--
-- Parameters:
-- * ##opts## - a sequence of valid option records: See Comments: section for details
-- * ##add_help_rid## - an integer, the id of ???. Defaults to -1.
--
-- Returns:
--  A **sequence**, the list of all command line arguments.
--
-- Comments:
-- 6 sorts of tokens are recognized on the command line:
-- # a single '-'. Simply added to the option list
-- # a single "~-~-". This signals the end of command line options. What remains of the command
--   line is added to the option list, and the parsing terminates.
-- # -something. The option will be looked up in ##opts##.
-- # ~-~-something. Ditto.
-- # /something. Ditto.
-- # anything else. The word is simply aded to the option list.
--
-- On a failed lookup, the progam shows the help by calling [[:show_help]](##opts##,
-- ##add_help_rid##) and terminates with status code 1.
--
-- Option records have the following structure:
-- # a sequence representing some text following a "-". Use an atom if not relevant;
-- # a sequence representing some text following a "~-~-". Use an atom if not relevant;
-- # a sequence, some help text which concerns the above synonymous options.
-- # either ##HAS_PARAMETER## to denote a parameter of the options, or anything else if none.
-- # an integer, a [[:routine_id]]. This id will be called when a lookup he this entry.
-- # an integer, a value of ##NO_CASE## to indicate that the case of the supplied option
--   is not significant.
--
-- The fifth member of the record must be the id of a procedure. If the fourth member is
-- ##NO_PARAMETER##, the rocedure takes no argument. Otherwise, it will be passed a sequence,
-- the next word on the command line.
--
-- For more details on how the command line is being pre parsed, see [[:command_line]].
--
-- Example:
-- <eucode>
-- integer verbose = 0
-- sequence output_filename = ""
--
-- procedure opt_verbose()
--     verbose = 1
-- end procedure
--
-- procedure opt_output_filename(object param)
--     output_filename = param
-- end procedure
--
-- sequence opts = {
--     { "v", "verbose", "Verbose output",	NO_PARAMETER, routine_id("opt_verbose") },
--     { "o", "output",  "Output filename", HAS_PARAMETER, routine_id("opt_output_filename") }
-- }
--
-- sequence extras = cmd_parse(opts)
--
-- -- When run as: exu/exwc myprog.ex -v -o john.txt input1.txt input2.txt
-- -- verbose will be 1, output_filename will be "john.txt" and
-- -- extras = { "input1.txt", "input2.txt" }
-- </eucode>
--
-- See Also:
--     [[:show_help]], [[command_line]]

export function cmd_parse(sequence opts, integer add_help_rid=-1, sequence cmds = command_line())
	integer idx, opts_done
	sequence cmd, extras
	sequence param
	sequence find_result
	integer lType
	integer lFrom

	extras = {}
	idx = 2
	opts_done = 0

	while idx < length(cmds) do
		idx += 1

		cmd = cmds[idx]
		if opts_done then
			extras = append(extras, cmd)
			continue
		end if

		if equal(cmd, "--") then
			opts_done = 1
			continue
		end if

		if find(cmd[1], "-/") =  0 then
			extras = append(extras, cmd)
			continue
		end if


		if length(cmd) = 1 then
			extras = append(extras, cmd)
			continue
		end if

		if equal(cmd[1..2], "--") then	  -- found --opt-name
			lType = 2
			lFrom = 3
		elsif cmd[1] = '-' then -- found -opt
			lType = 1
			lFrom = 2
		else  -- found /opt
			lType = 3
			lFrom = 2
		end if

		find_result = find_opt(opts, lType, cmd[lFrom..$])

		if find_result[1] = 0 then
			-- something is wrong with the option
			printf(1, "%s option: %s\n\n", {find_result[2], cmd})
			show_help(opts, add_help_rid)
			abort(1)
		elsif find_result[1] > 0 then
			if equal(opts[find_result[1]][PARAM],HAS_PARAMETER) then
				idx += 1
				if idx <= length(cmds) then
					param = {cmds[idx]}
				else
					param = {""}
				end if

			elsif equal(opts[find_result[1]][PARAM],NO_PARAMETER) then
				param = {}

			elsif sequence(opts[find_result[1]][PARAM]) then
				if atom(find_result[2]) then
					idx += 1
					if idx <= length(cmds) then
						param = {cmds[idx]}
					else
						param = {""}
					end if
				else
					param = {find_result[2]}
				end if

			else
				-- Unknown option parameter so don't call the RID.
				opts[find_result[1]][RID] = -1
			end if

			if opts[find_result[1]][RID] >= 0 then
				call_proc(opts[find_result[1]][RID], param)
			end if
		end if

	end while

	return extras
end function

--**
-- Suspend thread execution. for ##t## seconds.
--
-- Parameters:
-- # ##t##: an atom, the number of seconds for which to sleep.
--
-- Comments:
-- On //Windows// and //Unix//, the operating system will suspend your process and
-- schedule other processes. On //DOS//, your program will go into a busy loop for
-- ##t## seconds, during which time other processes may run, but they will compete
-- with your process for the CPU.
--
-- With multiple tasks, the whole program sleeps, not just the current task. To make
-- just the current task sleep, you can call ##[[:task_schedule]]([[:task_self]](), {i, i})##
-- and then execute ##[[:task_yield]]()##.
--
-- Example:
-- <eucode>
-- puts(1, "Waiting 15 seconds...\n")
-- sleep(15)
-- puts(1, "Done.\n")
-- </eucode>
--
-- See Also:
--     [[:task_schedule]], [[:tick_rate]], [[:task_yield]]

global procedure sleep(atom t)
-- go to sleep for t seconds
-- allowing (on WIN32 and Linux) other processes to run
	if t >= 0 then
		machine_proc(M_SLEEP, t)
	end if
end procedure

constant M_INSTANCE = 55

--**
-- Return ##hInstance## on //Windows//, Process ID (pid) on //Unix// and 0 on //DOS//
--
-- Comments:
-- On //Windows// the ##hInstance## can be passed around to various
-- //Windows// routines.

export function instance()
	return machine_func(M_INSTANCE, 0)
end function

ifdef WIN32 then
	constant UNAME = define_c_func(open_dll("kernel32.dll"), "GetVersionExA", {C_POINTER}, C_INT)
elsifdef LINUX then
	constant UNAME = define_c_func(open_dll(""), "uname", {C_POINTER}, C_INT)
elsifdef FREEBSD then
	constant UNAME = define_c_func(open_dll("libc.so"), "uname", {C_POINTER}, C_INT)
elsifdef OSX then
	constant UNAME = define_c_func(open_dll("libc.dylib"), "uname", {C_POINTER}, C_INT)
end ifdef

--**
-- Retrieves the nme of the host OS.
--
-- Returns:
--    A **sequence**, starting with the OS name. If identification fails, returned string
--    is "". Extra information deoends on the OS (details unavailable).

export function uname()
	ifdef WIN32 then
		atom buf
		sequence sbuf
		integer maj, mine, build, plat
		buf = allocate(148)
		poke4(buf, 148)
		if c_func(UNAME, {buf}) then
			maj = peek4u(buf+4)
			mine = peek4u(buf+8)
			build = peek4u(buf+12)
			plat = peek4u(buf+16)
			sbuf = {}
			if plat = 0 then
				sbuf = append(sbuf, "Win32s")
				sbuf = append(sbuf, sprintf("Windows %d.%d", {maj,mine}))
			elsif plat = 1 then
				sbuf = append(sbuf, "Win9x")
				if mine = 0 then
					sbuf = append(sbuf, "Win95")
				elsif mine = 10 then
					sbuf = append(sbuf, "Win98")
				elsif mine = 90 then
					sbuf = append(sbuf, "WinME")
				else
					sbuf = append(sbuf, "Unknown")
				end if
			elsif plat = 2 then
				sbuf = append(sbuf, "WinNT")
				if maj = 6 and mine = 1 then
					sbuf = append(sbuf, "Windows7")
				elsif maj = 6 and mine = 0 then
					sbuf = append(sbuf, "Vista")
				elsif maj = 5 and mine = 1 or 2 then
					sbuf = append(sbuf, "WinXP")
				elsif maj = 5 and mine = 0 then
					sbuf = append(sbuf, "Win2K")
				elsif maj = 4 and mine = 0 then
					sbuf = append(sbuf, "WinNT 4.0")
				elsif maj = 3 and mine = 51 then
					sbuf = append(sbuf, "WinNT 3.51")
				elsif maj = 3 and mine = 50 then --is it 50 or 5?
					sbuf = append(sbuf, "WinNT 3.5")
				elsif maj = 3 and mine = 1 then
					sbuf = append(sbuf, "WinNT 3.1")
				else
					sbuf = append(sbuf, sprintf("WinNT %d.%d", {maj,mine}))
				end if
			elsif plat = 3 then
				sbuf = append(sbuf, "WinCE")
				sbuf = append(sbuf, sprintf("WinCE %d.%d", {maj,mine}))
			else
				sbuf = append(sbuf, "Unknown Windows")
				sbuf = append(sbuf, sprintf("Version %d.%d", {maj,mine}))
			end if
			sbuf = append(sbuf, peek_string(buf+20))
			sbuf &= {plat, build, mine, maj}
			return sbuf
		else
			return {}
		end if
	elsifdef UNIX then
		atom buf, pbuf
		integer len,i, c, k
		sequence sbuf, snam
		buf = allocate(4096) --excessive, but to be safe
		if c_func(UNAME, {buf}) = 0 then
			sbuf = {}
			pbuf = buf
			snam = ""
			i = 0
			k = 0
			while 1 do
				c = peek(pbuf)
				i = i + 1
				if c = 0 and length(snam) then
					sbuf = append(sbuf, snam)
					snam = ""
					k = k + 1
					if k > 4 then exit end if
				elsif c != 0 then
					snam &= c
					pbuf = pbuf + 1
					i = i + 1
				else
					pbuf = pbuf + 1
					i = i + 1
				end if
			end while
			free(buf)
			return sbuf
		else
			free(buf)
			return ""
		end if
	elsifdef DOS32 then
		return {"DOS"} --TODO
	else
		return {"UNKNOWN"} --TODO
	end ifdef
end function

--**
-- Decides whether the host system is a newer Windows version (NT/2K/XP/Vista).
--
-- Returns:
-- An **integer**, 1 if host system is a newer Windows (NT/2K/XP/Vista), else 0.

export function is_win_nt()
	ifdef WIN32 then
		sequence s
		s = uname()
		return equal(s[1], "WinNT")
	else
		return -1
	end ifdef
end function

--**
-- Set an environment variable
--
-- Parameters:
-- * ##name## - envionment variable name
-- * ##val## - value to set to
-- * ##overwrite## - overwrite an existing variable? TRUE/FALSE
--
-- Example 1:
-- <eucode>
-- ? setenv("NAME", "John Doe")
-- ? setenv("NAME", "Jane Doe")
-- ? setenv("NAME", "Jim Doe", 0)
-- </eucode>
--
-- See Also:
--   [[:getenv]], [[:unsetenv]]

export function setenv(sequence name, sequence val, integer overwrite=1)
	return machine_func(M_SET_ENV, {name, val, overwrite})
end function

--**
-- Unset an environment variable
--
-- Parameters:
-- * ##name## - name of environment variable to unset
--
-- Example 1:
-- <eucode>
-- ? unsetenv("NAME")
-- </eucode>
--
-- See Also:
--   [[:setenv]], [[:getenv]]

export function unsetenv(sequence env)
	return machine_func(M_UNSET_ENV, {env})
end function

