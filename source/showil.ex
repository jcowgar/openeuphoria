-- (c) Copyright - See License.txt
--
-- Display the IL code produced by the front-end.
-- Fairly crude, used for debugging. You'll be able to check
-- if the IL you are producing from the front end is correct or not.
-- usage:
--
--     eui showil.ex boundfile.exe
-- or:
--     eui showil.ex shroudedfile.il
--
-- The result is placed in "icode.lst".

include std/machine.e
include opnames.e
include reswords.e
include std/pretty.e
include std/io.e
include std/os.e

-- works as a pseudo INTERPRETER
include mode.e
set_mode("interpret",0)
include global.e
include compress.e

-- fields for reduced symbol table stored in IL
constant
	OBJ = 1,
	NEXT = 2,
	MODE = 3,
	SCOPE = 4,
	FILE_NO = 5,
	NAME = 6,
	TOKEN = 7,
	CODE = 8,
	LINETAB = 9,
	TEMPS = 10,
	NUM_ARGS = 11,
	FIRSTLINE = 12,
	STACK_SPACE = 13

integer il_file

procedure show_operand(integer flist, atom word)
-- display one operand
	printf(flist, "%d ", word)
end procedure

procedure error(sequence msg)
	puts(2, msg & '\n')
	abort(1)
end procedure

