-- (c) Copyright 2007 Rapid Deployment Software - See License.txt
--
----------------------------------------------------------------------------
--                                                                        -- 
--       Translator Declarations and Support Routines                     --
--                                                                        -- 
----------------------------------------------------------------------------

include std/text.e
include std/math.e
include std/os.e
include std/filesys.e

include global.e
include reswords.e
include symtab.e
include tranplat.e
include compile.e

with type_check
-- Translator
global constant MAX_CFILE_SIZE = 2500 -- desired max size of created C files

global constant LAST_PASS = 7        -- number of Translator passes

global integer Pass   -- the pass number, 1 ... LAST_PASS 

-- What we currently know locally in this basic block about var values etc.
global constant BB_VAR = 1,      -- the var / type / constant
		 BB_TYPE = 2,     -- main type
		 BB_ELEM = 3,     -- element type for sequences
		 BB_SEQLEN = 4,   -- sequence length
		 BB_OBJ = 5       -- integer value min/max
global sequence BB_info
BB_info = {}

global integer LeftSym   -- to force name to appear, not value
LeftSym = FALSE    

global boolean dll_option, con_option, fastfp, lccopt_option
dll_option = FALSE
con_option = FALSE
fastfp = FALSE
lccopt_option = TRUE

sequence files_to_delete
files_to_delete = {
"main-.c",
"main-.h",
"init-.c"
}

global boolean keep -- emake should keep .c files or delete?
keep = FALSE

global boolean debug_option
debug_option = FALSE

global sequence user_library
user_library = ""

global integer total_stack_size  -- default size for OPTION STACK
total_stack_size = -1  -- (for now) 

-- first check EUCOMPILEDIR, to allow the user to override and use a different
-- directory than EUDIR. THen use EUDIR, then default to /usr/share/euphoria
function get_eudir()
	object x
	x = getenv("EUCOMPILEDIR")
	if equal(x, -1) then
		x = getenv("EUDIR")
	end if
ifdef UNIX then
	if equal(x, -1) then
		x = "/usr/share/euphoria"
	end if
end ifdef
	return x
end function

procedure delete_files(integer doit)
-- output commands to delete .c and .h files
	if not keep then
		for i = 1 to length(files_to_delete) do
			if TUNIX then
				puts(doit, "rm ")
			else
				puts(doit, "del ")
			end if
			puts(doit, files_to_delete[i] & HOSTNL)
		end for 
	end if
end procedure

global procedure NewBB(integer a_call, integer mask, symtab_index sub)
-- Start a new Basic Block at a label or after a subroutine call 

	symtab_index s
	
	if a_call then
		-- Forget what we know about local & global var values,
		-- but remember that they were initialized 
		for i = 1 to length(BB_info) do
			s = BB_info[i][BB_VAR]
			if SymTab[s][S_MODE] = M_NORMAL and
				(SymTab[s][S_SCOPE] = SC_GLOBAL or
				 SymTab[s][S_SCOPE] = SC_LOCAL  or
				 SymTab[s][S_SCOPE] = SC_EXPORT or
				 SymTab[s][S_SCOPE] = SC_PUBLIC ) then
				  if and_bits(mask, power(2, remainder(s, E_SIZE))) then
					  if mask = E_ALL_EFFECT or s < sub then
						  BB_info[i][BB_TYPE..BB_OBJ] = 
							{TYPE_NULL, TYPE_NULL, NOVALUE, {MININT, MAXINT}}
					  end if
				  end if
			end if
		end for
	else 
		-- Label: forget what we know about all temp and var types
		BB_info = {}
	end if 
end procedure

global function BB_var_obj(integer var)
-- return the local min/max value of an integer, based on BB info.
	sequence fail
	
	fail = {NOVALUE, NOVALUE}
	for i = length(BB_info) to 1 by -1 do
		if BB_info[i][BB_VAR] = var and
		   SymTab[BB_info[i][BB_VAR]][S_MODE] = M_NORMAL then
				if BB_info[i][BB_TYPE] != TYPE_INTEGER then
					return fail
				end if
				return BB_info[i][BB_OBJ]
		end if
	end for
	return fail
end function

global function BB_var_type(integer var)
-- return the local type of a var, based on BB info (only) 
	for i = length(BB_info) to 1 by -1 do
		if BB_info[i][BB_VAR] = var and
		   SymTab[BB_info[i][BB_VAR]][S_MODE] = M_NORMAL then
			if BB_info[i][BB_TYPE] < 0 or
			   BB_info[i][BB_TYPE] > TYPE_OBJECT then
				InternalErr("Bad BB_var_type")
			end if
			if BB_info[i][BB_TYPE] = TYPE_NULL then  -- var has only been read
				return TYPE_OBJECT
			else
				return BB_info[i][BB_TYPE]
			end if
		end if
	end for
	return TYPE_OBJECT
end function

global function GType(symtab_index s)  
-- return our best estimate of the current type of a var or temp 
	integer t, local_t
	
	t = SymTab[s][S_GTYPE]
	if t < 0 or t > TYPE_OBJECT then
		InternalErr("Bad GType")
	end if
	if SymTab[s][S_MODE] != M_NORMAL then
		return t
	end if
	-- check local BB info for vars only 
	local_t = BB_var_type(s)
	if local_t = TYPE_OBJECT then
		return t
	end if
	if t = TYPE_INTEGER then
		return TYPE_INTEGER
	end if
	return local_t
end function

global function ObjValue(symtab_index s) 
-- the value of an integer constant or variable 
	sequence t, local_t

	t = {SymTab[s][S_OBJ_MIN], SymTab[s][S_OBJ_MAX]}
	
	if t[MIN] != t[MAX] then
		t[MIN] = NOVALUE
	end if
	if SymTab[s][S_MODE] != M_NORMAL then
		return t[MIN]
	end if
	
	-- check local BB info for vars only 
	local_t = BB_var_obj(s)
	if local_t[MIN] = NOVALUE or 
	   local_t[MIN] != local_t[MAX] then
		return t[MIN]
	else
		return local_t[MIN]
	end if
end function

global function TypeIs(integer x, object types) 
	if atom(types) then
		return GType(x) = types
	else
		return find(GType(x), types)
	end if
end function

global function TypeIsNot(integer x, object types) 
	if atom(types) then
		return GType(x) != types
	else
		return not find(GType(x), types)
	end if
end function

global function or_type(integer t1, integer t2)
-- OR two types to get the (least general) type that includes both 
	if t1 = TYPE_NULL then
		return t2
	
	elsif t2 = TYPE_NULL then
		return t1
	
	elsif t1 = TYPE_OBJECT or t2 = TYPE_OBJECT then
		return TYPE_OBJECT
	
	elsif t1 = TYPE_SEQUENCE then
		if t2 = TYPE_SEQUENCE then
			return TYPE_SEQUENCE
		else 
			return TYPE_OBJECT
		end if
		
	elsif t2 = TYPE_SEQUENCE then
		if t1 = TYPE_SEQUENCE then
			return TYPE_SEQUENCE
		else 
			return TYPE_OBJECT
		end if
	
	elsif t1 = TYPE_ATOM or t2 = TYPE_ATOM then
		return TYPE_ATOM   
	
	elsif t1 = TYPE_DOUBLE then
		if t2 = TYPE_INTEGER then
			return TYPE_ATOM
		else
			return TYPE_DOUBLE
		end if
	
	elsif t2 = TYPE_DOUBLE then
		if t1 = TYPE_INTEGER then
			return TYPE_ATOM
		else
			return TYPE_DOUBLE
		end if
	
	elsif t1 = TYPE_INTEGER and t2 = TYPE_INTEGER then
		return TYPE_INTEGER
	
	else
		InternalErr(sprintf("or_type: t1 is %d, t2 is %d\n", {t1, t2}))
			
	end if
end function

global procedure SetBBType(symtab_index s, integer t, sequence val, integer etype)
-- Set the type and value, or sequence length and element type,
-- of a temp or var s locally within a BB. 

