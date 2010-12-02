include std/unittest.e

without warning
function append(object a, object b)
	return {}
end function

with warning
test_equal("override #1", {}, append({1,2,3}, 4))
test_equal("eu:append", {1,2,3,4}, eu:append({1,2,3}, 4))
test_not_equal("override routine_id #1", routine_id("append"), -1 )
test_equal("routine_id(\"eu:append\")", routine_id("eu:id"), -1 )

include foo_default.e
include bar_default.e as bar
test_equal( "default namespace", "foo", foo:test() )
test_equal( "override default namespace", "bar", bar:test() )

include foo_export.e
test_equal( "public function", "foo", export_test() )
test_equal( "public constant", "foo", EXPORT_CONSTANT )
test_not_equal( "public routine id", -1, routine_id("export_test"))
test_equal( "public include",  "baz", baz() )
test_not_equal( "routine id public visible through public include", -1, routine_id("baz") )
test_equal( "routine id export not visible through public include", -1, routine_id("baz_export") )

include def_ns.e

def_ns dn = {}
def_ns:def_ns dn2 = public_ns:foo()

test_equal( "type clash with default namespace", "", dn )
test_equal( "using a default namespace through a 'public include'", "public_ns:foo", dn2 )

include case_file.e

sequence cf = repeat( 0, 2 )
for i = 1 to 2 do
	switch i with fallthru do
		case CASE_FILE:CASE_1 then
			cf[i] = CASE_FILE:CASE_2
			break
		case CASE_FILE:CASE_2 then
			cf[i] = CASE_FILE:CASE_1
		case else
			-- deliberate no case-else used.
	end switch
end for
test_equal( "switch with cases that use namespace", {2,1}, cf )

include use_default.e
test_equal( "default namespaces usable from file other than first to include", "foo", use_default() )

test_report()

