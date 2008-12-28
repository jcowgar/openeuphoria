-- (c) Copyright 2007 Rapid Deployment Software - See License.txt
--
-- Forward reference resolution
namespace fwd

include global.e
include parser.e
include symtab.e
include error.e
include scanner.e
include shift.e

-- Tracking forward references
sequence forward_references = {}
enum
	FR_TYPE,
	FR_NAME,
	FR_FILE,
	FR_SUBPROG,
	FR_PC,
	FR_LINE,
	FR_THISLINE,
	FR_BP,
	FR_QUALIFIED,
	FR_OP,
	FR_PRIVATE_LIST,
	FR_DATA  -- extra info

constant FR_SIZE = FR_DATA

-- # extra default parameters to leave space when
-- emitting a forward call
export constant FORWARD_DEFAULT_PADDING = 5


-- TODO: update side effects tracking for routines
export integer parse_arg_rid
export integer pop_rid
integer shifting_sub = 0

sequence patch_code_temp = {}
symtab_index patch_code_sub
symtab_index patch_current_sub
procedure set_code( integer ref )
	patch_code_sub = forward_references[ref][FR_SUBPROG]
	
	if patch_code_sub != CurrentSub then
		patch_code_temp = Code
		Code = SymTab[patch_code_sub][S_CODE]
		patch_current_sub = CurrentSub
		CurrentSub = patch_code_sub
	else
		patch_current_sub = patch_code_sub
	end if
	
end procedure

procedure reset_code( )
	SymTab[patch_code_sub][S_CODE] = Code
	if patch_code_sub != patch_current_sub then
		CurrentSub = patch_current_sub
		Code = patch_code_temp
	end if
end procedure

export procedure set_data( integer ref, object data )
	forward_references[ref][FR_DATA] = data
end procedure

sequence fwd_private_sym  = {}
sequence fwd_private_name = {}
export procedure add_private_symbol( symtab_index sym, sequence name )
	
	fwd_private_sym &= sym
	fwd_private_name = append( fwd_private_name, name )
	
end procedure

procedure reset_private_lists()
	fwd_private_sym  = {}
	fwd_private_name = {}
end procedure

procedure patch_forward_call( token tok, integer ref )
	-- Format of IL:
	-- pc   OPCODE
	-- pc+1 Proc Sym
	-- pc+2 Num args supplied => Next pc
	-- pc+3 Args... [/ Func target]
	
	sequence fr = forward_references[ref]
	integer code_sub = fr[FR_SUBPROG]
	shifting_sub = code_sub
	symtab_index sub = tok[T_SYM]
	integer args = SymTab[sub][S_NUM_ARGS]
	integer is_func = (SymTab[sub][S_TOKEN] = FUNC) or (SymTab[sub][S_TOKEN] = TYPE)
	
	integer real_file = current_file_no
	current_file_no = fr[FR_FILE]
	
	set_code( ref )
	sequence code = Code
	integer temp_sub = CurrentSub
	
	integer pc = fr[FR_PC]
	integer next_pc = pc
	integer supplied_args = code[pc+2]
	sequence name = fr[FR_NAME]
	next_pc +=
		  3                         -- op, sym, #args
		+ code[next_pc + 2]         -- # args emitted
		+ is_func                   -- target sym for func assignment
	integer target
	if is_func then
		target = Code[pc + 3 + supplied_args]
	end if
	integer has_defaults = 0
	integer goto_target = length( code ) + 1
	integer defarg = 0
	integer code_len = length(code)
	
	integer extra_default_args = 0
	set_dont_read( 1 )
	reset_private_lists()
	integer param_sym = sub
	sequence params = repeat( 0, args )
	sequence orig_code = code
	Code = {}
	for i = pc + 3 to pc + args + 2 do
		defarg += 1
		param_sym = SymTab[param_sym][S_NEXT]
		if defarg > supplied_args or i > length( code ) or not code[i] then
			-- default arg!
			has_defaults = 1
			extra_default_args += 1
			
			-- now we need to parse the args
			-- set up the environment
			
			show_params( sub )
			call_proc( parse_arg_rid, { sub, defarg, fwd_private_name, fwd_private_sym } )
			hide_params( sub )
			params[defarg] = call_func( pop_rid, {} )
		else
			extra_default_args = 0
			add_private_symbol( code[i], SymTab[param_sym][S_NAME] )
			params[defarg] = code[i]
		end if
	end for
	
	sequence new_code = Code
	Code = orig_code
	
	set_dont_read( 0 )
	current_file_no = real_file
	
	integer from_file = fr[FR_FILE]
	integer line      = fr[FR_LINE]
	sequence routine_type
	
	if is_func then 
		routine_type = "function"
	else
		routine_type = "procedure"
	end if
	sequence err_msg = ""
	
	if args != ( supplied_args + extra_default_args ) then
		err_msg = sprintf( "Wrong number of arguments supplied for forward reference\n\t%s (%d): %s %s.  Expected %d, but found %d.",
			{ file_name[from_file], line, routine_type, name, args, supplied_args + extra_default_args } )
	
	end if
	
	if length( err_msg ) then
		current_file_no = from_file
		line_number = line
		CompileErr( err_msg )
	end if
	
	new_code &= PROC & sub & params
	if is_func then
		new_code &= target
	end if
	
	replace_code( new_code, pc, next_pc - 1 )
	
	reset_code()
	-- mark this one as resolved already
	forward_references[ref] = 0
	shifting_sub = 0