procedure showCode(integer flist, sequence Code)
-- display the IL code. SymTab is needed.
	integer i, n, sub
	atom word

	i = 1
	puts(flist, "\n\n")
	while i <= length(Code) do
		printf(flist, "     %d: ", i)
		word = Code[i]

		if word > length(opnames) then
			printf(flist, "* BAD OPCODE: %d\n", word)
			error("BAD OPCODE!")
		end if

		puts(flist, opnames[word] & " ")

		if find(word, {TYPE_CHECK, CALL_BACK_RETURN, BADRETURNF, RETURNT,
					   CLEAR_SCREEN, UPDATE_GLOBALS, TASK_YIELD, TASK_CLOCK_STOP,
					   TASK_CLOCK_START,
					   NOP1, NOPWHILE -- translator only
					   }) then
			-- 0 operands follow
			i += 1

		elsif find(word, {CONTINUE, ENDWHILE, ELSE, EXIT, NOP2, TASK_SELF, TASK_SUSPEND,
						  TASK_LIST, GLOBAL_INIT_CHECK, PRIVATE_INIT_CHECK,
						  INTEGER_CHECK, ATOM_CHECK, SEQUENCE_CHECK,
						  RETURNP, DATE, TIME, SPACE_USED, CALL, CLOSE,
						  GET_KEY, COMMAND_LINE, STARTLINE, TRACE,
						  PROFILE, DISPLAY_VAR, ERASE_PRIVATE_NAMES,
						  ERASE_SYMBOL, ABORT, PLATFORM -- only emitted for .il
						  }) then
			-- 1 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			i += 2


		elsif find(word, {NOT, IS_AN_ATOM, IS_A_SEQUENCE, UMINUS, GETS, GETC,
						  SQRT, LENGTH, PLENGTH, ARCTAN, LOG, SIN, COS, TAN, RAND,
						  PEEK, FLOOR, WHILE, ASSIGN_I, ASSIGN,
						  IS_AN_INTEGER, IS_AN_OBJECT, NOT_BITS,
						  NOT_IFW, SC2_AND, SC2_OR, CALL_PROC,
						  RETURNF, POSITION, PEEK4S, PEEK4U, TASK_SCHEDULE,
						  SYSTEM, PUTS, QPRINT, PRINT,
						  GETENV, MACHINE_PROC, IF, POKE4, POKE, TASK_STATUS
						  }) then
			-- 2 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			word = Code[i+2]
			show_operand(flist, word)
			i += 3


		elsif find(word, {LESS, GREATEREQ, EQUALS, NOTEQ, LESSEQ, GREATER,
						  LESS_IFW_I, GREATEREQ_IFW_I, EQUALS_IFW_I,
						  NOTEQ_IFW_I, LESSEQ_IFW_I, GREATER_IFW_I,
						  LESS_IFW, GREATEREQ_IFW, EQUALS_IFW, NOTEQ_IFW,
						  LESSEQ_IFW, GREATER_IFW, AND, OR, MINUS, PLUS,
						  MULTIPLY, DIVIDE, CONCAT, REMAINDER, POWER, OR_BITS,
						  XOR_BITS, APPEND, REPEAT, OPEN, PREPEND, COMPARE,
						  FIND, MATCH, XOR, AND_BITS, EQUAL, RHS_SUBS,
						  RHS_SUBS_CHECK, RHS_SUBS_I, ASSIGN_OP_SUBS,
						  ASSIGN_SUBS, ASSIGN_SUBS_CHECK, ASSIGN_SUBS_I,
						  PASSIGN_SUBS, PASSIGN_OP_SUBS,
						  PLUS1, PLUS1_I, RIGHT_BRACE_2, PLUS_I, MINUS_I,
						  DIV2, FLOOR_DIV2, FLOOR_DIV, SC1_AND, SC1_AND_IF,
						  SC1_OR, SC1_OR_IF, MEM_COPY, MEM_SET,
						  SYSTEM_EXEC, PRINTF, SPRINTF, MACHINE_FUNC,
						  TASK_CREATE, C_PROC, CALL_FUNC, HEAD, TAIL
						  }) then

			-- 3 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			word = Code[i+2]
			show_operand(flist, word)
			word = Code[i+3]
			show_operand(flist, word)
			i += 4

		elsif find(word, {ENDFOR_INT_UP1, ENDFOR_INT_DOWN1, ENDFOR_INT_UP,
						  ENDFOR_INT_DOWN, ASSIGN_OP_SLICE, ASSIGN_SLICE,
						  PASSIGN_SLICE, PASSIGN_OP_SLICE, LHS_SUBS, LHS_SUBS1,
						  LHS_SUBS1_COPY, RHS_SLICE, ENDFOR_UP, ENDFOR_DOWN,
						  C_FUNC, ENDFOR_GENERAL, FIND_FROM, MATCH_FROM, REMOVE,
						  INSERT, SPLICE
						  }) then
			-- 4 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			word = Code[i+2]
			show_operand(flist, word)
			word = Code[i+3]
			show_operand(flist, word)
			word = Code[i+4]
			show_operand(flist, word)
			i += 5

		elsif word = ROUTINE_ID or word = REPLACE then
			-- 5 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			word = Code[i+2]
			show_operand(flist, word)
			word = Code[i+3]
			show_operand(flist, word)
			word = Code[i+4]
			show_operand(flist, word)
			word = Code[i+5]
			show_operand(flist, word)
			i += 6

		elsif find(word, {FOR, FOR_I, ROUTINE_ID}) then
			-- 6 operands follow
			word = Code[i+1]
			show_operand(flist, word)
			word = Code[i+2]
			show_operand(flist, word)
			word = Code[i+3]
			show_operand(flist, word)
			word = Code[i+4]
			show_operand(flist, word)
			word = Code[i+5]
			show_operand(flist, word)
			word = Code[i+6]
			show_operand(flist, word)
			i += 7

		-- special cases: variable number of operands

		elsif word = PROC then
			sub = Code[i+1]
			show_operand(flist, sub)
			puts(flist, "\"" & SymTab[sub][NAME] & "\" ")
			-- we must look at the symbol table to know
			-- how many arguments follow, and whether the
			-- routine being called is a function or not
			n = SymTab[sub][NUM_ARGS]
			for j = 2 to n+1 do
				word = Code[i+j]
				show_operand(flist, word)
			end for

			if SymTab[sub][TOKEN] != PROC then
				word = Code[i+2+n]
				show_operand(flist, word)
				i += 1
			end if

			i += 2 + n

		elsif word = RIGHT_BRACE_N then
			n = Code[i+1]
			show_operand(flist, n)
			for j = 1 to n+1 do
				word = Code[i+1+j]
				show_operand(flist, word)
			end for

			-- more
			i += n + 3

		elsif word = CONCAT_N then
			n = Code[i+1]
			show_operand(flist, n)
			for j = 1 to n do
				word = Code[i+1+j]
				show_operand(flist, word)
			end for

			-- more
			i += n + 3

		else
			puts(flist, " <-- BAD OPCODE!\n")
			error("UNKNOWN OPCODE!")
		end if

		puts(flist, '\n')
		flush(flist)

	end while
end procedure