-- t is the type

-- val is either the integer min & max values, or the length of a 
-- sequence in min, or -1 if we are to just OR-in the etype. 

-- etype is the element type of a sequence or object. If an object is 
-- subscripted or sliced that shows that it's a sequence in that instance, 
-- and its element type can be used. 
	
	integer found, i, tn
	
	if find(SymTab[s][S_MODE], {M_TEMP, M_NORMAL}) then
		found = FALSE
		if SymTab[s][S_MODE] = M_TEMP then
			SymTab[s][S_GTYPE] = t
			SymTab[s][S_SEQ_ELEM] = etype
			if find(SymTab[s][S_GTYPE], {TYPE_SEQUENCE, TYPE_OBJECT}) then
				if val[MIN] < 0 then
					SymTab[s][S_SEQ_LEN] = NOVALUE
				else    
					SymTab[s][S_SEQ_LEN] = val[MIN]
				end if
				SymTab[s][S_OBJ] = NOVALUE
			else 
				SymTab[s][S_OBJ_MIN] = val[MIN] 
				SymTab[s][S_OBJ_MAX] = val[MAX] 
				SymTab[s][S_SEQ_LEN] = NOVALUE
			end if
			if not Initializing then
				integer new_type = or_type(temp_name_type[SymTab[s][S_TEMP_NAME]][T_GTYPE_NEW], t)
				if new_type = TYPE_NULL then
					new_type = TYPE_OBJECT
				end if
				temp_name_type[SymTab[s][S_TEMP_NAME]][T_GTYPE_NEW] = new_type
-- 				   or_type(temp_name_type[SymTab[s][S_TEMP_NAME]][T_GTYPE_NEW], t)
				
			end if
			tn = SymTab[s][S_TEMP_NAME]
			i = 1
			while i <= length(BB_info) do
				if SymTab[BB_info[i][BB_VAR]][S_MODE] = M_TEMP and
					SymTab[BB_info[i][BB_VAR]][S_TEMP_NAME] = tn then
					found = TRUE
					exit
				end if
				i += 1
			end while
		
		else   -- M_NORMAL
			if t != TYPE_NULL then
				if not Initializing then
					SymTab[s][S_GTYPE_NEW] = or_type(SymTab[s][S_GTYPE_NEW], t)
				end if
				
				if t = TYPE_SEQUENCE then
					SymTab[s][S_SEQ_ELEM_NEW] = 
							  or_type(SymTab[s][S_SEQ_ELEM_NEW], etype)
					-- treat val.min as sequence length 
					if val[MIN] != -1 then
						if SymTab[s][S_SEQ_LEN_NEW] = -NOVALUE then
							if val[MIN] < 0 then
								SymTab[s][S_SEQ_LEN_NEW] = NOVALUE
							else
								SymTab[s][S_SEQ_LEN_NEW] = val[MIN]
							end if
						elsif val[MIN] != SymTab[s][S_SEQ_LEN_NEW] then
							SymTab[s][S_SEQ_LEN_NEW] = NOVALUE
						end if
					end if

				elsif t = TYPE_INTEGER then
					-- treat val as integer value */
					if SymTab[s][S_OBJ_MIN_NEW] = -NOVALUE then
						-- first known value assigned in this pass */
						SymTab[s][S_OBJ_MIN_NEW] = val[MIN]
						SymTab[s][S_OBJ_MAX_NEW] = val[MAX]

					elsif SymTab[s][S_OBJ_MIN_NEW] != NOVALUE then
						-- widen the range */
						if val[MIN] < SymTab[s][S_OBJ_MIN_NEW] then
							SymTab[s][S_OBJ_MIN_NEW] = val[MIN]
						end if
						if val[MAX] > SymTab[s][S_OBJ_MAX_NEW] then
							SymTab[s][S_OBJ_MAX_NEW] = val[MAX]
						end if
					end if

				else 
					SymTab[s][S_OBJ_MIN_NEW] = NOVALUE
					if t = TYPE_OBJECT then
						-- for objects, we record element type, if provided,
						-- but we don't try to record integer value or seq len
						SymTab[s][S_SEQ_ELEM_NEW] = 
								 or_type(SymTab[s][S_SEQ_ELEM_NEW], etype)
						SymTab[s][S_SEQ_LEN_NEW] = NOVALUE
					end if
				end if
			end if
			
			i = 1
			while i <= length(BB_info) do
				if BB_info[i][BB_VAR] = s then
					found = TRUE
					exit
				end if
				i += 1
			end while
			
		end if

		if not found then
			-- add space for a new entry
			BB_info = append(BB_info, repeat(0, 5))
		end if
		
		if t = TYPE_NULL then
			if not found then
				-- add read-only dummy reference
				BB_info[i] = {s, t, TYPE_OBJECT, NOVALUE, {MININT, MAXINT}}
			end if
			-- don't record anything if the var already exists in this BB
		else 
			BB_info[i][BB_VAR] = s
			BB_info[i][BB_TYPE] = t
			-- etype shouldn't matter if the var is not a sequence here
			if t = TYPE_SEQUENCE and val[MIN] = -1 then
				-- assign to subscript or slice of a sequence
				if found and BB_info[i][BB_ELEM] != TYPE_NULL then
					--kludge:
					BB_info[i][BB_ELEM] = or_type(BB_info[i][BB_ELEM], etype) 
				else
					BB_info[i][BB_ELEM] = TYPE_NULL
				end if
				if not found then
					BB_info[i][BB_SEQLEN] = NOVALUE
				end if
			else 
				BB_info[i][BB_ELEM] = etype
				if t = TYPE_SEQUENCE or t = TYPE_OBJECT then 
					if val[MIN] < 0 then
						BB_info[i][BB_SEQLEN] = NOVALUE
					else
						BB_info[i][BB_SEQLEN] = val[MIN]
					end if
				else
					BB_info[i][BB_OBJ] = val
				end if
			end if
		end if
		
	elsif SymTab[s][S_MODE] = M_CONSTANT then
		SymTab[s][S_GTYPE] = t
		SymTab[s][S_SEQ_ELEM] = etype
		if SymTab[s][S_GTYPE] = TYPE_SEQUENCE or 
		   SymTab[s][S_GTYPE] = TYPE_OBJECT then
			if val[MIN] < 0 then
				SymTab[s][S_SEQ_LEN] = NOVALUE
			else    
				SymTab[s][S_SEQ_LEN] = val[MIN]
			end if
		else 
			SymTab[s][S_OBJ_MIN] = val[MIN] 
			SymTab[s][S_OBJ_MAX] = val[MAX] 
		end if
	end if
end procedure


global function ok_name(sequence name)
-- return a different name to avoid conflicts with certain C compiler
-- reserved words. Only needed for private variables (no file number attached). 
-- split into two lists for speed 
	
	if name[1] <= 'f' then
		if    equal(name, "Bool") then
			return "Bool97531"
		elsif equal(name, "Seg16") then
			return "Seg1697531"
		elsif equal(name, "Packed") then
			return "Packed97531"
		elsif equal(name, "Try") then
			return "Try97531"
		elsif equal(name, "cdecl") then
			return "cdecl97531"
		elsif equal(name, "far") then
			return "far97531"
		elsif equal(name, "far16") then
			return "far1697531"
		elsif equal(name, "asm") then
			return "asm97531"
		else
			return name
		end if
		
	else 
		if    equal(name, "stdcall") then
			return "stdcall97531"
		elsif equal(name, "fastcall") then
			return "fastcall97531"
		elsif equal(name, "pascal") then
			return "pascal97531"
		elsif equal(name, "try") then
			return "try97531"
		elsif equal(name, "near") then
			return "near97531"
		elsif equal(name, "interrupt") then
			return "interrupt97531"
		elsif equal(name, "huge") then
			return "huge97531"
		else
			return name
		end if
	end if
end function

