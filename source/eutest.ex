#!/usr/bin/env eui
-- (c) Copyright - See License.txt

-- TODO: Extract log parsing code into it's own file
-- TODO: Use templates (with defaults supplied) for HTML reports, thus
--       users will be able to theme the unit test reports to fit into
--       their own project pages. Further, it will simplify the output
--       code quite a bit

include std/pretty.e
include std/sequence.e
include std/sort.e
include std/filesys.e as fs
include std/io.e
include std/get.e
include std/os.e as ut
include std/text.e 
include std/math.e
include std/search.e  as search
include std/error.e as e
include std/types.e as types
include std/map.e
include std/cmdline.e
include std/eds.e

constant cmdopts = {
	{"exe", 0, "interpreter path", { NO_CASE, HAS_PARAMETER, "path-to-interpreter"} },
	{"ec",  0, "translator path",  { NO_CASE, HAS_PARAMETER, "path-to-translator"} },
	{"trans", 0, "translate using default translator", { NO_CASE } },
	{"lib", 0, "runtime library path", {NO_CASE, HAS_PARAMETER, "path-to-runtime-library"} },
	{"cc",  0, "C compiler", { NO_CASE, HAS_PARAMETER, "-wat|wat|gcc|compiler-name"} },
	{"log", 0, "output a log", { NO_CASE } },
	{"verbose", 0, "verbose output", {NO_CASE} },
	{"process-log", 0, "", {NO_CASE} },
	{"html", 0, "", {NO_CASE} },
	{"html-file", 0, "output file for html log output", {NO_CASE, HAS_PARAMETER, "html output file"}},
	{"i", 0, "include directory", {NO_CASE, MULTIPLE, HAS_PARAMETER, "directory"}},
	{"d", 0, "define a preprocessor word", {NO_CASE, MULTIPLE, HAS_PARAMETER, "word"}},
	{ "coverage",  0, "Indicate files or directories for which to gather coverage statistics", 
		{ NO_CASE, MULTIPLE, HAS_PARAMETER, "dir|file" } },
	{ "coverage-db",  0, "Specify the filename for the coverage database.", 
		{ NO_CASE, HAS_PARAMETER, "file" } },
	{ "coverage-erase",  0, "Erase an existing coverage database and start a new coverage analysis.", 
		{ NO_CASE } },
	{ "coverage-pp", 0, "Path to eucoverage.ex for post processing", {NO_CASE, HAS_PARAMETER, "path-to-eucoverage.ex"} },
	{ "coverage-exclude", 0, "Pattern for files to exclude from coverage", { NO_CASE, MULTIPLE, HAS_PARAMETER, "pattern"}},
	{ "testopt", 0, "option for tester", { NO_CASE, HAS_PARAMETER, "test-opt"} },
	{ "bind", 0, "path to bind.ex", { NO_CASE, HAS_PARAMETER, "bind.ex"} },
	{ "all", 0, "show tests that pass and fail", {} },
	{ "failed", 0, "show tests that fail only", {} },
	{ "wait", 0, "Wait on summary", {} },	
	{ "accumulate", 0, "Count the individual tests in each file", {} },
	$ }

constant USER_BREAK_EXIT_CODES = {255,-1073741510}
integer verbose_switch = 0
object void
integer ctcfh = 0
sequence error_list = repeat({},4)

-- moved from do_test:
integer logging_activated = 0
integer failed = 0
integer total
sequence 
	dexe = "", 
	executable = ""

object html_fn = 1

enum E_NOERROR, E_INTERPRET, E_TRANSLATE, E_COMPILE, E_EXECUTE, E_BIND, E_BOUND, E_EUTEST

type error_class(object i)
	return integer(i) and i >= 1 and i <= E_EUTEST
end type

procedure error(sequence file, error_class e, sequence message, sequence vals, object error_file = 0)
	object lines
	integer bad_string_flag = 0
	if sequence(error_file) then
		lines = read_lines(error_file)
	else
		lines = 0
	end if

	for i = 1 to length(vals) do
		-- assume only nested sequences of vals[i] to be bad.
		if not atom(vals[i]) and not ascii_string(vals[i]) then
			bad_string_flag = 1
		end if
	end for
	if bad_string_flag then
	    for i = 1 to length(vals) do
	    	vals[i] = pretty_sprint(vals[i], {2} )
	    end for
	end if
	
	error_list = {
		append(error_list[1], file),
		append(error_list[2], sprintf(message, vals)),
		append(error_list[3], e),
		append(error_list[4], lines)
	}
