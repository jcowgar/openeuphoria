include std/unittest.e
include std/pipeio.e as pipe
include std/filesys.e as fs
include std/sequence.e

sequence list, interpreter
list = command_line()
ifdef not EUI then
	-- The tests test are here to test interpreters and libraries as we do not know where the
	-- interpreter is we just quit.
	test_report()
	abort(0)
elsedef
	if compare(list[1],list[2]) != 0 then
		-- okay, let's trust the EC variable.
		interpreter = list[1]
	else
		-- It's most likely the EC variable was not defined when translating
		-- yet this is a translated application.
		interpreter = "eui"
	end if
end ifdef

object z = pipe:create()

object p = pipe:exec(interpreter & " "& stdseq:join({"..","demo","pipe_sub.ex"},fs:SLASH), z)
if atom(p) then
	test_fail("pipe:exec #1")
	abort(1)
end if

sequence message = "Hello from eutest!"
integer bytes = pipe:write(p[STDIN], message & "\n")
test_equal("pipe:write #1", length(message), bytes - 1)

object r = pipe:read(p[STDOUT], 256)
if atom(r) then
	test_fail("pipe:read")
else
	test_equal("pipe:read", sprintf("pipe_sub.ex: read from STDIN: '%s'", { message }), r)
end if

pipe:kill(p)

test_report()