global procedure CName(symtab_index s)
-- display the C name or literal value of an operand 
	object v
	
	v = ObjValue(s)
	if SymTab[s][S_MODE] = M_NORMAL then
		-- declared user variables 

		if LeftSym = FALSE and GType(s) = TYPE_INTEGER and v != NOVALUE then
			c_printf("%d", v)
		else   
			if SymTab[s][S_SCOPE] > SC_PRIVATE then 
				c_printf("_%d", SymTab[s][S_FILE_NO])
				c_puts(SymTab[s][S_NAME])
			else 
				c_puts("_")
				c_puts(ok_name(SymTab[s][S_NAME]))
			end if
		end if
		if s != CurrentSub and SymTab[s][S_NREFS] < 2 then
			SymTab[s][S_NREFS] += 1
		end if
		SetBBType(s, TYPE_NULL, novalue, TYPE_OBJECT) -- record that this var was referenced in this BB
	
	
	elsif SymTab[s][S_MODE] = M_CONSTANT then
		-- literal integers, or declared constants 

		if LeftSym = FALSE and TypeIs(s, TYPE_INTEGER) and v != NOVALUE then
			-- integer: either literal, or 
			-- declared constant rvalue with integer value
			c_printf("%d", v) 
		else 
			-- Declared constant 
			c_printf("_%d", SymTab[s][S_FILE_NO])
			c_puts(SymTab[s][S_NAME])
			if SymTab[s][S_NREFS] < 2 then
				SymTab[s][S_NREFS] += 1
			end if
		end if
	
	else   -- M_TEMP 
		-- literal doubles, strings, temporary vars that we create 
		if LeftSym = FALSE and GType(s) = TYPE_INTEGER and v != NOVALUE then
			c_printf("%d", v)
		else 
			c_printf("_%d", SymTab[s][S_TEMP_NAME])
		end if
	end if
	
	LeftSym = FALSE
end procedure
with warning

global procedure c_stmt(sequence stmt, object arg)
-- output a C statement with replacements for @ or @1 @2 @3, ... @9
	integer argcount, i
	
	if Pass = LAST_PASS and Initializing = FALSE then
		cfile_size += 1
	end if
		
	adjust_indent_before(stmt)
	
	if atom(arg) then 
		arg = {arg}
	end if
	
	argcount = 1
	i = 1
	while i <= length(stmt) and length(stmt) > 0 do
		if stmt[i] = '@' then
			-- argument detected
			if i = 1 then
				LeftSym = TRUE
			end if
			
			if i < length(stmt) and stmt[i+1] > '0' and stmt[i+1] <= '9' then
				-- numbered argument
				CName(arg[stmt[i+1]-'0'])
				i += 1
			
			else
				-- plain argument
				CName(arg[argcount])
			
			end if
			argcount += 1
		
		else 
			c_putc(stmt[i])
			if stmt[i] = '&' and i < length(stmt) and stmt[i+1] = '@' then
				LeftSym = TRUE -- never say: x = x &y or andy - always leave space
			end if
		end if
		
		if stmt[i] = '\n' and i < length(stmt) then
			adjust_indent_after(stmt)
			stmt = stmt[i+1..$]
			i = 0
			adjust_indent_before(stmt)
		end if
		
		i += 1
	end while
	
	adjust_indent_after(stmt)
end procedure

global procedure c_stmt0(sequence stmt)
-- output a C statement with no arguments
	if emit_c_output then
		c_stmt(stmt, {})
	end if
end procedure

global procedure DeclareFileVars()
-- emit C declaration for each local and global constant and var 
	symtab_index s
	symtab_entry eentry
	
	c_puts("\n")
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		eentry = SymTab[s]
		if eentry[S_SCOPE] >= SC_LOCAL and (eentry[S_SCOPE] <= SC_GLOBAL 
			or eentry[S_SCOPE] = SC_EXPORT or eentry[S_SCOPE] = SC_PUBLIC) and
			eentry[S_USAGE] != U_UNUSED and eentry[S_USAGE] != U_DELETED and
			not find(eentry[S_TOKEN], {PROC, FUNC, TYPE}) then
			
			
			c_puts("int ")
			c_printf("_%d", eentry[S_FILE_NO])
			c_puts(eentry[S_NAME])
			if integer( eentry[S_OBJ] ) then
					c_printf(" = %d;\n", eentry[S_OBJ] )
			else
				c_puts(" = 0;\n")
			end if
			
			c_hputs("extern int ")
			c_hprintf("_%d", eentry[S_FILE_NO])
			c_hputs(eentry[S_NAME])
			
			c_hputs(";\n")
		end if
		s = SymTab[s][S_NEXT]
	end while
	c_puts("\n")
	c_hputs("\n")
end procedure
   
integer deleted_routines 
deleted_routines = 0

global procedure PromoteTypeInfo()
-- at the end of each pass, certain info becomes valid 
	symtab_index s
	
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if SymTab[s][S_TOKEN] = FUNC or SymTab[s][S_TOKEN] = TYPE then
			if SymTab[s][S_GTYPE_NEW] = TYPE_NULL then
				SymTab[s][S_GTYPE] = TYPE_OBJECT
			else
				SymTab[s][S_GTYPE] = SymTab[s][S_GTYPE_NEW]
			end if
		else 
			-- variables: promote gtype_new only if it's better than gtype 
			-- user may have declared it better than we can determine. 
			if SymTab[s][S_GTYPE] != TYPE_INTEGER and
				SymTab[s][S_GTYPE_NEW] != TYPE_OBJECT and
				SymTab[s][S_GTYPE_NEW] != TYPE_NULL then
				if SymTab[s][S_GTYPE_NEW] = TYPE_INTEGER or
				   SymTab[s][S_GTYPE] = TYPE_OBJECT or
				   (SymTab[s][S_GTYPE] = TYPE_ATOM and 
					SymTab[s][S_GTYPE_NEW] = TYPE_DOUBLE) then
						SymTab[s][S_GTYPE] = SymTab[s][S_GTYPE_NEW]
				end if      
			end if
			if SymTab[s][S_ARG_TYPE_NEW] = TYPE_NULL then
				SymTab[s][S_ARG_TYPE] = TYPE_OBJECT
			else
				SymTab[s][S_ARG_TYPE] = SymTab[s][S_ARG_TYPE_NEW]
			end if
			SymTab[s][S_ARG_TYPE_NEW] = TYPE_NULL
			
			if SymTab[s][S_ARG_SEQ_ELEM_NEW] = TYPE_NULL then
				SymTab[s][S_ARG_SEQ_ELEM] = TYPE_OBJECT
			else
				SymTab[s][S_ARG_SEQ_ELEM] = SymTab[s][S_ARG_SEQ_ELEM_NEW]
			end if
			SymTab[s][S_ARG_SEQ_ELEM_NEW] = TYPE_NULL
		
			if SymTab[s][S_ARG_MIN_NEW] = -NOVALUE or 
			   SymTab[s][S_ARG_MIN_NEW] = NOVALUE then
				SymTab[s][S_ARG_MIN] = MININT
				SymTab[s][S_ARG_MAX] = MAXINT
			else 
				SymTab[s][S_ARG_MIN] = SymTab[s][S_ARG_MIN_NEW]
				SymTab[s][S_ARG_MAX] = SymTab[s][S_ARG_MAX_NEW]
			end if
			SymTab[s][S_ARG_MIN_NEW] = -NOVALUE
		
			if SymTab[s][S_ARG_SEQ_LEN_NEW] = -NOVALUE then
				SymTab[s][S_ARG_SEQ_LEN] = NOVALUE
			else
				SymTab[s][S_ARG_SEQ_LEN] = SymTab[s][S_ARG_SEQ_LEN_NEW]
			end if
			SymTab[s][S_ARG_SEQ_LEN_NEW] = -NOVALUE
		end if
		
		SymTab[s][S_GTYPE_NEW] = TYPE_NULL
		
		if SymTab[s][S_SEQ_ELEM_NEW] = TYPE_NULL then
		   SymTab[s][S_SEQ_ELEM] = TYPE_OBJECT
		else
			SymTab[s][S_SEQ_ELEM] = SymTab[s][S_SEQ_ELEM_NEW]
		end if
		SymTab[s][S_SEQ_ELEM_NEW] = TYPE_NULL
		
		if SymTab[s][S_SEQ_LEN_NEW] = -NOVALUE then
			SymTab[s][S_SEQ_LEN] = NOVALUE
		else
			SymTab[s][S_SEQ_LEN] = SymTab[s][S_SEQ_LEN_NEW]
		end if
		SymTab[s][S_SEQ_LEN_NEW] = -NOVALUE
		
		if SymTab[s][S_TOKEN] != NAMESPACE then
			if SymTab[s][S_OBJ_MIN_NEW] = -NOVALUE or
			   SymTab[s][S_OBJ_MIN_NEW] = NOVALUE then
				SymTab[s][S_OBJ_MIN] = MININT
				SymTab[s][S_OBJ_MAX] = MAXINT
			else 
				SymTab[s][S_OBJ_MIN] = SymTab[s][S_OBJ_MIN_NEW]
				SymTab[s][S_OBJ_MAX] = SymTab[s][S_OBJ_MAX_NEW]
			end if
		end if
		SymTab[s][S_OBJ_MIN_NEW] = -NOVALUE
		
		if SymTab[s][S_NREFS] = 1 and 
		   find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE}) then
			if SymTab[s][S_USAGE] != U_DELETED then
				SymTab[s][S_USAGE] = U_DELETED
				deleted_routines += 1
			end if
		end if
		SymTab[s][S_NREFS] = 0
		s = SymTab[s][S_NEXT]
	end while
	
	-- global temp information 
	for i = 1 to length(temp_name_type) do
		-- could be TYPE_NULL if temp is never assigned a value, i.e. not used
		temp_name_type[i][T_GTYPE] = temp_name_type[i][T_GTYPE_NEW]
		temp_name_type[i][T_GTYPE_NEW] = TYPE_NULL
	end for
