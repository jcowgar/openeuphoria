namespace decl
constant cmd = command_line()

include std/unittest.e
include std/error.e

with warning {short_circuit}

integer n=3,n0
sequence s0="Useless code"

function f(sequence s="abcd")
	if n<0 then ?0 end if
	return length(s)
end function

if n and f()=7 then end if

with warning &= {not_used, custom}

function foo()
	integer n = decl:n + f()
	return n
end function

test_equal("Assign on declare 1",s0,"Useless code")
test_equal("Assign on declare 1",n,3)
test_equal("Use default params in initial value", 7, foo())
warning("Useless code")

without warning &= (short_circuit)
if n and f()=7 then end if

ifdef EUI then
	warning_file("warning.lst")
end ifdef
integer n1
procedure bar()
	integer nha = 2
	nha+=1
	n1=nha
end procedure
bar()
test_equal("assign_op after assign on declare",3,n1)

test_report()
