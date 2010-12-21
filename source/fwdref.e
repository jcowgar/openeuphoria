-- (c) Copyright - See License.txt
--
-- Forward reference resolution

namespace fwd

ifdef ETYPE_CHECK then
	with type_check
elsedef
	without type_check
end ifdef
without type_check
include std/filesys.e

include global.e
include parser.e
include symtab.e
include error.e
include scanner.e
include shift.e
include reswords.e
include block.e
include emit.e


-- Tracking forward references
sequence 
	forward_references  = {},
	active_subprogs     = {},
	active_references   = {},
	toplevel_references = {},
	inactive_references = {}


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
	FR_HASHVAL,
--	FR_PRIVATE_LIST, -- not used yet
	FR_DATA  -- extra info

constant FR_SIZE = FR_DATA

-- # extra default parameters to leave space when
-- emitting a forward call
export constant FORWARD_DEFAULT_PADDING = 5


-- TODO: update side effects tracking for routines
--export integer parse_arg_rid
integer shifting_sub = 0
integer fwdref_count = 0

export procedure clear_fwd_refs()
	fwdref_count = 0
end procedure

export function get_fwdref_count()
	return fwdref_count
end function

export procedure set_glabel_block( integer ref, symtab_index block )
	forward_references[ref][FR_DATA] &= block
end procedure

procedure insert_code( sequence code, integer index, integer subprog )
	shifting_sub = subprog
	shift:insert_code( code, index )
	shifting_sub = 0
end procedure

procedure replace_code( sequence code, integer start, integer finish, integer subprog )
	shifting_sub = subprog
	shift:replace_code( code, start, finish )
	shifting_sub = 0
end procedure

procedure resolved_reference( integer ref )
	integer 
		file    = forward_references[ref][FR_FILE],
		subprog = forward_references[ref][FR_SUBPROG]
	
	integer 
		tx = 0,
		ax = 0,
		sp = 0
	
	if forward_references[ref][FR_SUBPROG] = TopLevelSub then
		tx = find( ref, toplevel_references[file] )
	else
		sp = find( subprog, active_subprogs[file] )
		ax = find( ref, active_references[file][sp] )
	end if
	
	if ax then
		sequence r = active_references[file][sp] 
		active_references[file][sp] = 0
		r = remove( r, ax )
		active_references[file][sp] = r
		
		if not length( active_references[file][sp] ) then
			r = active_references[file]
			active_references[file] = 0
			r = remove( r, sp )
			active_references[file] = r
			
			r = active_subprogs[file]
			active_subprogs[file] = 0
			r = remove( r,   sp )
			active_subprogs[file] = r
		end if
	elsif tx then
		sequence r = toplevel_references[file]
		toplevel_references[file] = 0
		r = remove( r, tx )
		toplevel_references[file] = r
		
	else
		InternalErr( 260 )
	end if
	inactive_references &= ref
	forward_references[ref] = 0
end procedure

sequence patch_code_temp = {}
sequence patch_linetab_temp = {}
symtab_index patch_code_sub
symtab_index patch_current_sub
procedure set_code( integer ref )
	patch_code_sub = forward_references[ref][FR_SUBPROG]
	
	if patch_code_sub != CurrentSub then
		patch_code_temp = Code
		patch_linetab_temp = LineTable
		
		Code = SymTab[patch_code_sub][S_CODE]
		SymTab[patch_code_sub][S_CODE] = 0
		LineTable = SymTab[patch_code_sub][S_LINETAB]
		
		patch_current_sub = CurrentSub
		CurrentSub = patch_code_sub
	else
		patch_current_sub = patch_code_sub
	end if
end procedure

procedure reset_code( )
	SymTab[patch_code_sub][S_CODE] = Code
	SymTab[patch_code_sub][S_LINETAB] = LineTable
	if patch_code_sub != patch_current_sub then
		CurrentSub = patch_current_sub
		Code = patch_code_temp
		LineTable = patch_linetab_temp
	end if
	patch_code_temp = {}
	patch_linetab_temp = {}
end procedure

export procedure set_data( integer ref, object data )
	forward_references[ref][FR_DATA] = data
end procedure

export procedure add_data( integer ref, object data )
	forward_references[ref][FR_DATA] = append( forward_references[ref][FR_DATA], data )