end procedure

procedure verbose_printf(integer fh, sequence fmt, sequence data={})
	if verbose_switch then
		printf(fh, fmt, data)
	end if
end procedure

function run_emake()
	-- parse and run the commands in emake.bat.
	object file

	ifdef UNIX then
		file = read_lines("emake")
	elsedef
		file = read_lines("emake.bat")
	end ifdef

	if atom(file) then
		return 1
	end if

	for i = 1 to length(file) do
		sequence line = file[i]

		if length(line) < 4 or
			match("rem ", line) = 1 or
			match("echo ", line) or
			equal("if ", line[1..3]) or
			match("@echo", line) = 1 or
			match("goto ", line) or
			line[1] = '#' or
			line[1] = ':'
		then

			-- Do nothing with these lines
		
		elsif match("set ", line) = 1 then 
			sequence pair
			pair = split(line[5..$], "=")
			pair = {setenv(pair[1], pair[2])}

		elsif match("move ", line) = 1 or
			equal("del ", line[1..4]) then
			system(line, 2)

		else
			integer status = system_exec(line, 2)

			if status then
				sequence source = ""
				integer dl = match(".c", line)

				for ws = dl to 1 by -1 do
					if line[ws] = ' ' then
						source = line[ws+1..dl-1]
						exit
					end if
				end for

				return { E_COMPILE,  "program could not be compiled.  Error %d executing:%s",
					{ status, line }, source & ".err" }
			end if
		end if

		puts(1,'.')
	end for

	puts(1,"\n")

	return 0
end function

-- runs cmd using system exec tests for returned error values
-- and error files.  Before the command is run, the error files
-- are deleted and just before the functions exits the error 
-- files are deleted unless REC is defined.
-- returns 0 iff no errors were raised
function invoke(sequence cmd, sequence filename, integer err)
	integer status
	
	delete_file("cw.err")
	delete_file("ex.err")

	status = system_exec(cmd, 2)
	if find(status, USER_BREAK_EXIT_CODES) > 0 then
		-- user break
		abort(status)
	end if

	sleep(0.1)
	
	if file_exists("cw.err") then
		error(filename, err, "Causeway error with status %d", {status}, "cw.err")

		if not status then
			status = 1
		end if

		ifdef not REC then
			delete_file("cw.err")
		end ifdef

	elsif file_exists("ex.err") then
		error(filename, err, "EUPHORIA error with status %d", {status}, "ex.err")

		if not status then
			status = 1
		end if

		ifdef not REC then
			delete_file("ex.err")
		end ifdef

	elsif status then
		error(filename, err, "program died with status %d", {status})
	end if
	
	return status
end function

-- returns the location in the log file if there has been
-- writing to the log or or a string indicating which error 
function check_log(integer log_where)

	integer log_fd = open("unittest.log", "a")
	atom pos
					
	if log_fd = -1  then
		return "couldn't generate unittest.log"
	else
		pos = where(log_fd)
		if log_where = pos then
			close(log_fd)
			return  "couldn't add to unittest.log"
		end if
	end if	

	log_where = where(log_fd)
	close(log_fd)

	return log_where
end function

procedure report_last_error(sequence filename)
	if length(error_list) and length(error_list[3])  then
		if error_list[3][$] = E_NOERROR then
			verbose_printf(1, "SUCCESS: %s %s\n", {filename, error_list[2][length(error_list[1])]})
		else
			printf(1, "FAILURE: %s %s\n", {filename, error_list[2][length(error_list[1])]})
		end if
	end if
end procedure

function prepare_error_file(object file_name)
	integer pos
	object file_data
	
	file_data = read_lines(file_name)
	
	if atom(file_data) then
		return file_data
	end if
	
	if length(file_data) > 4 then
		file_data = file_data[1..4]
	end if
	for i = 1 to length(file_data) do
		pos = find('=', file_data[i])
		if pos then
			if length(file_data[i]) >= 6 then
				if equal(file_data[i][1..4], "    ") then
					file_data = file_data[1 .. i-1]
					exit
				end if
			end if
		end if
		if equal(file_data[i], "Global & Local Variables") then
			file_data = file_data[1 .. i-1]
			exit
		end if
		if equal(file_data[i], "--- Defined Words ---") then
			file_data = file_data[1 .. i-1]
			exit
		end if
	end for
	
    sequence path
    if length(file_data) >= 2 then
    	path = "\\/" & file_data[1]
    	path = path[max(rfind('/', path) & rfind('\\', path))+1..$]
    	file_data[1] = path
    else
    	-- Malformed error file
    	file_data = 0
    end if
    
    return file_data