end procedure

procedure set_error_info( integer ref )
	sequence fr = forward_references[ref]
	ThisLine        = fr[FR_THISLINE]
	bp              = fr[FR_BP]
	line_number     = fr[FR_LINE]
	current_file_no = fr[FR_FILE]
end procedure

procedure patch_forward_variable( token tok, integer ref )
-- forward reference for a variable
	sequence fr = forward_references[ref]
	symtab_index sym = tok[T_SYM]
	
	if SymTab[sym][S_FILE_NO] = fr[FR_FILE] then
		return
	end if
	
	if fr[FR_OP] = ASSIGN and SymTab[sym][S_MODE] = M_CONSTANT then
		prep_forward_error( ref )
		CompileErr( "may not change the value of a constant" )
	end if
	
	if fr[FR_OP] = ASSIGN then
		SymTab[sym][S_USAGE] = or_bits( U_WRITTEN, SymTab[sym][S_USAGE] )
	else
		SymTab[sym][S_USAGE] = or_bits( U_READ, SymTab[sym][S_USAGE] )
	end if
	
	set_code( ref )
	integer vx = find_from( -ref, Code, fr[FR_PC] )
	if vx then
		while vx do
			-- subscript assignments might cause the
			-- sym to be emitted multiple times
			Code[vx] = sym
			vx = find_from( -ref, Code, fr[FR_PC] )
		end while
		forward_references[ref] = 0
	end if
	reset_code()
end procedure

procedure patch_forward_init_check( token tok, integer ref )
-- forward reference for a variable
	sequence fr = forward_references[ref]
	set_code( ref )
	Code[fr[FR_PC]+1] = tok[T_SYM]
	forward_references[ref] = 0
	reset_code()
end procedure


function expected_name( integer id )
	
	switch id do
		case PROC:
		case PROC_FORWARD:
			return "a procedure"
			
		case FUNC:
		case FUNC_FORWARD:
			return "a function"
		
		case VARIABLE:
			return "a variable, constant or enum"
		case else
			return "something"
	end switch
	
end function


procedure patch_forward_type( token tok, integer ref )
	sequence fr = forward_references[ref]
	sequence syms = fr[FR_DATA]
	for i = 2 to length( syms ) do
		SymTab[syms[i]][S_VTYPE] = tok[T_SYM]
		if TRANSLATE then
			SymTab[syms[i]][S_GTYPE] = CompileType(tok[T_SYM])
		end if
	end for
	forward_references[ref] = 0
end procedure

procedure patch_forward_case( token tok, integer ref )
	sequence fr = forward_references[ref]
	
	integer switch_pc = fr[FR_DATA]
	
	symtab_index case_sym = SymTab[fr[FR_SUBPROG]][S_CODE][switch_pc + 2]
	
	sequence case_values = SymTab[case_sym][S_OBJ]
	
	integer cx = find( { ref }, case_values )
	if not cx then
		cx = find( { -ref }, case_values )
	end if
	
	if not cx then
		InternalErr( sprintf("Error resolving forward reference in case for '%s'", { fr[FR_NAME] } ) )
	end if
	
	integer negative = 0
	if case_values[cx][1] < 0 then
		negative = 1
		case_values[cx][1] *= -1
	end if
	
	if negative then
		case_values[cx] = - tok[T_SYM]
	else
		case_values[cx] = tok[T_SYM]
	end if
	SymTab[case_sym][S_OBJ] = case_values
	forward_references[ref] = 0
end procedure