end procedure

export procedure set_line( integer ref, integer line_no, sequence this_line, integer bp )
	forward_references[ref][FR_LINE] = line_no
	forward_references[ref][FR_THISLINE] = this_line
	forward_references[ref][FR_BP] = bp
end procedure

sequence fwd_private_sym  = {}
sequence fwd_private_name = {}
-- add a private symbol which could be a forward reference or an already
-- known symbol.
export procedure add_private_symbol( symtab_pointer sym, sequence name )
	
	fwd_private_sym &= sym
	fwd_private_name = append( fwd_private_name, name )
	
end procedure

procedure reset_private_lists()
	fwd_private_sym  = {}
	fwd_private_name = {}
end procedure

procedure patch_forward_goto( token tok, integer ref )
	sequence fr = forward_references[ref]
	set_code( ref )
	-- Goto_block may insert code, so we need to remember where we are
	shifting_sub = fr[FR_SUBPROG]
	
	if length( fr[FR_DATA] ) = 2 then
		prep_forward_error( ref )
		CompileErr( 156, { fr[FR_DATA][2] })
	end if
	
	Goto_block(  fr[FR_DATA][1], fr[FR_DATA][3], fr[FR_PC] )
	
	shifting_sub = 0
	
	reset_code()
	resolved_reference( ref )
end procedure

procedure patch_forward_call( token tok, integer ref )
	-- Format of IL:
	-- pc   OPCODE
	-- pc+1 Proc Sym
	-- pc+2 Num args supplied => Next pc
	-- pc+3 Args... [/ Func target]
	
	sequence fr = forward_references[ref]
	integer code_sub = fr[FR_SUBPROG]
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
	
	if Code[pc] != FUNC_FORWARD and Code[pc] != PROC_FORWARD then
		prep_forward_error( ref )
		CompileErr( "The forward call to [4] wasn't where we thought it would be: [1]:[2]:[3]",
			{ known_files[current_file_no], sym_name( fr[FR_SUBPROG] ), fr[FR_LINE], fr[FR_NAME] })
	end if
	
	integer old_temps_allocated = temps_allocated
	temps_allocated = 0
	
	if is_func and fr[FR_OP] = PROC then
		-- an unused forward function call!
		-- need to convert from a PROC_FORWARD to a FUNC_FORWARD
		symtab_index temp_target = NewTempSym()
		sequence converted_code = 
			FUNC_FORWARD 
			& Code[pc+1..pc+2+supplied_args] 
			& temp_target 
			& { DEREF_TEMP, temp_target }
		
		replace_code( converted_code, pc, pc + 2 + supplied_args, code_sub )

		code = Code
	end if
	next_pc +=
		  3                         -- op, sym, #args
		+ supplied_args             -- # args emitted
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
	sequence orig_linetable = LineTable
	Code = {}
	
	
	integer ar_sp = find( code_sub, active_subprogs[current_file_no] )
	integer pre_refs
	
	if code_sub = TopLevelSub then
		pre_refs = length( toplevel_references[current_file_no] )
	else
		ar_sp = find( code_sub, active_subprogs[current_file_no] )
		pre_refs = length( active_references[current_file_no][ar_sp] )
	end if
	
	sequence old_fwd_params = {}
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
			set_error_info( ref )
			Parse_default_arg(sub, defarg, fwd_private_name, fwd_private_sym) --call_proc( parse_arg_rid, { sub, defarg, fwd_private_name, fwd_private_sym } )
			hide_params( sub )
			params[defarg] = Pop()
		else
			extra_default_args = 0
			add_private_symbol( code[i], SymTab[param_sym][S_NAME] )
			params[defarg] = code[i]
		end if
	end for
	
	SymTab[code_sub][S_STACK_SPACE] += temps_allocated
	temps_allocated = old_temps_allocated
	
	-- In case anything was inlined, we need to shift the code so it's correct for its
	-- final place in the original code, since we've been building this stream of IL
	-- from an empty sequence, rather than actually inline with the function call.
	integer temp_shifting_sub = shifting_sub
	shift( -pc, pc-1 )
	
	sequence new_code = Code
	Code = orig_code
	LineTable = orig_linetable
	set_dont_read( 0 )
	current_file_no = real_file
	
	if args != ( supplied_args + extra_default_args ) then
		sequence routine_type
		
		if is_func then 
			routine_type = "function"
		else
			routine_type = "procedure"
		end if
		current_file_no = fr[FR_FILE]
		line_number = fr[FR_LINE]
		CompileErr( 158,
			{ known_files[current_file_no], line_number, routine_type, name, args, supplied_args + extra_default_args }  )
	end if
	
	new_code &= PROC & sub & params
	if is_func then
		new_code &= target
	end if

	replace_code( new_code, pc, next_pc - 1, code_sub )
	
	if code_sub = TopLevelSub then
		for i = pre_refs + 1 to length( toplevel_references[fr[FR_FILE]] ) do
			forward_references[toplevel_references[fr[FR_FILE]][i]][FR_PC] += pc - 1
		end for
	else
		for i = pre_refs + 1 to length( active_references[fr[FR_FILE]][ar_sp] ) do
			forward_references[active_references[fr[FR_FILE]][ar_sp][i]][FR_PC] += pc - 1
		end for
	end if
	
	reset_code()
	
	-- mark this one as resolved already
	resolved_reference( ref )
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
	
	if SymTab[sym][S_FILE_NO] = fr[FR_FILE] 
	and fr[FR_SUBPROG] = TopLevelSub then
		return
	end if
	
	if fr[FR_OP] = ASSIGN and SymTab[sym][S_MODE] = M_CONSTANT then
		prep_forward_error( ref )
		CompileErr( 110 )
	end if
	
	if fr[FR_OP] = ASSIGN then
		SymTab[sym][S_USAGE] = or_bits( U_WRITTEN, SymTab[sym][S_USAGE] )
	else
		SymTab[sym][S_USAGE] = or_bits( U_READ, SymTab[sym][S_USAGE] )
	end if
	
	set_code( ref )
	integer pc = fr[FR_PC]
	if pc < 1 then
		pc = 1
	end if
	integer vx = find( -ref, Code, pc )
	if vx then
		while vx do
			-- subscript assignments might cause the
			-- sym to be emitted multiple times
			Code[vx] = sym
			vx = find( -ref, Code, vx )
		end while
		resolved_reference( ref )
	end if
	reset_code()