end procedure

global procedure DeclareRoutineList()
-- Declare the list of routines for routine_id search 
	symtab_index s, p
	integer first, seq_num
	
	c_hputs("extern struct routine_list _00[];\n")
	
	-- declare all used routines 
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if SymTab[s][S_USAGE] != U_DELETED and
			find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE}) then
			if find( SymTab[s][S_SCOPE], { SC_GLOBAL, SC_EXPORT, SC_PUBLIC } ) and dll_option then
				-- declare the global routine as an exported DLL function
				if TWINDOWS then            
				 -- c_hputs("int __declspec (dllexport) __stdcall\n")
					c_hputs("int __stdcall\n")
				end if
			else
				c_hputs("int ")
			end if
			c_hprintf("_%d", SymTab[s][S_FILE_NO])
			c_hputs(SymTab[s][S_NAME])
			c_hputs("(")
			for i = 1 to SymTab[s][S_NUM_ARGS] do
				if i = 1 then
					c_hputs("int")
				else
					c_hputs(", int")
				end if
			end for
			c_hputs(");\n")
		end if
		s = SymTab[s][S_NEXT]
	end while
	c_puts("\n")
	
	-- add all possible routine_id targets to the routine list 
	seq_num = 0
	first = TRUE
	c_puts("struct routine_list _00[] = {\n")
	
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE, NAMESPACE}) then
			if SymTab[s][S_TOKEN] != NAMESPACE and SymTab[s][S_RI_TARGET] then
				if not first then
					c_puts(",\n")
				end if
				first = FALSE
				
				c_puts("  {\"")
				
				c_puts(SymTab[s][S_NAME])
				c_puts("\", ")
				
				if dll_option then
					c_puts("(int (*)())")
				end if
					
				c_printf("_%d", SymTab[s][S_FILE_NO])
				c_puts(SymTab[s][S_NAME])
				
				c_printf(", %d", seq_num)
				
				c_printf(", %d", SymTab[s][S_FILE_NO])
				
				c_printf(", %d", SymTab[s][S_NUM_ARGS])
				
				if TWINDOWS and dll_option and find( SymTab[s][S_SCOPE], { SC_GLOBAL, SC_EXPORT, SC_PUBLIC} ) then
					c_puts(", 1")  -- must call with __stdcall convention
				else
					c_puts(", 0")  -- default: call with normal or __cdecl convention
				end if
				
				c_printf(", %d", SymTab[s][S_SCOPE] )
				
				c_puts("}")
				
				if SymTab[s][S_NREFS] < 2 then
					SymTab[s][S_NREFS] = 2 --s->nrefs++
				end if
				
				-- all bets are off: 
				-- set element type and arg type of parameters to TYPE_OBJECT 
				p = SymTab[s][S_NEXT]
				for i = 1 to SymTab[s][S_NUM_ARGS] do
					SymTab[p][S_ARG_SEQ_ELEM_NEW] = TYPE_OBJECT
					SymTab[p][S_ARG_TYPE_NEW] = TYPE_OBJECT
					SymTab[p][S_ARG_MIN_NEW] = NOVALUE
					SymTab[p][S_ARG_SEQ_LEN_NEW] = NOVALUE
					p = SymTab[p][S_NEXT]
				end for
			end if
			seq_num += 1
		end if
		s = SymTab[s][S_NEXT]
	end while
	if not first then
		c_puts(",\n")
	end if
	c_puts("  {\"\", 0, 999999999, 0, 0, 0, 0}\n};\n\n")  -- end marker

	c_hputs("extern unsigned char ** _02;\n")
	c_puts("unsigned char ** _02;\n")
	
	c_hputs("extern object _0switches;\n")
	c_puts("object _0switches;\n")
end procedure   


global procedure DeclareNameSpaceList()
-- Declare the list of namespace qualifiers for routine_id search 
	symtab_index s
	integer first, seq_num
	
	c_hputs("extern struct ns_list _01[];\n")
	c_puts("struct ns_list _01[] = {\n")

	seq_num = 0
	first = TRUE
	
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE, NAMESPACE}) then
			if SymTab[s][S_TOKEN] = NAMESPACE then
				if not first then
					c_puts(",\n")
				end if
				first = FALSE
				
				c_puts("  {\"")
				c_puts(SymTab[s][S_NAME])
				c_printf("\", %d", SymTab[s][S_OBJ])
				c_printf(", %d", seq_num)
				c_printf(", %d", SymTab[s][S_FILE_NO])
				
				c_puts("}")
			end if   
			seq_num += 1
		end if
		s = SymTab[s][S_NEXT]
	end while
	if not first then
		c_puts(",\n")
	end if
	c_puts("  {\"\", 0, 999999999, 0}\n};\n\n")  -- end marker
end procedure

function is_exported( symtab_index s )
-- returns 1 if symbol should be exported from dll/so
	sequence eentry = SymTab[s]
	integer scope = eentry[S_SCOPE]
	if eentry[S_MODE] = M_NORMAL then
		if eentry[S_FILE_NO] = 1 or scope = SC_GLOBAL then
			return 1
		end if
		
		if scope = SC_PUBLIC 
		and and_bits( include_matrix[1][eentry[S_FILE_NO]], PUBLIC_INCLUDE ) then
			return 1
		end if
	end if
	return 0
end function


procedure Write_def_file(integer def_file)
-- output the list of exported symbols for a .dll 
	symtab_index s
	
	if atom(wat_path) then
		puts(def_file, "EXPORTS\n")
	end if
	
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE}) then
			if is_exported( s ) then
				if sequence(bor_path) then             
					printf(def_file, "%s=_%d%s\n", 
						   {SymTab[s][S_NAME], SymTab[s][S_FILE_NO], 
							SymTab[s][S_NAME]})
				elsif sequence(wat_path) then
					printf(def_file, "EXPORT %s='__%d%s@%d'\n", 
						   {SymTab[s][S_NAME], SymTab[s][S_FILE_NO], 
							SymTab[s][S_NAME], SymTab[s][S_NUM_ARGS] * 4})
				else 
					-- Lcc 
					printf(def_file, "_%d%s@%d\n", 
						   {SymTab[s][S_FILE_NO], SymTab[s][S_NAME], 
							SymTab[s][S_NUM_ARGS] * 4})
				end if
			end if
		end if
		s = SymTab[s][S_NEXT]
	end while