end function

function check_errors( sequence filename, sequence fail_list )
	object expected_err
	object actual_err
	integer some_error = 0
	
	expected_err = prepare_error_file( find_error_file( filename ) )
	if atom(expected_err) then
		error(filename, E_INTERPRET, "No valid control file was supplied.", {})
		some_error = 1
	elsif length(expected_err) = 0 then
		error(filename, E_INTERPRET, "Unexpected empty control file.", {})
		some_error = 1
	end if
	
	if not some_error then
		actual_err = prepare_error_file("ex.err")
		if atom(actual_err) then
			error(filename, E_INTERPRET, "No valid ex.err has been generated.", {})
			some_error = 1
		elsif length(actual_err) = 0 then
			error(filename, E_INTERPRET, "Unexpected empty ex.err.", {})
			some_error = 1
		end if
	
		if not some_error then
			-- N.B. Do not compare the first line as it contains PATH 
			-- information which can vary from system to system.			
			if not equal(actual_err[2..$], expected_err[2..$]) then
		
				error(filename, E_INTERPRET, "Unexpected ex.err.  Expected:\n----\n" &
						"%s\n----\nbut got\n----\n%s\n----\n",
						{join(expected_err,"\n"), join(actual_err, "\n")}, "ex.err")
				some_error = 1
			end if
		end if
	end if
	
	if some_error then	
		failed += 1
		fail_list = append(fail_list, filename)
	end if
	return fail_list
end function

function find_error_file( sequence filename )
	sequence control_error_file
	sequence base_filename
	
	base_filename = filename[1 .. find('.', filename & '.') - 1] & ".d" & SLASH
	
	-- try tests/t_test.d/interpreter/UNIX/control.err
	control_error_file =  base_filename & "interpreter" & SLASH & interpreter_os_name & SLASH & "control.err"
	if file_exists(control_error_file) then
		return control_error_file
	end if
	
	-- try tests/t_test/UNIX/control.err
	control_error_file =  base_filename & interpreter_os_name & SLASH & "control.err"
	if file_exists(control_error_file) then
		return control_error_file
	end if

	-- try tests/t_test/control.err
	control_error_file = base_filename & "control.err"
	if file_exists(control_error_file) then
		return control_error_file
	end if

	return -1
end function

function interpret_fail( sequence cmd, sequence filename,  sequence fail_list )
	integer status = system_exec(cmd, 2)
	integer old_length
	
	-- Now we will compare the control error file to the newly created 
	-- ex.err.  If ex.err doesn't exist or there is no match error()
	-- is called and we add to the failed list.
	old_length = length( fail_list )
	fail_list = check_errors( filename, fail_list )

	if old_length = length( fail_list ) then
		-- No new errors found.
		if status = 0 then
			-- We were expecting the test program to crash, but it didn't.
			failed += 1
			fail_list = append(fail_list, filename)
			error(filename, E_INTERPRET,
				"The unit test did not crash, which was unexpected.", {})
		else						
			error(filename, E_NOERROR, "The unit test crashed in the expected manner. " &
				"Error status %d.", {status})
		end if
	end if
	return fail_list
end function

function translate( sequence filename, sequence fail_list )
	printf(1, "translating, compiling, and executing executable: %s\n", {filename})
	total += 1
	sequence cmd = sprintf("%s %s %s %s -D UNITTEST -D EC -batch %s",
		{ translator, library, compiler, translator_options, filename })
	verbose_printf(1, "CMD '%s'\n", {cmd})
	integer status = system_exec(cmd, 0)

	filename = filebase(filename)
	integer log_where = 0
	if status = 0 then
		sequence exename = filename & dexe

		void = delete_file(exename)
		void = delete_file("cw.err")
		verbose_printf(1, "compiling %s%s\n", {filename, ".c"})

		object emake_outcome = run_emake()
		if equal(emake_outcome, 0) then
			verbose_printf(1, "executing %s:\n", {exename})
			cmd = sprintf("./%s %s", {exename, test_options})
			status = invoke(cmd, exename,  E_EXECUTE) 
			if status then
				failed += 1
				fail_list = append(fail_list, "translated" & " " & exename)
			else
				object token
				if logging_activated then
					token = check_log(log_where)
				else
					token = 0
				end if

				if sequence(token) then
					failed += 1
					fail_list = append(fail_list, "translated" & " " & exename)					
					error(exename, E_EXECUTE, token, {}, "ex.err")
				else
					log_where = token
					error(exename, E_NOERROR, "all tests successful", {})
				end if -- sequence(token)
			end if
			
			void = delete_file(exename)
		else
			failed += 1
			fail_list = append(fail_list, "compiling " & filename)					
			if sequence(emake_outcome) then
				error(exename, E_COMPILE, emake_outcome[2], emake_outcome[3], emake_outcome[4])
				status = emake_outcome[3][1]
			else
				error(exename, E_COMPILE, 
					"program could not be compiled. Compilation process exited with status %d", {emake_outcome})
			end if
		end if
	else
		failed += 1
		fail_list = append(fail_list, "translating " & filename)
		error(filename, E_TRANSLATE, "program translation terminated with a bad status %d", {status})                               
	end if
	report_last_error(filename)
	return fail_list