end procedure

procedure patch_forward_init_check( token tok, integer ref )
-- forward reference for a variable
	sequence fr = forward_references[ref]
	set_code( ref )
	Code[fr[FR_PC]+1] = tok[T_SYM]
	resolved_reference( ref )
	reset_code()
end procedure


function expected_name( integer id )
	
	switch id with fallthru do
		case PROC then
		case PROC_FORWARD then
			return "a procedure"
			
		case FUNC then
		case FUNC_FORWARD then
			return "a function"
		
		case VARIABLE then
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
	resolved_reference( ref )
end procedure

procedure patch_forward_case( token tok, integer ref )
	sequence fr = forward_references[ref]
	
	integer switch_pc = fr[FR_DATA]

	symtab_index case_sym
	if fr[FR_SUBPROG] = TopLevelSub then
		case_sym = Code[switch_pc + 2]
	else
		case_sym = SymTab[fr[FR_SUBPROG]][S_CODE][switch_pc + 2]
	end if
	
	if current_file_no = fr[FR_FILE] and fr[FR_SUBPROG] = TopLevelSub then
		return
	end if
	
	sequence case_values = SymTab[case_sym][S_OBJ]
	
	integer cx = find( { ref }, case_values )
	if not cx then
		cx = find( { -ref }, case_values )
	end if
	
 	ifdef DEBUG then	
	if not cx then
		prep_forward_error( ref )
		InternalErr( 261, { fr[FR_NAME] } )
	end if
	end ifdef
	
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
	resolved_reference( ref )
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
		InternalErr( 262, { TYPE_CHECK, TYPE_CHECK_FORWARD, fr[FR_OP] })
	end if
	
	if which_type < 0 then
		-- not yet...
		return
	end if
	
	set_code( ref )
	
	integer pc = fr[FR_PC]
	integer with_type_check = Code[pc + 2]
	
	if Code[pc] != TYPE_CHECK_FORWARD then
		forward_error( tok, ref )
	end if
	if not var then
		-- type type was the forward reference
		var = Code[pc+1]
	end if
	
	if var < 0 then
		-- not yet...don't know the variable yet
		return
	end if
	
	-- clear out the old stuff
	replace_code( {}, pc, pc + 2, fr[FR_SUBPROG])
	
	if TRANSLATE then
		if with_type_check then
			if which_type != object_type then
				if SymTab[which_type][S_EFFECT] then
					-- only call user-defined types that have side-effects
					integer c = NewTempSym()
					insert_code( { PROC, which_type, var, c, TYPE_CHECK }, pc, fr[FR_SUBPROG] )
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
					insert_code( { INTEGER_CHECK, var }, pc, fr[FR_SUBPROG] )
					pc += 2
					
				elsif which_type = sequence_type then
					insert_code( { SEQUENCE_CHECK, var }, pc, fr[FR_SUBPROG])
					pc += 2
					
				elsif which_type = atom_type then
					insert_code( { ATOM_CHECK, var }, pc, fr[FR_SUBPROG] )
					pc += 2
					
				elsif SymTab[which_type][S_NEXT] then
					integer start_pc = pc
					
					
					if SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] = integer_type then
						
						insert_code( { INTEGER_CHECK, var }, pc, fr[FR_SUBPROG] )
						
						pc += 2
					end if
					symtab_index c = NewTempSym()
					SymTab[fr[FR_SUBPROG]][S_STACK_SPACE] += 1
					insert_code( { PROC, which_type, var, c, TYPE_CHECK }, pc, fr[FR_SUBPROG] )
					pc += 4
					
				end if
			end if
		end if
	end if

	if (TRANSLATE or not with_type_check) and SymTab[which_type][S_NEXT] then
		integer start_pc = pc

		if which_type = sequence_type or
			SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] = sequence_type then
			-- check sequences anyway, so we can avoid it on subscripting etc.
			insert_code( { SEQUENCE_CHECK, var }, pc, fr[FR_SUBPROG] )
			pc += 2
			
		elsif which_type = integer_type or
				 SymTab[SymTab[which_type][S_NEXT]][S_VTYPE] = integer_type then
				 -- check integers too
			insert_code( { INTEGER_CHECK, var }, pc, fr[FR_SUBPROG] )
			pc += 4
			
		end if
		
	end if
	resolved_reference( ref )
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
	CompileErr(68, { expected_name( forward_references[ref][FR_TYPE] ),
			expected_name( tok[T_ID] ) } ) 