end procedure

global procedure version()
	c_puts("// Euphoria To C version " & TRANSLATOR_VERSION & "\n")
end procedure

sequence c_opts

global procedure new_c_file(sequence name)
-- end the old .c file and start a new one 
	cfile_size = 0
	if Pass != LAST_PASS then
		return
	end if

	close(c_code)
	c_code = open(name & ".c", "w")
	if c_code = -1 then
		CompileErr("Couldn't open .c file for output")
	end if  
	cfile_count += 1
	version()
	if TDOS and sequence(dj_path) then
		c_puts("#include <go32.h>\n")
	end if
	c_puts("#include \"include/euphoria.h\"\n")
	
	c_puts("#include \"main-.h\"\n\n")

	if not TUNIX then
		name = lower(name)  -- for faster compare later
	end if
	files_to_delete = append(files_to_delete, name & ".c")
end procedure

-- These characters are assumed to be legal and safe to use 
-- in a file name on any platform. We can generate up to 
-- length(file_chars) squared (i.e. over 1000) .c files per Euphoria file.
constant file_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

function unique_c_name(sequence name)
-- See if name has been used already. If so, change the first char.
	integer i
	sequence compare_name
	integer next_fc 
	
	compare_name = name & ".c"
	if not TUNIX then
		compare_name = lower(compare_name)
		-- .c's on files_to_delete are already lower
	end if
	next_fc = 1
	i = 1
	while i <= length(files_to_delete) do
		-- extract the base name
		if equal(files_to_delete[i], compare_name) then
			-- name conflict 
			if next_fc > length(file_chars) then
				CompileErr("Sorry, too many .c files with the same base name")
			end if
			name[1] = file_chars[next_fc]
			compare_name = name & ".c"
			if not TUNIX then
				compare_name = lower(compare_name)
			end if
			next_fc += 1
			i = 1 -- start over and compare again
		else
			i += 1
		end if
	end while
	return name
end function

sequence link_line
integer link_file

procedure add_file(sequence filename)
-- add a file to the list of files to be linked 
	if TUNIX then
		link_line &= filename & ".o "
	
	elsif TDOS then
		if sequence(wat_path) then
			printf(link_file, "FILE %s.obj\n", {filename})
		else
			printf(link_file, "%s.o\n", {filename})
		end if
	
	else
		if sequence(wat_path) then
			printf(link_file, "FILE %s.obj\n", {filename})
		elsif sequence(bor_path) then
			printf(link_file, "%s.c\n", {filename})
		else
			printf(link_file, "%s.obj\n", {filename})
		end if
	end if
end procedure

function any_code(integer file_no)
-- return TRUE if the corresponding C file will contain any code
-- Note: top level code goes into main-.c   
	symtab_index s
	
	s = SymTab[TopLevelSub][S_NEXT]
	while s do
		if SymTab[s][S_FILE_NO] = file_no and 
		   SymTab[s][S_USAGE] != U_DELETED and
		   find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE}) then
			return TRUE -- found a non-deleted routine in this file
		end if
		s = SymTab[s][S_NEXT]
	end while
	return FALSE
end function

integer doit
sequence cc_name, echo
sequence file0
sequence prepared_file0

global procedure start_emake()
-- start creating emake.bat     
	sequence debug_flag
	debug_flag = ""
	
	if TUNIX then      
		doit = open("emake", "wb")
	else       
		doit = open("emake.bat", "wb")
	end if      
		
	if doit = -1 then
		CompileErr("Couldn't create batch file for compile.\n")
	end if
		
	if not TUNIX then
		puts(doit, "@echo off"&HOSTNL)
		puts(doit, "if not exist main-.c goto nofiles"&HOSTNL)
	end if
	
	ifdef DOS32 then
		prepared_file0 = truncate_to_83(file0)
	elsedef
		prepared_file0 = file0
	end ifdef
	
	if TDOS then
		if sequence(wat_path) then
			if debug_option then
				debug_flag = "/d2 "
			end if
			-- /ol removed due to bugs with SEQ_PTR() inside a loop
			-- can remove /fpc and add /fp5 /fpi87 for extra speed
			puts(doit, "echo compiling with WATCOM"&HOSTNL)
			if fastfp then
				-- fast f.p. that assumes f.p. hardware
				c_opts = debug_flag & " /w0 /zq /j /zp4 /fp5 /fpi87 /5r /otimra /s"
			else    
				-- slower f.p. but works on all machines
				c_opts = debug_flag & "/w0 /zq /j /zp4 /fpc /5r /otimra /s"
			end if
				
		else 
			if debug_option then
				debug_flag = " -g3"
			else
				debug_flag = " -fomit-frame-pointer -g0"
			end if
			puts(doit, "echo compiling with DJGPP"&HOSTNL)
			c_opts = "-c -w -fsigned-char -O2 -ffast-math" & debug_flag
		end if
	end if

	if TWINDOWS then
		if sequence(wat_path) then
			puts(doit, "echo compiling with WATCOM"&HOSTNL)
			if debug_option then
				debug_flag = " /d3"
			end if
			--  /ol removed due to bugs with SEQ_PTR() inside a loop
			if dll_option then
				c_opts = "/bd /bt=nt /mf /w0 /zq /j /zp4 /fp5 /fpi87 /5r /otimra /s" & debug_flag
			else
				c_opts = "/bt=nt /mf /w0 /zq /j /zp4 /fp5 /fpi87 /5r /otimra /s" & debug_flag
			end if
			
		elsif sequence(bor_path) then
			if debug_option then
				debug_flag = " -v "
			end if
			puts(doit, "echo compiling with BORLAND"&HOSTNL)
			c_opts = " -q -w- -O2 -5 -a4 -I" & debug_flag
			if dll_option then
				c_opts = "-tWD" & c_opts
			elsif con_option then
				c_opts = "-tWC" & c_opts
			else    
				c_opts = "-tW" & c_opts
			end if
			c_opts &= bor_path & "\\include -L" & bor_path & "\\lib"

		else 
			-- LccWin 
			if debug_option then
				debug_flag = " -g"
			end if
			puts(doit, "echo compiling with LCCWIN"&HOSTNL)
			c_opts = "-w -Zp4" & debug_flag

			-- -O causes some problems sometimes. Use -LCCOPT-OFF to
			-- disable the use of -O on LCC.
			if lccopt_option = TRUE then
				c_opts &= " -O"
			end if
		end if
		
		c_opts &= sprintf( " -I%s", {get_eudir()})
	end if
	
	if TUNIX then
		puts(doit, "echo compiling with GNU C"&HOSTNL)
		cc_name = "gcc"
		echo = "echo"
		if debug_option then
			debug_flag = " -g3"
		else
			debug_flag = " -fomit-frame-pointer"
		end if
		if dll_option then
			c_opts = "-c -w -fPIC -fsigned-char -O2 -I"&get_eudir()&" -ffast-math" & debug_flag
		else 
			c_opts = "-c -w -fsigned-char -O2 -I"&get_eudir()&" -ffast-math" & debug_flag
		end if
		link_line = ""
	else       
		echo = "echo"
		link_file = open("objfiles.lnk", "w")
		files_to_delete = append(files_to_delete, "objfiles.lnk")
		if link_file = -1 then
			CompileErr("Couldn't open objfiles.lnk for output")
		end if
	end if
	
	if TDOS then
		if sequence(wat_path) then  
			cc_name = "wcc386"
			if not dll_option and debug_option then
				puts(link_file, "DEBUG ALL\n")
			end if
			puts(link_file, "option osname='CauseWay'\n")
			printf(link_file, "libpath %s\\lib386\n", {wat_path})
			printf(link_file, "libpath %s\\lib386\\dos\n", {wat_path})
			printf(link_file, "OPTION stub=%s\\bin\\cwstub.exe\n", {shrink_to_83(get_eudir())})
			puts(link_file, "format os2 le ^\n")
			printf(link_file, "OPTION STACK=%d\n", total_stack_size) 
			puts(link_file, "OPTION QUIET\n") 
			puts(link_file, "OPTION ELIMINATE\n") 
			puts(link_file, "OPTION CASEEXACT\n")
			printf(link_file, "FILE %s.obj\n", {prepared_file0} )
		else 
			cc_name = "gcc"
		end if
		c_opts &= sprintf( " -I%s", {shrink_to_83(get_eudir())})
	end if      

	if TWINDOWS then    
		if sequence(wat_path) then		
			cc_name = "wcc386"
			
			if not dll_option and debug_option then
				puts(link_file, "DEBUG ALL\n")
			end if
			if dll_option then    
				puts(link_file, "SYSTEM NT_DLL initinstance terminstance\n")
			elsif con_option then
				puts(link_file, "SYSTEM NT\n")
			else    
				puts(link_file, "SYSTEM NT_WIN\n")
				puts(link_file, "RUNTIME WINDOWS=4.0\n") 
			end if
			printf(link_file, "OPTION STACK=%d\n", total_stack_size) 
			printf(link_file, "COMMIT STACK=%d\n", total_stack_size) 
			
			puts(link_file, "OPTION QUIET\n") 
			puts(link_file, "OPTION ELIMINATE\n") 
			puts(link_file, "OPTION CASEEXACT\n") 
			printf(link_file, "FILE %s.obj\n", {prepared_file0} )			
		elsif sequence(bor_path) then
			cc_name = "bcc32"
			
		else 
			cc_name = "lcc"
			
		end if
	end if      