end function

function bind( sequence filename, sequence fail_list )
	sequence cmd = sprintf("%s %s -batch \"%s\" %s -batch -D UNITTEST %s",
		{ executable, interpreter_options, binder, interpreter_options, filename } )
	total += 1
	verbose_printf(1, "CMD '%s'\n", {cmd})
	integer status = system_exec(cmd, 0)

	filename = filebase(filename)
	integer log_where = 0
	if status = 0 then
		sequence exename = filename & dexe
		verbose_printf(1, "executing %s:\n", {exename})
		cmd = sprintf("./%s %s", {exename, test_options})
		status = invoke(cmd, exename,  E_EXECUTE) 
		if status then
			failed += 1
			fail_list = append(fail_list, "bound" & " " & exename)
		else
			object token
			if logging_activated then
				token = check_log(log_where)
			else
				token = 0
			end if

			if sequence(token) then
				failed += 1
				fail_list = append(fail_list, "bound" & " " & exename)					
				error(exename, E_BOUND, token, {}, "ex.err")
			else
				log_where = token
				error(exename, E_NOERROR, "all tests successful", {})
			end if -- sequence(token)
		end if
			
		void = delete_file(exename)
		
	else
		failed += 1
		fail_list = append(fail_list, "binding " & filename)
		error(filename, E_BIND, "program binding terminated with a bad status %d", {status})                               
	end if
	report_last_error(filename)
	return fail_list
end function

function test_file( sequence filename, sequence fail_list )

	integer log_where = 0 -- keep track of unittest.log
	integer status
	void = delete_file("ex.err")
	void = delete_file("cw.err")
	
	sequence crash_option = ""
	if match("t_c_", filename) = 1 then
		crash_option = " -D CRASH "
	end if
	
	printf(1, "interpreting %s:\n", {filename})
	sequence cmd = sprintf("%s %s %s -D UNITTEST -batch %s%s %s",
		{ executable, interpreter_options, coverage_erase, crash_option, filename, test_options })

	verbose_printf(1, "CMD '%s'\n", {cmd})
	
	integer expected_status
	if match("t_c_", filename) = 1 then
		-- We expect this test to fail
		expected_status = 1
		fail_list = interpret_fail( cmd, filename, fail_list )
		
	else -- not match(t_c_*.e)
		-- in this branch error() is called once and only once in all sub-branches
		expected_status = 0
		status = invoke(cmd, filename, E_INTERPRET) -- error() called if status != 0

		if status then
			failed += 1
			fail_list = append(fail_list, filename)
			-- error() called in invoke()
		else
			object token
			if logging_activated then
				token = check_log(log_where)
			else
				token = 0
			end if

			if sequence(token) then
				failed += 1
				fail_list = append(fail_list, filename)					
				error(filename, E_INTERPRET, token, {}, "ex.err")
			else
				log_where = token
				error(filename, E_NOERROR, "all tests successful", {})
			end if
		end if
	end if

	ifdef REC then
		if status then
			if match("t_c_", filename) != 1 then
				directory = filename[1..find('.',filename&'.')] & "d" & SLASH & interpreter_os_name
			else
				directory = filename[1..find('.',filename&'.')] & "d"
			end if

			create_directory(filename[1..find('.',filename&'.')] & "d")
			create_directory(directory)

			if not move_file("ex.err", directory & SLASH & "control.err") then
				e:crash("Could not move 'ex.err' to %s", { directory & SLASH & "control.err" })
			end if
		end if
	end ifdef
	
	report_last_error(filename)
	
	if length(binder) and expected_status = 0 then
		fail_list = bind( filename, fail_list )
	end if
	
	if length(translator) and expected_status = 0 then
		fail_list = translate( filename, fail_list )
	end if
	
	return fail_list
