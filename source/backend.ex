-- (c) Copyright - See License.txt
--
-- mini Euphoria front-end for stand-alone back-end
-- we redundantly declare some things to keep the size down
ifdef ETYPE_CHECK then
with type_check
elsedef
without type_check
end ifdef

include mode.e
set_mode("backend", 0 )

include std/machine.e
include std/wildcard.e
include std/os.e
include std/io.e
include std/sequence.e
include std/text.e

include global.e
include common.e
include reswords.e
include compress.e
include cominit.e
include pathopen.e
include preproc.e

sequence misc
integer il_file = 0

include backend.e

procedure fatal(sequence msg)
-- fatal error 
	puts(2, msg & '\n')
	puts(2, "\nPress Enter\n")
	getc(0)
	abort(1)
end procedure

procedure verify_checksum(atom size, atom vchecksum)
-- check that the IL was generated by our binder, 
-- and has not been tampered with   
	atom checksum
	integer prev_c, c
	
	checksum = 11352 -- magic starting point
	size = 0
	prev_c = -1
	-- read whole IL
	while 1 do
		c = getc(current_db)
		if c = -1 then
			exit
		end if
		
		if c < 100 then
			if c != 'A' then
				checksum += c
			end if
		else
			checksum += c*2
		end if
		size -= 1
		if size = 0 then
			exit
		end if
		prev_c = c
	end while
	
	checksum = remainder(checksum, 1000000000)
	if checksum != vchecksum then
		fatal("IL code is not in proper format")
	end if
end procedure   

procedure InputIL()
-- Read the IL into several Euphoria variables.
-- Must match OutputIL() in il.e
	integer c1, c2, start
	atom size, checksum
	sequence switches
	
	c1 = getc(current_db)
	if c1 = '#' then
		--ignore shebang line
		if atom(gets(current_db)) then
		end if
		c1 = getc(current_db)
	end if
	
	c2 = getc(current_db) -- IL version
	if c1 != IL_MAGIC or c2 < 10 then
		fatal("not an IL file!")
	end if
	
	if c2 != IL_VERSION then
		fatal("Obsolete .il file. Please recreate it using Euphoria 4.0.")
	end if
	
	-- read size
	size = (getc(current_db) - 32) +
		   (getc(current_db) - 32) * 200 +
		   (getc(current_db) - 32) * 40000 +
		   (getc(current_db) - 32) * 8000000
	
	-- read checksum
	checksum = (getc(current_db) - 32) +
			   (getc(current_db) - 32) * 200 +
			   (getc(current_db) - 32) * 40000 +
			   (getc(current_db) - 32) * 8000000
	
	start = where(current_db)
	
	verify_checksum(size, checksum) -- reads rest of file
	
	-- restart at beginning
	if seek(current_db, start) != 0 then
		fatal("seek failed!")
	end if

	init_compress()
	misc = fdecompress(0)
	max_stack_per_call = misc[1]
	AnyTimeProfile = misc[2]
	AnyStatementProfile = misc[3]
	sample_size = misc[4]
	gline_number = misc[5]
	file_name = misc[6]
	
	SymTab = fdecompress(0)
	slist = fdecompress(0)
	file_include = fdecompress(0)
	switches = fdecompress(0)
end procedure

sequence cl, filename

cl = command_line()

-- open our own .exe file
ifdef UNIX then
	sequence tmp_fname = e_path_find(cl[1])
	if sequence(tmp_fname) then
		current_db = open(tmp_fname, "rb")
	else
		current_db = -1
	end if
elsedef
	current_db = open(cl[1], "rb") 
end ifdef

if current_db = -1 then
	fatal("Can't open .exe file")
end if

-- Must be less than or equal to actual backend size.
-- We seek to this position and then search for the marker.

ifdef FREEBSD or OSX or SUNOS then
	constant OUR_SIZE = 150000 -- backendu for FreeBSD (not compressed)

elsifdef LINUX then
	constant OUR_SIZE = 150000  -- backendu for Linux

elsedef
	constant OUR_SIZE = 67000  -- backendw.exe (upx compression)
end ifdef

if seek(current_db, OUR_SIZE) then
	fatal("seek failed")
end if

object line

-- search for Euphoria code 
-- either tacked on the end of our .exe, 
-- or as a command-line filename

while 1 do
	line = gets(current_db)
	if atom(line) then
		-- EOF, no eu code found in our .exe
		-- see if a filename was specified on the command line
		
		if length(cl) > 2 and match("BACKEND", and_bits(cl[1],#DF)) or
		(length(cl[$]) > 3 and equal(".IL", upper(cl[$][$-2..$])) ) then
			filename = cl[3]
			close(current_db)
			filename = e_path_find(filename)
			if sequence(filename) then
				current_db = open(filename, "rb")
			else
				current_db = -1
			end if

			if current_db = -1 then
				il_file = 1
				exit
			end if
			fatal("Couldn't open " & filename)
		end if
		fatal("no Euphoria code to execute")
	end if
	if equal(line, IL_START) then
		exit
	end if
end while

integer save_first_rand
save_first_rand = rand(1000000000)

InputIL() -- read Euphoria data structures from compressed IL 
		  -- in our own .exe file, or from a .il file, and descramble them

constant M_SET_RAND = 35
machine_proc(M_SET_RAND,save_first_rand)

BackEnd(il_file)-- convert Euphoria data structures to memory and call C back-end