end procedure       

type legaldos_filename_char( integer i )
	if ('A' <= i and i <= 'Z') or
	   ('0' <= i and i <= '9') or
	   (128 <=i and  i <= 255) or
	   find( i, " !#$%'()@^_`{}~" ) != 0
	then
		return 1
	else
		return 0
	end if
end type  

type legaldos_filename( sequence s )
	integer dloc

	if find( s, { "..", "." } ) then
		return 1
	end if
	dloc = find('.',s)
	if dloc > 8 or ( dloc > 0 and dloc + 3 < length(s) ) or ( dloc = 0 and length(s) > 8 ) then
		return 0
	end if
	for i = 1 to length(s) do
		if s[i] = '.' then
			for j = i+1 to length(s) do
				if not legaldos_filename_char(s[j]) then
					return 0
				end if
			end for
			exit
		end if
		if not legaldos_filename_char(s[i]) then
			return 0
		end if
	end for
	
	return 1
end type

function shrink_to_83( sequence s )
	integer dl, -- dot location
		sl, -- slash location
		osl -- old slash location
	sequence se -- short extension

	osl = find( ':', s )
	sl = osl + find( '\\', s[osl+1..$] ) -- find_from osl
	-- if slash immediately follows the colon skip the part between : and slash.
	if sl=osl+1 then
		osl = sl
	end if
	sl = osl + find( '\\', s[osl+1..$] )
	dl = osl + find( '.', s[osl+1..sl] )
	if dl > osl then
		se = s[dl..min({dl+3,sl-1})]
	else
		se = ""
	end if
	
	while sl != osl do
		if find( ' ', s[osl+1..sl] ) or not legaldos_filename(upper(s[osl+1..sl-1])) then
			s = s[1..osl] & s[osl+1..osl+6] & "~1" & se & s[sl..$]
			sl = osl+8+length(se)
		end if
		osl = sl
		sl += find( '\\', s[sl+1..$] )
		dl = osl + find( '.', s[osl+1..sl] )
		if dl > osl then
			se = s[dl..min({dl+3,sl})]
		else
			se = ""
		end if
	end while
	if dl > osl then
		se = s[dl..min({dl+3,length(s)})]
	end if
	if find( ' ', s[osl+1..$] ) or not legaldos_filename(upper(s[osl+1..$])) then
		s = s[1..osl] & s[osl+1..osl+6] & "~1" & se
	end if
	
	return s
end function

function truncate_to_83( sequence lfn )
	integer dl
	dl = find( '.', lfn )
	if dl = 0 and length(lfn) > 8 then
		return lfn[1..8]
	elsif dl = 0 and length(lfn) <= 8 then
		return lfn
	elsif dl > 9 and dl + 3 <= length(lfn) then
		return lfn[1..8] & lfn[dl..$]
	else
		CompileErr( "Cannot use the filename, " & lfn & ", under DOS.  Use the Windows version with -plat DOS instead.\n")
	end if
end function