end procedure

function find_reference( sequence fr )
	
	sequence name = fr[FR_NAME]
	integer file  = fr[FR_FILE]
	
	integer ns_file = -1
	integer ix = find( ':', name )
	if ix then
		sequence ns = name[1..ix-1]
		token ns_tok = keyfind( ns, ns_file, file, 1, fr[FR_HASHVAL] )
		if ns_tok[T_ID] != NAMESPACE then
			return ns_tok
		end if
	else
		ns_file = fr[FR_QUALIFIED]
	end if
	
	No_new_entry = 1
	token tok = keyfind( name, ns_file, file, , fr[FR_HASHVAL] )
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


-- TRUE if ref is a forward reference encoded as a negative number.
export type forward_reference( integer ref )
	if 0 > ref and ref >= -length( forward_references ) then
		ref = -ref
		if integer(forward_references[ref][FR_FILE]) and
			integer(forward_references[ref][FR_PC]) then
				return 1
		else
			return 0
		end if
	else
		return 0
	end if
end type

export function new_forward_reference( integer fwd_op, symtab_index sym, integer op = fwd_op  )
	integer 
		ref, 
		len = length( inactive_references )
	
	if len then
		ref = inactive_references[len]
		inactive_references = remove( inactive_references, len, len )
	else
		forward_references &= 0
		ref = length( forward_references )
	end if
	forward_references[ref] = repeat( 0, FR_SIZE )
	
	forward_references[ref][FR_TYPE]      = fwd_op
	if sym < 0 then
		forward_references[ref][FR_NAME] = forward_references[-sym][FR_NAME]
		forward_references[ref][FR_HASHVAL] = forward_references[-sym][FR_HASHVAL]
	else
		forward_references[ref][FR_NAME] = SymTab[sym][S_NAME]
		integer hashval = SymTab[sym][S_HASHVAL]
		if 0 = hashval then
			forward_references[ref][FR_HASHVAL] = hashfn( forward_references[ref][FR_NAME] )
		else
			forward_references[ref][FR_HASHVAL] = hashval
			remove_symbol( sym )
		end if
		
	end if
	
	forward_references[ref][FR_FILE]      = current_file_no
	forward_references[ref][FR_SUBPROG]   = CurrentSub
	
	if fwd_op != TYPE then
		forward_references[ref][FR_PC]        = length( Code ) + 1
	end if
	
	forward_references[ref][FR_LINE]      = fwd_line_number
	forward_references[ref][FR_THISLINE]  = ForwardLine
	forward_references[ref][FR_BP]        = forward_bp
	forward_references[ref][FR_QUALIFIED] = get_qualified_fwd()
	forward_references[ref][FR_OP]        = op
	
	if op = GOTO then
		forward_references[ref][FR_DATA] = { sym }
	end if
	
	-- If we're recording tokens (for a default parameter), this ref will never 
	-- get resolved.  So ignore it for now, and when someone actually calls
	-- the routine, it will be resolved normally then.
	if  Parser_mode != PAM_RECORD then
		if CurrentSub = TopLevelSub then
			if length( toplevel_references ) < current_file_no then
				toplevel_references &= repeat( {}, current_file_no - length( toplevel_references ) )
			end if
			toplevel_references[current_file_no] &= ref
		else
			if length( active_references ) < current_file_no then
				active_references &= repeat( {}, current_file_no - length( active_references ) )
				active_subprogs   &= repeat( {}, current_file_no - length( active_subprogs ) )
			end if
			integer sp = find( CurrentSub, active_subprogs[current_file_no] )
			if not sp then
				active_subprogs[current_file_no] &= CurrentSub
				sp = length( active_subprogs[current_file_no] )
				
				active_references[current_file_no] = append( active_references[current_file_no], {} )
			end if
			active_references[current_file_no][sp] &= ref
		end if
		fwdref_count += 1
	end if
	
	return ref