procedure patch_forward_type_check( token tok, integer ref )
	sequence fr = forward_references[ref]
	symtab_index which_type
	symtab_index var
	
	if fr[FR_OP] = TYPE_CHECK_FORWARD then
		which_type = SymTab[tok[T_SYM]][S_VTYPE]
		if not which_type then
			which_type = tok[T_SYM]
			var = 0
		else
			var = tok[T_SYM]
		end if
		
		
	elsif fr[FR_OP] = TYPE then
		which_type = tok[T_SYM]
		var = 0
	
	else 
		prep_forward_error( ref )
		InternalErr( sprintf( "Bad operation.  Expected TYPE_CHECK (%d) or TYPE_CHECK_FORWARD (%d) , not %d", 
			{ TYPE_CHECK, TYPE_CHECK_FORWARD, fr[FR_OP] }) )
	end if
	
	set_code( ref )
	
	integer pc = fr[FR_PC]
	integer with_type_check = Code[pc + 2]
	
	if not var then
		-- type type was the forward reference
		var = Code[pc+1]
	end if
	
	-- clear out the old stuff
	replace_code( {}, pc, pc + 2 )
	
	if TRANSLATE then
		if with_type_check then
			if which_type != object_type then
				if SymTab[which_type][S_EFFECT] then
					-- only call user-defined types that have side-effects
					integer c = NewTempSym()
					insert_code( { PROC, which_type, var, c, TYPE_CHECK }, pc )
					pc += 5
				end if
			end if
		end if

	else
		if with_type_check then
			
			if which_type = object_type then
					-- skip it
			else
				-- TODO:  Some of these could be optimized away
				if which_type = integer_type then
					insert_code( { INTEGER_CHECK, var }, pc )
					pc += 2
					
				elsif which_type = sequence_type then
					insert_code( { SEQUENCE_CHECK, var }, pc)
					pc += 2
					
				elsif which_type = atom_type then
					insert_code( { ATOM_CHECK, var }, pc )
					pc += 2
					
				else
					integer start_pc = pc
					if SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] =
						integer_type then
						
						insert_code( { INTEGER_CHECK, var }, pc )
						
						pc += 2
					end if
					symtab_index c = NewTempSym()
					insert_code( { PROC, which_type, var, c, TYPE_CHECK }, pc )
					pc += 4
					
				end if
			end if
		end if
	end if

	if TRANSLATE or not with_type_check then
		integer start_pc = pc

		if which_type = sequence_type or
			SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] = sequence_type then
			-- check sequences anyway, so we can avoid it on subscripting etc.
			insert_code( { SEQUENCE_CHECK, var }, pc )
			pc += 2
			
		elsif which_type = integer_type or
				 SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] = integer_type then
				 -- check integers too
			insert_code( { INTEGER_CHECK, var }, pc )
			pc += 4
			
		end if
		
	end if
	forward_references[ref] = 0
	reset_code()
end procedure

procedure prep_forward_error( integer ref )
	ThisLine = forward_references[ref][FR_THISLINE]
	bp = forward_references[ref][FR_BP]
	line_number = forward_references[ref][FR_LINE]
	current_file_no = forward_references[ref][FR_FILE]
end procedure

procedure forward_error( token tok, integer ref )
	prep_forward_error( ref )
	CompileErr(sprintf("expected %s, not %s", 
		{ expected_name( forward_references[ref][FR_TYPE] ),
			expected_name( tok[T_ID] ) } ) )
end procedure

function find_reference( sequence fr )
	
	sequence name = fr[FR_NAME]
	integer file  = fr[FR_FILE]
	
	integer ns_file = -1
	integer ix = find( ':', name )
	if ix then
		sequence ns = name[1..ix-1]
		token ns_tok = keyfind( ns, ns_file, file, 1 )
		if ns_tok[T_ID] != NAMESPACE then
			return ns_tok
		end if
	else
		ns_file = fr[FR_QUALIFIED]
	end if
	
	No_new_entry = 1
	token tok = keyfind( name, ns_file, file )
	No_new_entry = 0
	return tok
end function

-- record places where we're using a forward type so it can be patched later
export procedure register_forward_type( symtab_index sym, integer ref )
	if ref < 0 then
		ref = -ref
	end if
	forward_references[ref][FR_DATA] &= sym
end procedure