procedure showSymTab(integer f, integer flist)
-- read the symbol table
-- display it in flist and keep it in memory for use by showCode
	object eentry

	current_db = f
	SymTab = fdecompress(0)
	for i = 1 to length(SymTab) do
		eentry = SymTab[i]
		printf(flist, "%3d. ", i)
		if atom(eentry) then
			puts(flist, "*DELETED*     ")

		elsif length(eentry) >= NAME then
			printf(flist, "%s", {eentry[NAME]})
			if find(eentry[TOKEN], RTN_TOKS) then
				puts(flist, "()\n     ")
				if eentry[TOKEN] = PROC then
					puts(flist, "procedure\n     ")
				elsif eentry[TOKEN] = FUNC then
					puts(flist, "function\n     ")
				elsif eentry[TOKEN] = TYPE then
					puts(flist, "type\n     ")
				end if
				printf(flist, "number of args: %d", eentry[NUM_ARGS])
				if sequence(eentry[CODE]) then
					showCode(flist, eentry[CODE])
				end if

				puts(flist, "\n LINETAB: ")
				print(flist, eentry[LINETAB])

				puts(flist, "\n   TEMPS: ")
				print(flist, eentry[TEMPS])

				puts(flist, "\nFIRSTLINE: ")
				print(flist, eentry[FIRSTLINE])

				puts(flist, "\n   STACK_SPACE: ")
				print(flist, eentry[STACK_SPACE])

			end if

		else
			puts(flist, "<TEMP>     ")
		end if

		if sequence(eentry) then

			puts(flist, "\n     OBJ: ")
			print(flist, eentry[OBJ])

			puts(flist, "\n    NEXT: ")
			print(flist, eentry[NEXT])

			puts(flist, "\n    MODE: ")
			print(flist, eentry[MODE])

			puts(flist, "\n   SCOPE: ")
			print(flist, eentry[SCOPE])

			if length(eentry) > 4 then
				puts(flist, "\n FILE_NO: ")
				print(flist, eentry[FILE_NO])

				puts(flist, "\n   TOKEN: ")
				print(flist, eentry[TOKEN])

			end if

		end if

		puts(flist, "\n")
		puts(flist, "\n")
	end for
	puts(flist, "\n\n")
end procedure

procedure showHeader(integer flist, integer c1, integer c2)
	atom size, checksum

	if il_file then
		if atom(gets(current_db)) then
			-- ignore first (comment) line
		end if
		c1 = getc(current_db)
		c2 = getc(current_db)
	end if

	if c1 != IL_MAGIC then
		puts(2, "not an IL file!\n")
		abort(1)
	end if

	printf(flist, "IL version: %d\n", c2)

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

	init_compress()
end procedure

procedure showMisc(integer flist, object misc)
	if atom(misc) or length(misc) < 6 then
		puts(2, "misc info is bad!\n")
		abort(0)
	end if
	printf(flist, "max_stack_per_call: %d\n", misc[1])
	printf(flist, "AnyTimeProfile: %d\n", misc[2])
	printf(flist, "AnyStatementProfile: %d\n", misc[3])
	printf(flist, "sample_size: %d\n", misc[4])
	printf(flist, "gline_number: %d\n", misc[5])
	puts(flist, "known_files:\n")
	for i = 1 to length(misc[6]) do
		puts(flist, '\t' & misc[6][i] & '\n')
	end for
	puts(flist, '\n')
end procedure

function s_expand(sequence slist) -- copied/modified from scanner.e
-- expand slist to full size if required. This version assumes 2-element slist.
	sequence new_slist

	new_slist = {}

	for i = 1 to length(slist) do
		if sequence(slist[i]) then
			new_slist = append(new_slist, slist[i])
		else
			for j = 1 to slist[i] do
				slist[i-1][1] += 1
				new_slist = append(new_slist, slist[i-1])
			end for
		end if
	end for
	return new_slist
end function

integer f, flist
sequence slist, cl

cl = command_line()
if length(cl) < 3 then
	error("Usage: eui showil file.exe\n       eui showil file.il")
end if

f = open(cl[3], "rb")
if f = -1 then
	error("Couldn't open " & cl[3] & '\n')
end if

object line
integer OUR_SIZE

il_file = match(".il", cl[3])

if not il_file then
	-- roughly, but must be less or equal to size of eub[w].exe
	OUR_SIZE = 61500

	if seek(f, OUR_SIZE) then
		error("initial seek failed")
	end if

	while not il_file do
		line = gets(f)
		if atom(line) then
			error("EOF reached with no separator line found")
		end if
		if equal(line, "YTREWQ\n") then
			exit
		end if
	end while
end if

flist = open("icode.lst", "wb")
if flist = -1 then
	puts(2, "Couldn't open icode.lst\n")
	abort(1)
end if

integer c1, c2
sequence misc

current_db = f

c1 = getc(f)
c2 = getc(f)
showHeader(flist, c1, c2)

misc = fdecompress(0)
showMisc(flist, misc)

showSymTab(f, flist)

slist = fdecompress(0)
slist = s_expand(slist)
puts(flist, "Line Table: {line number within file, file number}\n\n")
pretty_print(flist, slist, {})