global procedure finish_emake()
-- finish emake.bat 
	sequence path, def_name, dll_flag, exe_suffix, buff, subsystem, short_c_file, arguments
	object bin_path
	integer lib_dir
	integer fp, def_file
	
	arguments = command_line()
	if length( arguments ) > 0 then
		integer sl
		sl = length( arguments[1] )
		while sl and arguments[1][sl] != SLASH do
			sl -= 1
		end while
		if sl then
			bin_path = arguments[1][1..sl-1]
		else
			bin_path = 0 
		end if
	else
		bin_path = 0
	end if

	-- init-.c files
	if atom(bor_path) then
		printf(doit, "%s init-.c"&HOSTNL, {echo})
		printf(doit, "%s %s init-.c"&HOSTNL, {cc_name, c_opts})
	end if
	add_file("init-")
	for i = 0 to init_name_num-1 do -- now that we know init_name_num
		if atom(bor_path) then
			printf(doit, "%s init-%d.c"&HOSTNL, {echo, i})
			printf(doit, "%s %s init-%d.c"&HOSTNL, {cc_name, c_opts, i})
		end if
		buff = sprintf("init-%d", i)
		add_file(buff)
	end for
		
	if atom(bor_path) then
		printf(doit, "%s linking"&HOSTNL, {echo})
	end if
	
	ifdef DOS32 then
		short_c_file = truncate_to_83(file0)
	elsedef
		short_c_file = file0
	end ifdef

	if atom(bin_path) then
		bin_path = get_eudir() & SLASH & "bin"
	end if
	
	if TDOS then    
		if sequence(wat_path) then
			printf(doit, "wlink @objfiles.lnk"&HOSTNL, {})
			if length( user_library ) then
				printf(link_file, "FILE %s", {shrink_to_83(user_library)})
			else
				printf(link_file, "FILE %s\\", {bin_path})
				if fastfp then
					puts(link_file, "ecfastfp.lib\n") 
				else    
					puts(link_file, "ec.lib\n") 
				end if
			end if
			if not keep then
				puts(doit, "del *.obj > NUL"&HOSTNL)
			end if
			path = get_eudir() & "\\bin\\le23p.exe"
			fp = open(path, "rb")
			if fp != -1 then
				close(fp)
				path = get_eudir() & "\\bin\\cwc.exe"
				fp = open(path, "rb")
				if fp != -1 then
					close(fp)
					if not debug_option then
						printf(doit, "le23p %s.exe"&HOSTNL, {shrink_to_83(short_c_file)})
						printf(doit, "cwc %s.exe"&HOSTNL, {shrink_to_83(short_c_file)})
					end if
					if compare( short_c_file, file0 ) != 0 then
						printf(doit, "move %s.exe \"%s.exe\""&HOSTNL, { short_c_file, file0 })
					end if 
				end if
			end if
			close(link_file)

		else 
			-- DJGPP 
			if length(user_library) then
				printf(link_file, "%s\n", {user_library}) 
			else
				printf(link_file, "%s\\ec.a\n", {bin_path}) 
			end if
			
			integer nsl,sl
			nsl = 0
			loop do
				sl = nsl
				nsl = sl + find( '\\', dj_path[sl+1..$] )
			until sl = nsl
			
			printf(link_file, "%slib\\liballeg.a\n", {dj_path[1..sl]}) 
			printf(doit, "gcc %s.o -o%s.exe @objfiles.lnk"&HOSTNL, repeat(truncate_to_83(file0), 2))
			if not keep then
				puts(doit, "del *.o"&HOSTNL)
			end if
			if not debug_option then
				puts(doit, "set LFN=n"&HOSTNL)
				printf(doit, "strip %s.exe"&HOSTNL, {file0})
				puts(doit, "set LFN="&HOSTNL)
			end if
			if compare(truncate_to_83(file0), file0)!=0 then
				printf(doit, "move %s.exe \"%s.exe\""&HOSTNL, 
					{truncate_to_83(file0),file0} )
			end if
		end if
	end if      

	if TWINDOWS then
		if sequence(wat_path) then     
			printf(doit, "wlink @objfiles.lnk"&HOSTNL, {})
			if length(user_library) then
				printf(link_file, "FILE %s\n", {user_library}) 
			else
				printf(link_file, "FILE %s\\ecw.lib\n", {bin_path}) 	
			end if
			if compare( short_c_file, file0 ) != 0 then
				printf(doit, "move %s.exe \"%s.exe\""&HOSTNL, { short_c_file, file0 })
			end if			

		elsif sequence(bor_path) then
			printf(doit, "bcc32 %s %s.c @objfiles.lnk"&HOSTNL, {c_opts, file0})
			if length(user_library) then
				printf(link_file, "%s\n", {user_library}) 
			else
				printf(link_file, "%s\\ecwb.lib\n", {bin_path}) 	
			end if
			
			if not keep then
				puts(doit, "del *.tds > NUL"&HOSTNL)
			end if
			
		else 
			-- Lcc 
			if dll_option then
				printf(doit, 
				"lcclnk -s -dll -subsystem windows %s.obj %s.def @objfiles.lnk"&HOSTNL,
				{file0, file0})
			else 
				if con_option then
					subsystem = "console"
				else
					subsystem = "windows"
				end if
				printf(doit, 
				"lcclnk -s -subsystem %s -stack-reserve %d -stack-commit %d %s.obj @objfiles.lnk"&HOSTNL, 
				{subsystem, total_stack_size, total_stack_size, file0})
			end if
			if length(user_library) then
				printf(link_file, "%s\n", {shrink_to_83(user_library)}) 
			else
				printf(link_file, "%s\\ecwl.lib\n", {shrink_to_83(bin_path)}) 
			end if
			
		end if
			
		if not keep then
			puts(doit, "del *.obj > NUL"&HOSTNL)
		end if
			
		def_name = sprintf("%s.def", {file0})
		def_file = -1
		if dll_option then
			-- write out exported symbols 
			if sequence(bor_path) or atom(wat_path) then
				-- Borland or Lcc 
				def_file= open(def_name, "w")
				if def_file = -1 then
					CompileErr("Couldn't open .def file for output")
				end if
				Write_def_file(def_file)
			else 
				-- WATCOM - just add to objfiles.lnk 
				Write_def_file(link_file)
			end if
		else
			if sequence(bor_path) then
				def_file= open(def_name, "w")
				if def_file = -1 then
					CompileErr("Couldn't open .def file for output")
				end if
				-- set reserved *and* committed memory, 
				-- else a crash will occur
				printf(def_file, "STACKSIZE %d,%d\n", 
					   {total_stack_size, total_stack_size})
			end if
		end if
		if def_file != -1 then
			files_to_delete = append(files_to_delete, def_name)
			close(def_file)
		end if
		close(link_file)
	end if

	if TUNIX then
		if dll_option then
			dll_flag = "-shared -nostartfiles"
			exe_suffix = ".so" 
		else 
			dll_flag = ""
			exe_suffix = ""
		end if
		if length(user_library) then
			printf(doit, 
				  "gcc %s %s.o %s %s -o %s -lm ",
				  {dll_flag, short_c_file, link_line, user_library, file0})
		else
			-- need to check to see if euphoria is installed into
			-- the system:
			lib_dir = open("/usr/lib/ecu.a","r" )
			if lib_dir = -1 then
				printf(doit, 
					"gcc %s %s.o %s -I%s %s/bin/ecu.a -o %s -lm ",
					{dll_flag, short_c_file, link_line, get_eudir(), get_eudir(), file0})
			else
				close(lib_dir)
				printf(doit,
					"gcc %s %s.o %s -I/usr/include/euphoria/ /usr/lib/ecu.a -o %s -lm",
					{dll_flag, short_c_file, link_line, file0})
			end if
			
		end if
		
		if not TBSD then
			puts(doit, " -ldl")
		end if      
		printf(doit, " -o %s%s"&HOSTNL, {file0, exe_suffix})
		if not keep then
			puts(doit, "rm -f *.o"&HOSTNL)
		end if
			
		if dll_option then
			printf(doit, "echo you can now link with: ./%s.so"&HOSTNL, {file0})
		else    
			printf(doit, "echo you can now execute: ./%s"&HOSTNL, {file0})
		end if
		delete_files(doit)
		
	else
		if dll_option then
			printf(doit, "if not exist %s.dll goto done"&HOSTNL, {file0})
			printf(doit, "echo you can now link with: %s.dll"&HOSTNL, {file0})
		else 
			printf(doit, "if not exist %s.exe goto done"&HOSTNL, {file0})
			printf(doit, "echo you can now execute: %s.exe"&HOSTNL, {file0})
		end if
		delete_files(doit)
		puts(doit, "goto done"&HOSTNL)
		puts(doit, ":nofiles"&HOSTNL)
		puts(doit, "echo Run the translator to create new .c files"&HOSTNL)
		puts(doit, ":done"&HOSTNL)
	end if
		
	close(doit)
	if TUNIX and EUNIX then
		system("chmod +x emake", 2)
	end if
end procedure

