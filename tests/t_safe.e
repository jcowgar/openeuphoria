
with define SAFE
include std/machine.e
include std/safe.e
without define SAFE
include std/unittest.e

with define SAFE
edges_only = 0

atom addr
addr = allocate_protect( {1,2,3,4}, 1, PAGE_NONE )

if addr != 0 then
	test_pass("PAGE_NONE memory was allocated by allocate_protect")
	test_false("PAGE_NONE memory readable", safe_address(addr, 4, A_READ))
	test_false("PAGE_NONE memory writable", safe_address(addr, 4, A_WRITE))
	test_false("PAGE_NONE memory executable", safe_address( addr, 4, A_EXECUTE ))
	free_code(addr, 4)
else
	test_fail("PAGE_NONE memory could not be allocated by allocate_protect")
end if

addr = allocate_protect( {1,2,3,4}, 1, PAGE_READ )

if addr != 0 then
	test_pass("PAGE_READ memory was allocated by allocate_protect")
	test_true("PAGE_READ memory readable", safe_address(addr, 4, A_READ))
	test_false("PAGE_READ memory writable", safe_address(addr, 4, A_WRITE))
	test_false("PAGE_READ memory executable", safe_address( addr, 4, A_EXECUTE ))
else	
	test_fail("PAGE_READ memory could not be allocated by allocate_protect")
end if

addr = allocate_protect( {1,2,3,4}, 1, PAGE_READ_WRITE )

if addr != 0 then
	test_pass("PAGE_READ_WRITE memory was allocated by allocate_protect")
	test_true("PAGE_READ_WRITE memory readable", safe_address(addr, 4, A_READ))
	test_true("PAGE_READ_WRITE memory writable", safe_address(addr, 4, A_WRITE))
	test_false("PAGE_READ_WRITE memory executable", safe_address( addr, 4, A_EXECUTE ))
else
	test_fail("PAGE_READ_WRITE memory could not be allocated by allocate_protect")
end if

addr = allocate_protect( {1,2,3,4}, 1, PAGE_READ_WRITE_EXECUTE )

if addr != 0 then
	test_pass("PAGE_READ_WRITE_EXECUTE memory was allocated by allocate_protect")
	test_true("PAGE_READ_WRITE_EXECUTE memory readable", safe_address(addr, 4, A_READ))
	test_true("PAGE_READ_WRITE_EXECUTE memory writable", safe_address(addr, 4, A_WRITE))
	test_true("PAGE_READ_WRITE_EXECUTE memory executable", safe_address( addr, 4, A_EXECUTE ))
else
	test_fail("PAGE_READ_WRITE_EXECUTE memory could not be allocated by allocate_protect")
end if

addr = allocate_protect( {1,2,3,4}, 1, PAGE_READ_EXECUTE )

if addr != 0 then
	test_pass("PAGE_READ_EXECUTE memory was allocated by allocate_protect")
	test_true("PAGE_READ_EXECUTE memory readable", safe_address(addr, 4, A_READ))
	test_false("PAGE_READ_EXECUTE memory writable", safe_address(addr, 4, A_WRITE))
	test_true("PAGE_READ_EXECUTE memory executable", safe_address( addr, 4, A_EXECUTE ))
else
	test_fail("PAGE_READ_EXECUTE memory could not be allocated by allocate_protect")
end if



test_report()