end function

sequence interpreter_options = ""
sequence translator_options = "-emake "
sequence test_options = ""
sequence translator = "", library = "", compiler = ""
sequence interpreter_os_name

sequence binder = ""
sequence coverage_db    = ""
sequence coverage_pp    = ""
sequence coverage_erase = ""

procedure ensure_coverage()
	-- ensure that everything was at least included
	if DB_OK != db_open( coverage_db ) then
		printf( 2, "Error reading coverage database: %s\n", {coverage_db} )
		return
	end if
	
	sequence tables = db_table_list()
	integer ix = 1
	while ix <= length(tables) do
		sequence table_name = tables[ix]
		if table_name[1] = 'l' 
		and db_table_size( table_name ) = 0 then
			ix += 1
		else
			tables = remove( tables, ix )
		end if
	end while
	db_close()
	interpreter_options &= " -test"
	for tx = 1 to length( tables ) do
		sequence table_name = tables[tx]
		test_file( table_name[2..$], {} )
	end for
end procedure

procedure process_coverage()
	if not length( coverage_db ) then
		return
	end if
	
	ensure_coverage()
	
	if not length( coverage_pp ) then
		return
	end if
	
	-- post process the database
	if system_exec( sprintf(`%s "%s"`, { coverage_pp, coverage_db }), 2 ) then
		puts( 2, "Error running coverage postprocessor\n" )
		printf(2,`CMD: %s "%s"`, { coverage_pp, coverage_db })
	end if
end procedure

procedure do_test( sequence files )
	atom score
	
	integer log_fd = 0
	sequence silent = ""
	
	total = length(files)

	if verbose_switch <= 0 then
		translator_options &= " -silent"
	end if

	sequence fail_list = {}
	if logging_activated then
		void = delete_file("unittest.dat")
		void = delete_file("unittest.log")
		void = delete_file("ctc.log")
		ctcfh = open("ctc.log", "w")
	end if

	for i = 1 to length(files) do
		fail_list = test_file( files[i], fail_list )
		coverage_erase = ""
	end for
	
	if logging_activated and ctcfh != -1 then
		print(ctcfh, error_list)
		puts(ctcfh, 10)

		if length(translator) > 0 then
			print(ctcfh, total)
		else
			print(ctcfh, 0)
		end if

		close(ctcfh)
	end if

	ctcfh = 0
	
	if total = 0 then
		score = 100
	else
		score = ((total - failed) / total) * 100
	end if

	puts(1, "\nTest results summary:\n")

	for i = 1 to length(fail_list) do
		printf(1, "    FAIL: %s\n", {fail_list[i]})
	end for

	printf(1, "Files (run: %d) (failed: %d) (%.1f%% success)\n", {total, failed, score})

	object temps, ln = read_lines("unittest.dat")
	if sequence(ln) then
		total = 0
		failed = 0

		for i = 1 to length(ln) do
			temps = value(ln[i])
			if temps[1] = GET_SUCCESS then
				total += temps[2][1]
				failed += temps[2][2]
			end if
		end for

		if total = 0 then
			score = 100
		else
			score = ((total - failed) / total) * 100
		end if

		printf(1, "Tests (run: %d) (failed: %d) (%.1f%% success)\n", {total, failed, score})
	end if
	
	process_coverage()
	
	abort(failed > 0)
end procedure

sequence unsummarized_files = {}

procedure ascii_out(sequence data)
	switch data[1] do
		case "file" then
			unsummarized_files = append(unsummarized_files, data[2])
			printf(1, "%s\n", { data[2] })
			puts(1, repeat('=', 76) & "\n")

			if find(data[2], error_list[1]) then
				printf(1,"%s\n",
				{ error_list[2][find(data[2],error_list[1])] })
			end if

		case "failed" then
			printf(1, "  Failed: %s (%f) expected ", { data[2], data[5] })
			pretty_print(1, data[3], {2, 2, 12, 78, "%d", "%.15g"})
			puts(1, " got ")
			pretty_print(1, data[4], {2, 2, 12, 78, "%d", "%.15g"})
			puts(1, "\n")

		case "passed" then
			sequence anum
			if data[3] = 0 then
				anum = "0"
			else
				anum = sprintf("%f", data[3])
			end if
			printf(1, "  Passed: %s (%s)\n", { data[2], anum })

		case "summary" then
			puts(1, repeat('-', 76) & "\n")

			if find(data[2], unsummarized_files) then
				unsummarized_files = unsummarized_files[1..find(data[2], unsummarized_files)-1] 
					& unsummarized_files[find(data[2], unsummarized_files)+1..$]
			end if

			sequence status
			if data[3] > 0 then
				status = "bad"
			else
				status = "ok"
			end if

			printf(1, "  (Tests: %04d) (Status: %3s) (Failed: %04d) (Passed: %04d) (Time: %f)\n\n", {
				data[2], status, data[3], data[4], data[5]
			})
	end switch