global procedure GenerateUserRoutines()
-- walk through the user-defined routines, computing types and
-- optionally generating code 
	symtab_index s, sp
	integer next_c_char, q, temps
	sequence buff, base_name, long_c_file, c_file



	for file_no = 1 to length(file_name) do
		if file_no = 1 or any_code(file_no) then 
			-- generate a .c file for this Euphoria file
			-- (we need to use the name of the first file - don't skip it)
			next_c_char = 1
			base_name = name_ext(file_name[file_no])
			c_file = base_name

			q = length(c_file)
			while q >= 1 do
				if c_file[q] = '.' then
					c_file = c_file[1..q-1]
					exit
				end if
				q -= 1
			end while
						
			if find(lower(c_file), {"main-", "init-"})  then
				CompileErr(base_name & " conflicts with a file name used internally by the Translator")
			end if

			long_c_file = c_file
			ifdef DOS32 then
				c_file = truncate_to_83(c_file)
			end ifdef

			if Pass = LAST_PASS and file_no > 1 then
				c_file = unique_c_name(c_file)
				add_file(c_file)
			end if
		
			if file_no = 1 then
				-- do the standard top-level files as well 

				if Pass = LAST_PASS then
					if atom(bor_path) then
						printf(doit, "%s main-.c"&HOSTNL, {echo})                
						printf(doit, "%s %s main-.c"&HOSTNL, {cc_name, c_opts})
					end if
					add_file("main-")
					for i = 0 to main_name_num-1 do
						if atom(bor_path) then
							printf(doit, "%s main-%d.c"&HOSTNL, {echo, i})               
							printf(doit, "%s %s main-%d.c"&HOSTNL, {cc_name, c_opts, i})
						end if
						buff = sprintf("main-%d", i)
						add_file(buff)
					end for
				end if
				file0 = long_c_file
			end if
		
			if Pass = LAST_PASS then
				if atom(bor_path) then
					printf(doit, "%s %s.c"&HOSTNL, {echo, c_file})
					printf(doit, "%s %s %s.c"&HOSTNL, {cc_name, c_opts, c_file})
				end if
			end if
		
			new_c_file(c_file)
		
			s = SymTab[TopLevelSub][S_NEXT]
			while s do
				if SymTab[s][S_FILE_NO] = file_no and 
				SymTab[s][S_USAGE] != U_DELETED and
				find(SymTab[s][S_TOKEN], {PROC, FUNC, TYPE}) then
					-- a referenced routine in this file 
			  
					-- Check for oversize C file 
					if Pass = LAST_PASS and 
					   (cfile_size > MAX_CFILE_SIZE or 
						(s != TopLevelSub and cfile_size > MAX_CFILE_SIZE/4 and 
						length(SymTab[s][S_CODE]) > MAX_CFILE_SIZE)) then
						-- start a new C file 
						-- (we generate about 1 line of C per element of CODE)
						
						-- choose new file name, based on base_name
						if length(c_file) = 7 then
							-- make it size 8
							c_file &= " "
						end if
						if length(c_file) >= 8 then
							c_file[7] = '_'
							c_file[8] = file_chars[next_c_char]
						else 
							-- 6 or less
							if find('_', c_file) = 0 then
								c_file &= "_ "
							end if
							c_file[$] = file_chars[next_c_char]
						end if
						
						-- make sure we haven't created a duplicate name
						c_file = unique_c_name(c_file)
						new_c_file(c_file)

						next_c_char += 1
						if next_c_char > length(file_chars) then
							next_c_char = 1  -- (unique_c_name will resolve)
						end if
						
						if atom(bor_path) then
							printf(doit, "%s %s.c"&HOSTNL, {echo, c_file})
							printf(doit, "%s %s %s.c"&HOSTNL, {cc_name, c_opts, c_file})
						end if
						add_file(c_file)
					end if
					
					sequence ret_type
					if SymTab[s][S_TOKEN] = PROC then
						ret_type = ""
					else
						ret_type = "int "
					end if
					if find( SymTab[s][S_SCOPE], {SC_GLOBAL, SC_EXPORT, SC_PUBLIC} ) and dll_option then
						-- declare the global routine as an exported DLL function
						if TWINDOWS then      
							-- c_stmt0("int __declspec (dllexport) __stdcall\n")
							c_stmt0( ret_type & "__stdcall\n")
						end if                  
						-- mark it as a routine_id target, so it won't be deleted
						SymTab[s][S_RI_TARGET] = TRUE
						LeftSym = TRUE
						c_stmt(ret_type & "@(", s)
					else 
						LeftSym = TRUE
						c_stmt( ret_type & "@(", s)
					end if
				
					-- declare the parameters 
					sp = SymTab[s][S_NEXT]
					for p = 1 to SymTab[s][S_NUM_ARGS] do
						c_puts("int _")
						c_puts(ok_name(SymTab[sp][S_NAME]))  
						if p != SymTab[s][S_NUM_ARGS] then
							c_puts(", ")
						end if
						sp = SymTab[sp][S_NEXT]
					end for
				
					c_puts(")\n")
					c_stmt0("{\n")

					NewBB(0, E_ALL_EFFECT, 0)
					Initializing = TRUE
					
					-- declare the private vars 
					while sp do
						integer scope = SymTab[sp][S_SCOPE]
						switch scope do
							case SC_LOOP_VAR:
							case SC_UNDEFINED:
								-- don't need to declare this
								-- an undefined var is a forward reference
								break
						
							case SC_PRIVATE:
								c_stmt0("int ")
								c_puts("_")
								c_puts(ok_name(SymTab[sp][S_NAME]))
								if SymTab[sp][S_GTYPE] != TYPE_INTEGER then
									-- avoid DeRef in 1st BB
									c_puts(" = 0")
									target[MIN] = 0
									target[MAX] = 0
									SetBBType(sp, TYPE_INTEGER, target, TYPE_OBJECT)
								end if
								c_puts(";\n")
								break
								
							case else
								exit
						end switch
						sp = SymTab[sp][S_NEXT]
					end while
				
					-- declare the temps 
					temps = SymTab[s][S_TEMPS]
					sequence names = {}
					while temps != 0 do
						if SymTab[temps][S_SCOPE] != DELETED then
							sequence name = sprintf("_%d", SymTab[temps][S_TEMP_NAME] )
							if temp_name_type[SymTab[temps][S_TEMP_NAME]][T_GTYPE] 
																!= TYPE_NULL 
								and not find( name, names ) then
								c_stmt0("int ")
								c_puts( name )
								if temp_name_type[SymTab[temps][S_TEMP_NAME]][T_GTYPE] 
																!= TYPE_INTEGER then
									c_puts(" = 0")
									-- avoids DeRef in 1st BB, but may hurt global type:
									target = {0, 0}
									-- PROBLEM: sp could be temp or symtab entry?
									SetBBType(temps, TYPE_INTEGER, target, TYPE_OBJECT)
								end if
								ifdef DEBUG then
									c_puts(sprintf("; // %d %d\n", {temps, SymTab[temps][S_TEMP_NAME]} ) )
								elsedef
									c_puts(";\n")
								end ifdef
								names = prepend( names, name )
							else
								ifdef DEBUG then
									c_printf("// skipping %s  name type: %d\n", {name,temp_name_type[SymTab[temps][S_TEMP_NAME]][T_GTYPE] } )
								end ifdef
							end if
						end if
						SymTab[temps][S_GTYPE] = TYPE_OBJECT
						temps = SymTab[temps][S_NEXT]
					end while
					Initializing = FALSE
				
					if SymTab[s][S_LHS_SUBS2] then
						c_stmt0("int _0, _1, _2, _3;\n\n")
					else    
						c_stmt0("int _0, _1, _2;\n\n")
					end if
				
					-- set the local parameter types in BB 
					-- this will kill any unnecessary INTEGER_CHECK conversions 
					sp = SymTab[s][S_NEXT]
					for p = 1 to SymTab[s][S_NUM_ARGS] do
						SymTab[sp][S_ONE_REF] = FALSE
						if SymTab[sp][S_ARG_TYPE] = TYPE_SEQUENCE then
							target[MIN] = SymTab[sp][S_ARG_SEQ_LEN]
							SetBBType(sp, SymTab[sp][S_ARG_TYPE], target, 
										SymTab[sp][S_ARG_SEQ_ELEM])
					
						elsif SymTab[sp][S_ARG_TYPE] = TYPE_INTEGER then
							if SymTab[sp][S_ARG_MIN] = NOVALUE then
								target[MIN] = MININT
								target[MAX] = MAXINT
							else 
								target[MIN] = SymTab[sp][S_ARG_MIN]
								target[MAX] = SymTab[sp][S_ARG_MAX]
							end if
							SetBBType(sp, SymTab[sp][S_ARG_TYPE], target, TYPE_OBJECT)
					
						elsif SymTab[sp][S_ARG_TYPE] = TYPE_OBJECT then
							-- object might have valid seq_elem
							SetBBType(sp, SymTab[sp][S_ARG_TYPE], novalue, 
									SymTab[sp][S_ARG_SEQ_ELEM]) 
					
						else 
							SetBBType(sp, SymTab[sp][S_ARG_TYPE], novalue, TYPE_OBJECT) 
					
						end if
						sp = SymTab[sp][S_NEXT]
					end for
				
					-- walk through the IL for this routine 
					call_proc(Execute_id, {s})
					
					c_puts("    ;\n}\n")
					if TUNIX and dll_option and is_exported( s ) then
						-- create an alias for exporting routines
						LeftSym = TRUE
						c_stmt( ret_type & SymTab[s][S_NAME] & "() __attribute__ ((alias (\"@\")));\n", s )
						LeftSym = FALSE
					end if
					c_puts("\n\n" )
				end if
			
				s = SymTab[s][S_NEXT]
			end while
		end if
	end for   
end procedure



