include std/unittest.e

with define FOO

integer foo = 0
ifdef FOO then
	integer bar = 0
	for i = 1 to 3 do
		switch i with fallthru do
			case 1 then
			case 2 then
			case else
				bar = i
		end switch
	end for
	foo = 1
elsedef

end ifdef

test_equal( "ifdef recognizes 'case else'", 1, foo )

test_report()