end procedure

function text2html(sequence t)
	integer f = length(t)

	while f do
		if t[f] = '<' then
			t = t[1..f-1] & "&lt;" & t[f+1..$]
		elsif t[f] = '>' then
			t = t[1..f-1] & "&gt;" & t[f+1..$]
		elsif t[f] > 127 then
			t = t[1..f-1] & sprintf("&#%x;", t[f..f]) & t[f+1..$]
		elsif t[f] = 10 then
			t = t[1..f-1] & "<br>" & t[f+1..$]
		end if

		f = f - 1
	end while

	return t
end function

sequence html_table_head = `
<table width=100%%>
<tr bgcolor=#dddddd>
<th colspan=3 align=left><a name='%s'>%s</a></th>
<td><a href='#summary'>all file summary</a></th>
</tr>
<tr><th>test name</th>
<th>test time</th>
<th>expected</th>
<th>outcome</th>
</tr>`

sequence html_table_error_row = `
<tr bgcolor="%s">
<th align="left" width="50%%">%s</td>
<td colspan="3">%s</td>
</tr>`

sequence html_table_error_content_begin = `
<tr bgcolor="#ffaaaa">
  <th colspan="4" align="left" width="50%">
    Error file contents follows below
  </th>
</tr>
<tr bgcolor="#ffaaaa">
  <td colspan="4" align="left" width="100%">
    <pre>
`

sequence html_table_error_content_end = `
	</pre>
  </td>
</tr>
`

sequence html_table_failed_row = `
<tr bgcolor="#ffaaaa">
  <th align=left width=50%%>%s</th>
  <td>%f</td>
  <td>%s</td>
  <td>%s</td>
</tr>
`

sequence html_table_passed_row = `
<tr bgcolor="#aaffaa">
  <th align=left width=50%%>%s</th>
  <td>%s</td>
  <td>&nbsp;</td>
  <td>&nbsp;</td>
</tr>
`

sequence html_table_summary = `
</table>
<p>
<strong>Tests:</strong> %04d
<strong>Failed:</strong> %04d
<strong>Passed:</strong> %04d
<strong>Time:</strong> %f
</p>`

sequence html_table_final_summary = `
<a name="summary"></a>
<table style="font-size: 1.5em">
  <tr>
	<th colspan="2" align="left">Overall</th>
  </tr>
  <tr>
	<th align="left">Total Tests:</th>
	<td>%04d</td>
  </tr>
  <tr>
	<th align="left">Total Failed:</th>
	<td>%04d</td>
  </tr>
  <tr>
	<th align="left">Total Passed:</th>
	<td>%04d</td>
  </tr>
  <tr>
	<th align="left">Total Time:</th>
	<td>%f</td>
  </tr>
</table>
</body>
</html>`

procedure html_out(sequence data)
	switch data[1] do
		case "file" then
			unsummarized_files = append(unsummarized_files, data[2])
			printf(1, html_table_head, { data[2], data[2] })

			integer err = find(data[2], error_list[1])
			if err then
				sequence color
				if error_list[3][err] = E_NOERROR then
					color = "#aaffaa"
				else
					color = "#ffaaaa"
				end if

				printf(1, html_table_error_row, { color, data[2], error_list[2][err] })
				
				if sequence(error_list[4][err]) then
					puts(1, html_table_error_content_begin)

					for i = 1 to length(error_list[4][err]) do
						printf(1,"%s\n", { text2html(error_list[4][err][i]) })
					end for

					puts(1, html_table_error_content_end)
				end if
			end if

		case "failed" then
			printf(1, html_table_failed_row, {
				data[2],
				sprint(data[5]),
				sprint(data[3]),
				sprint(data[4])
			})

		case "passed" then
			sequence anum

			if data[3] = 0 then
				anum = "0"
			else
				anum = sprintf("%f", data[3])
			end if

			printf(1, html_table_passed_row, { data[2], anum })

		case "summary" then
			if length(unsummarized_files) then
				unsummarized_files = unsummarized_files[1..$-1] 
			end if

			printf(1, html_table_summary, {
				data[2],
				data[3],
				data[4],
				data[5]
			})
	end switch
