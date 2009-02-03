include std/unittest.e

test_equal( "non-include global type resolution", UDT(0), 1 )
test_equal( "non-include global constant", FORWARD_GLOBAL, 1 )
test_equal( "dollar sign on non-include global constant", 'g', FORWARD_GLOBAL_SEQUENCE[$] )

forward_global_sequence[$] = 'z'
test_equal( "dollar sign assign on non-include global constant", 'z', forward_global_sequence[$] )
ifdef EC then
fwd_object = 0
test_equal( "non-include global variable survives translation", 0, fwd_object )
end ifdef



with type_check
UDT u
u = 0
test_pass( "forward UDT type check doesn't hang execution" )

export procedure check_unincluded_type( sloppy s )
	if not sloppy(s) then
		puts(1,"")
	end if
end procedure
with inline 50
procedure no_fwd_param_inlined( sequence o )
	test_true( "no fwd param inlined", sequence(o))
end procedure
no_fwd_param_inlined( FORWARD_GLOBAL_SEQUENCE )