export function new_forward_reference( integer fwd_op, symtab_index sym, integer op = fwd_op  )
	forward_references = append( forward_references, repeat( 0, FR_SIZE ) )
	integer ref = length( forward_references )
	
	
	forward_references[ref][FR_TYPE]      = fwd_op
	if sym < 0 then
		forward_references[ref][FR_NAME] = forward_references[-sym][FR_NAME]
	else
		forward_references[ref][FR_NAME] = SymTab[sym][S_NAME]
	end if
	
	forward_references[ref][FR_FILE]      = current_file_no
	forward_references[ref][FR_SUBPROG]   = CurrentSub
	forward_references[ref][FR_PC]        = length( Code ) + 1
	forward_references[ref][FR_LINE]      = fwd_line_number
	forward_references[ref][FR_THISLINE]  = ForwardLine
	forward_references[ref][FR_BP]        = forward_bp
	forward_references[ref][FR_QUALIFIED] = get_qualified_fwd()
	forward_references[ref][FR_OP]        = op
	return ref
end function

export procedure Resolve_forward_references( integer report_errors = 0 )
	sequence errors = {}
	sequence code = {}
	integer unincluded_ok = get_resolve_unincluded_globals()
	
	for ref = length( forward_references ) to 1 by -1 do
		
		if sequence( forward_references[ref] ) then
			sequence fr = forward_references[ref]
			if include_matrix[fr[FR_FILE]][current_file_no] = NOT_INCLUDED and not unincluded_ok then
				continue
			end if
			token tok = find_reference( fr )
			
			if tok[T_ID] = IGNORED then
				errors &= ref
				continue
			end if
			
			sequence fname = file_name[fr[FR_FILE]]
			sequence cname = file_name[current_file_no]
			
			-- found a match...
			integer code_sub = fr[FR_SUBPROG]
			integer fr_type  = fr[FR_TYPE]
			integer sym_tok
			
			switch fr_type label "fr_type" do
				case PROC:
				case FUNC:
					
					sym_tok = SymTab[tok[T_SYM]][S_TOKEN]
					if sym_tok = TYPE then
						sym_tok = FUNC
					end if
					if sym_tok != fr_type then
						forward_error( tok, ref )
					end if
					switch sym_tok do
						case PROC:
						case FUNC:
							patch_forward_call( tok, ref )
							continue
							
						case else
							forward_error( tok, ref )
							
					end switch
					
				case VARIABLE:
					sym_tok = SymTab[tok[T_SYM]][S_TOKEN]
					if SymTab[tok[T_SYM]][S_SCOPE] = SC_UNDEFINED then
						errors &= ref
						continue
					end if
					switch sym_tok do
						case CONSTANT:
						case ENUM:
						case VARIABLE:
							patch_forward_variable( tok, ref )
							if sequence( forward_references[ref] ) then
								errors &= ref
							end if
							continue
						case else
							forward_error( tok, ref )
					end switch
				case TYPE_CHECK:
					patch_forward_type_check( tok, ref )
					continue
				
				case GLOBAL_INIT_CHECK:
					patch_forward_init_check( tok, ref )
					continue
				
				case CASE:
					patch_forward_case( tok, ref )
					continue
					
				case TYPE:
					patch_forward_type( tok, ref )
					continue
					
				case else
					-- ?? what is it?
					InternalErr( sprintf("unrecognized forward reference type: %d (%s)", {fr[FR_TYPE], fr[FR_NAME]} ))
			end switch
		end if
	end for
	
	if report_errors and length( errors ) then
		sequence msg = "Errors resolving the following references:\n"
		integer error_count = 0
		
		for e = 1 to length( errors ) do
			sequence ref = forward_references[errors[e]]
			if (ref[FR_TYPE] = TYPE_CHECK and ref[FR_OP] = TYPE_CHECK) or ref[FR_TYPE] = GLOBAL_INIT_CHECK then
				-- these checks end up looking like duplicate errors
				continue

			else
				msg &= sprintf("\t%s (%d): %s\n", {file_name[ref[FR_FILE]], ref[FR_LINE], ref[FR_NAME]} )
			end if
			error_count += 1
			ThisLine    = ref[FR_THISLINE]
			bp          = ref[FR_BP]
			CurrentSub  = ref[FR_SUBPROG]
			line_number = ref[FR_LINE]
		end for
		if error_count then
			CompileErr( msg )
		end if
	end if
end procedure

export function might_be_fwdref( sequence name )
	for i = 1 to length( forward_references ) do
		if sequence( forward_references[i] ) and equal( forward_references[i][FR_NAME], name ) then
			return 1
		end if
	end for
	return 0
end function

export procedure shift_fwd_refs( integer pc, integer amount )
	for i = 1 to length( forward_references ) do
		if sequence( forward_references[i] ) then
			sequence ref = forward_references[i]
			if ref[FR_SUBPROG] = shifting_sub then
				if ref[FR_PC] > pc then
					forward_references[i][FR_PC] += amount
				end if
			end if
		end if
	end for
end procedure