end procedure

procedure summarize_error(sequence message, error_class e, integer html)
	if find(e, error_list[3]) then
		if html then
			printf(1,message & "<br>\nThese were:\n", {sum(error_list[3] = e)})
		else
			printf(1,message & "\nThese were:\n", {sum(error_list[3] = e)})
		end if

		for i = 1 to length(error_list[1]) do
			if error_list[3][i] = e then
				if html then
					printf(1, "<a href='#%s'>%s</a>, ", repeat(error_list[1][i],2))
				else
					printf(1, "%s, ", repeat(error_list[1][i],1))
				end if
			end if
		end for

		if html then
			puts(1, "<p>")
		end if

		puts(1, "\n")
	end if
end procedure

procedure do_process_log( sequence cmds, integer html)
	sequence summary = {}
	object other_files = {}
	integer total_failed=0, total_passed=0
	integer test_files=0
	integer out_r
	atom total_time = 0
	object ctc
	sequence messages
	
	if html then
		out_r = routine_id("html_out")
		if sequence( html_fn ) then
			html_fn = open( html_fn, "w" )
		end if
	else
		out_r = routine_id("ascii_out")
	end if

	ctcfh = open("ctc.log","r")
	if ctcfh != -1 then
		ctc = stdget:get(ctcfh)

		if ctc[1] = GET_SUCCESS then
			ctc = ctc[2]
			error_list = ctc

			ctc = stdget:get(ctcfh)
			if ctc[1] = GET_SUCCESS then
				test_files = ctc[2]
			else
				ctc = 0
			end if
		else
			ctc = 0
		end if

		close(ctcfh)
	else
		ctc = 0
		ctcfh = 0
	end if
	
	other_files = error_list[1]

	if html then
		puts(html_fn, "<html><body>\n")
	end if

	object content = read_file("unittest.log")
	if atom(content) then
		puts(1, "unittest.log could not be read\n")
	else 
   
		messages = split( content,"entry = ")
		for a = 1 to length(messages) do
			if sequence(messages[a]) and equal(messages[a], "") then
				continue
			end if
	
			sequence data = value(messages[a])
			if data[1] = GET_SUCCESS then
				data = data[2]
			else
				puts(1, "unittest.log could not parse:\n")
				pretty_print(1, messages[a], {3})
				abort(1)
			end if
	
			switch data[1] do
				case "failed" then
					total_failed += 1
					total_time += data[5]
	
				case "passed" then
					total_passed += 1
					total_time += data[3]
				
				case "file" then
					integer ofi = find(data[2], other_files)
					if ofi != 0 then
						other_files = other_files[1..ofi-1] & other_files[ofi+1..$]
					end if

					while length(unsummarized_files)>=1 and compare(data[2],unsummarized_files[1])!=0 do
						call_proc(out_r, {{"summary",0,0,0,0}})
					end while
			end switch
	
			call_proc(out_r, {data})
		end for
	end if

	while length(unsummarized_files) do
		call_proc(out_r, {{"summary",0,0,0,0}})
	end while
	
	for i = 1 to length(other_files) do
		if find(other_files[i], error_list[1]) then
			call_proc(out_r, {{"file",other_files[i]}})
			call_proc(out_r, {{"summary",0,0,0,0}})
		end if
	end for
	
	summarize_error("Interpreted test files failed unexpectedly.: %d", E_INTERPRET, html)
	summarize_error("Test files could not be translated.........: %d", E_TRANSLATE, html)
	summarize_error("Translated test files could not be compiled: %d", E_COMPILE, html)
	summarize_error("Compiled test files failed unexpectedly....: %d", E_EXECUTE, html)
	summarize_error("Test files could not be bound..............: %d", E_BIND, html )
	summarize_error("Bound test files failed unexpectedly.......: %d", E_BOUND, html )
	summarize_error("Test files run successfully................: %d", E_NOERROR, html)
	
	if html then
		if find(1, error_list[3] = E_EUTEST) then
			printf(1, "There was an internal error to the testing system involving %s<br>",
				{ error_list[1][find(E_EUTEST, error_list[3])] })
		end if

		printf(html_fn, html_table_final_summary, {
			total_passed + total_failed,
			total_failed,
			total_passed,
			total_time
		})
		if html_fn != 1 then
			close( html_fn )
		end if
	else
		puts(1, repeat('*', 76) & "\n\n")
		printf(1, "Overall: Total Tests: %04d  Failed: %04d  Passed: %04d Time: %f\n\n", {
			total_passed + total_failed, total_failed, total_passed, total_time })
		puts(1, repeat('*', 76) & "\n\n")
	end if