end function

function resolve_file( sequence refs, integer report_errors, integer unincluded_ok )
	
	sequence errors = {}
	for ar = length( refs ) to 1 by -1 do
		integer ref = refs[ar]
		
		sequence fr = forward_references[ref]
		if include_matrix[fr[FR_FILE]][current_file_no] = NOT_INCLUDED and not unincluded_ok then
			continue
		end if
		token tok = find_reference( fr )
		if tok[T_ID] = IGNORED then
			errors &= ref
			continue
		end if
		
		-- found a match...
		integer code_sub = fr[FR_SUBPROG]
		integer fr_type  = fr[FR_TYPE]
		integer sym_tok
		
		switch fr_type label "fr_type" do
			case PROC, FUNC then
				
				sym_tok = SymTab[tok[T_SYM]][S_TOKEN]
				if sym_tok = TYPE then
					sym_tok = FUNC
				end if
				if sym_tok != fr_type then
					if sym_tok != FUNC and fr_type != PROC then
						forward_error( tok, ref )
					end if
				end if
				switch sym_tok do
					case PROC, FUNC then
						patch_forward_call( tok, ref )
						break "fr_type"
												
					case else
						forward_error( tok, ref )
						
				end switch
				
			case VARIABLE then
				sym_tok = SymTab[tok[T_SYM]][S_TOKEN]
				if SymTab[tok[T_SYM]][S_SCOPE] = SC_UNDEFINED then
					errors &= ref
					continue
				end if
				switch sym_tok do
					case CONSTANT, ENUM, VARIABLE then
						patch_forward_variable( tok, ref )
						break "fr_type"
					case else
						forward_error( tok, ref )
				end switch

			case TYPE_CHECK then
				patch_forward_type_check( tok, ref )
			
			case GLOBAL_INIT_CHECK then
				patch_forward_init_check( tok, ref )
			
			case CASE then
				patch_forward_case( tok, ref )
				
			case TYPE then
				patch_forward_type( tok, ref )
			
			case GOTO then
				patch_forward_goto( tok, ref )
				
			case else
				-- ?? what is it?
				InternalErr( 263, {fr[FR_TYPE], fr[FR_NAME]})
		end switch
		if report_errors and sequence( forward_references[ref] ) then
			errors &= ref
		end if
		
	end for
	return errors