end procedure

procedure platform_init()
	ifdef UNIX then
		if equal( executable, "" ) then
			executable = "eui"
		end if
		dexe = ""
		
	elsifdef WIN32 then
		if equal( executable, "" ) then
			executable = "eui"
		end if
		dexe = ".exe"		
	end ifdef
	
	if equal(translator, "-") then
		ifdef UNIX then
			translator = "euc"
		
		elsifdef WIN32 then
			translator = "euc.exe"
		end ifdef
	end if	

	-- Check for various executable names to see if we need -CON or not
	
	-- lower for Windows or DOS, lower for all.  K.I.S.S.

	ifdef UNIX then
		interpreter_os_name = "UNIX"

	elsifdef WIN32 then
		if length(translator) > 0 then
			translator_options &= " -CON"
		end if
		
		interpreter_os_name = "WIN32"

	elsedef
		puts(2, "eutest is only supported on Unix and Windows.\n")
		abort(1)
	end ifdef
	
end procedure

function build_file_list( sequence list )
	sequence files = {}
	for j = 1 to length( list ) do
		
		if file_type( list[j] ) = FILETYPE_DIRECTORY then
			object dirlist = dir( list[j] )
		
			if sequence( dirlist ) then
				sequence basedir = canonical_path( list[j] )
				if basedir[$] != SLASH then
					basedir &= SLASH
				end if
					
				for k = 1 to length( dirlist ) do
					files = append( files, basedir & dirlist[k][D_NAME] )
					printf( 1, "adding test file: %s\n", { files[$] })
				end for
			end if
		else
			files = append( files, list[j] )
		end if
	end for
	return files
end function

procedure main()

	object files = {}
	
	map opts = cmd_parse( cmdopts )
	sequence keys = map:keys( opts )
	for i = 1 to length( keys ) do
		sequence param = keys[i]
		object val = map:get(opts, param)
		
		switch param do
			case "all","failed","wait","accumulate" then
				test_options &= " -" & param		
		
			case "log" then
				logging_activated = 1
				test_options &= " -log "
				
			case "verbose" then
				verbose_switch = 1
				
			case "exe" then
				executable = val
				
			case "ec" then
				translator = val
				
			case "trans" then
				if not length( translator ) then
					translator = "-"
				end if
				
			case "cc" then
				compiler = "-" & val
				
			case "lib" then
				library = "-lib " & val
				
			case "i", "d" then
				for j = 1 to length( val ) do
					sequence option = sprintf( " -%s %s", {param, val[j] })
					interpreter_options &= option
					translator_options &= option
				end for
			
			case "coverage" then
				for j = 1 to length( val ) do
					interpreter_options &= sprintf( " -coverage %s", {val[j]} )
				end for
				if not length( coverage_db ) then
					coverage_db = "-"
				end if
			
			case "coverage-db" then
				coverage_db = val
				interpreter_options &= " -coverage-db " & val
			
			case "coverage-erase" then
				coverage_erase = "-coverage-erase"
			
			case "coverage-pp" then
				coverage_pp = val
			
			case "coverage-exclude" then
				for j = 1 to length( val ) do
					interpreter_options &= sprintf(` -coverage-exclude "%s"`, {val[j]} )
				end for

			case "testopt" then
				test_options &= " -" & val & " "
				
			case "bind" then
				binder = val
				
			case "html-file" then
				html_fn = val

			case "extras" then
				if length( val ) then
					files = build_file_list( val )
				else
					files = dir("t_*.e" )
					if atom(files) then
						files = {}
					end if
					for f = 1 to length( files ) do
						files[f] = files[f][D_NAME]
					end for
					files = sort( files )
					-- put the counter tests last to do
					for f = length( files ) to 1 by -1 do
						if match( "t_c_", files[f] ) = 1 then
							for g = f - 1 to 1 by -1 do
								if match( "t_c_", files[g] ) != 1 then
									files = remove(files, g+1, f) & files[g+1..f]
								end if
							end for
						end if
					end for						
				end if
				
		end switch
	end for
	
	if equal( coverage_db, "-" ) then
		coverage_db = "eutest-cvg.edb"
	end if
	
	if map:has( opts, "process-log") then
		do_process_log( files, map:has( opts, "html" ) )
	else
		platform_init()
		do_test( files )
	end if
end procedure

main()