end function

export procedure Resolve_forward_references( integer report_errors = 0 )
	sequence errors = {}
	integer unincluded_ok = get_resolve_unincluded_globals()
	
	if length( active_references ) < length( known_files ) then
		active_references &= repeat( {}, length( known_files ) - length( active_references ) )
		active_subprogs   &= repeat( {}, length( known_files ) - length( active_subprogs ) )
	end if
	
	if length( toplevel_references ) < length( known_files ) then
		toplevel_references &= repeat( {}, length( known_files ) - length( toplevel_references ) )
	end if
	
	for i = 1 to length( active_subprogs ) do
		if (length( active_subprogs[i] ) or length(toplevel_references[i])) 
		and (i = current_file_no or finished_files[i] or unincluded_ok)
		then
			
			for j = length( active_references[i] ) to 1 by -1 do
				errors &= resolve_file( active_references[i][j], report_errors, unincluded_ok )
			end for
			errors &= resolve_file( toplevel_references[i], report_errors, unincluded_ok )
		end if
	end for
		
	if report_errors and length( errors ) then
		sequence msg = ""
		sequence errloc
		
		for e = length(errors) to 1 by -1 do
			sequence ref = forward_references[errors[e]]
			if (ref[FR_TYPE] = TYPE_CHECK and ref[FR_OP] = TYPE_CHECK) or ref[FR_TYPE] = GLOBAL_INIT_CHECK then
				-- these checks end up looking like duplicate errors
				continue

			else
				errloc = sprintf("\t%s (%d): %s\n", {abbreviate_path(known_files[ref[FR_FILE]]), ref[FR_LINE], ref[FR_NAME]} )
				if not match(errloc, msg) then
					msg &= errloc
					prep_forward_error( errors[e] )
				end if
			end if
			ThisLine    = ref[FR_THISLINE]
			bp          = ref[FR_BP]
			CurrentSub  = ref[FR_SUBPROG]
			line_number = ref[FR_LINE]
		end for
		if length(msg) > 0 then
			CompileErr( 74, {msg} )
		end if
	elsif report_errors then
		-- free up some space
		forward_references  = {}
		active_references   = {}
		toplevel_references = {}
		inactive_references = {}
	end if
	clear_last()
end procedure

procedure shift_these( sequence refs, integer pc, integer amount )
	for i = length( refs ) to 1 by -1 do
		sequence fr = forward_references[refs[i]]
		forward_references[refs[i]] = 0
		if fr[FR_SUBPROG] = shifting_sub then
			if fr[FR_PC] >= pc then
				fr[FR_PC] += amount
				if fr[FR_TYPE] = CASE
				and fr[FR_DATA] >= pc then
					-- the FR_DATA info tracks the pc for the switch statement for the case
					fr[FR_DATA] += amount
				end if
			end if
		end if
		forward_references[refs[i]] = fr
	end for
end procedure

-- duplicates the above, but we don't need to compare subprogs
procedure shift_top( sequence refs, integer pc, integer amount )
	for i = length( refs ) to 1 by -1 do
		sequence fr = forward_references[refs[i]]
		forward_references[refs[i]] = 0
		if fr[FR_PC] >= pc then
-- 			if fr[FR_PC] > 1 then
				if fr[FR_PC] = -amount then
					? Code
					? fr
				end if
				fr[FR_PC] += amount
				if fr[FR_TYPE] = CASE
				and fr[FR_DATA] >= pc then
					-- the FR_DATA info tracks the pc for the switch statement for the case
					fr[FR_DATA] += amount
				end if
-- 			end if
		end if
		forward_references[refs[i]] = fr
	end for
end procedure

export procedure shift_fwd_refs( integer pc, integer amount )
	if not shifting_sub then
		return
	end if
	
	if shifting_sub = TopLevelSub then
		for file = 1 to length( toplevel_references ) do
			shift_top( toplevel_references[file], pc, amount )
		end for
	else
		integer file = SymTab[shifting_sub][S_FILE_NO]
		integer sp   = find( shifting_sub, active_subprogs[file] )
		shift_these( active_references[file][sp], pc, amount )
	end if
end procedure
