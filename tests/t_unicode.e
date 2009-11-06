include std/unittest.e
include std/unicode.e

wstring s1, s2, s3
s1 = "abcd"
s2 = ""
s3 = {#FFFF, #0001, #1000, #8080}

test_equal("peek_wstring and allocate_wstring#1", s1, peek_wstring(allocate_wstring(s1)))
test_equal("peek_wstring and allocate_wstring#2", s2, peek_wstring(allocate_wstring(s2)))
test_equal("peek_wstring and allocate_wstring#3", s3, peek_wstring(allocate_wstring(s3)))


-- type tests
object a1, a2, a3, a4, a5, a6, a7
a1 = "this is ascii string \t \n \r " & #FF & #00
a2 = 123
a3 = {{"not", "string", 999}}
a4 = "this is unicode string " & #100
a5 = "this is unicode string " & #FFFF
a6 = "this is not unicode string " & #10000
a7 = "this is not unicode string " & #FFFFFFFF

test_equal("astring type#1", 1, astring(a1))
test_equal("astring type#2", 0, astring(a2))
test_equal("astring type#3", 0, astring(a3))
test_equal("astring type#4", 0, astring(a4))
test_equal("astring type#5", 0, astring(a5))

test_equal("wstring type#1", 1, wstring(a1))
test_equal("wstring type#2", 0, wstring(a2))
test_equal("wstring type#3", 0, wstring(a3))
test_equal("wstring type#4", 1, wstring(a4))
test_equal("wstring type#5", 1, wstring(a5))
test_equal("wstring type#6", 0, wstring(a6))
test_equal("wstring type#7", 0, wstring(a7))


-- utf8 tests -- taken from rfc 2279

wstring e1, e2, e3
astring f1, f2, f3

e1 = {#0041, #2262, #0391, #002E} -- "A<NOT IDENTICAL TO><ALPHA>."
e2 = {#D55C, #AD6D, #C5B4} -- "hangugo" in Hangul
e3 = {#65E5, #672C, #8A9E} -- "nihongo" in Kanji

f1 = utf8_encode(e1)
f2 = utf8_encode(e2)
f3 = utf8_encode(e3)

test_equal("utf8_encode#1", {#41, #E2, #89, #A2, #CE, #91, #2E}, f1)
test_equal("utf8_encode#2", {#ED, #95, #9C, #EA, #B5, #AD, #EC, #96, #B4}, f2)
test_equal("utf8_encode#3", {#E6, #97, #A5, #E6, #9C, #AC, #E8, #AA, #9E}, f3)

test_equal("utf8_decode#1", e1, utf8_decode({#41, #E2, #89, #A2, #CE, #91, #2E}))
test_equal("utf8_decode#2", e2, utf8_decode({#ED, #95, #9C, #EA, #B5, #AD, #EC, #96, #B4}))
test_equal("utf8_decode#3", e3, utf8_decode({#E6, #97, #A5, #E6, #9C, #AC, #E8, #AA, #9E}))


test_true(`isUChar('a')`, isUChar('a'))
test_false(`isUChar(0x1FFFFF)`, isUChar(0x1FFFFF))
test_true(`isUChar(0xFFFF)`, isUChar(0xFFFF))
test_false(`isUChar(0xFFFF, strict)`, isUChar(0xFFFF, 1))
test_true(`isUChar(0x1FFFF)`, isUChar(0x1FFFF))
test_false(`isUChar(0x1FFFF, strict)`, isUChar(0x1FFFF, 1))

procedure ut1()
	object c
	
	sequence s = x"7a C2A9 E6B0B4 F09d849e"
	c = get_char(s, 1, utf_8)
	test_equal("get_char utf_8 z", {'z', 2}, c)
	
	c = get_char(s, 2, utf_8)
	test_equal("get_char utf_8 copyright", {0xa9, 4}, c)

	c = get_char(s, 4, utf_8)
	test_equal("get_char utf_8 water", {0x6c34, 7}, c)

	c = get_char(s, 7, utf_8)
	test_equal("get_char utf_8 G-Clef", {0x1d11e, 11}, c)
	
	sequence s4 = {
	x"DFFF", -- Subsequent parts invalid
	x"E289", -- Sequence is missing
	x"EDBFBF", -- Not a valid UCS char (0xDFFF)
	x"F88080808A", -- 5 byte sequence
	x"FC808080808A", -- 6 byte sequence
	$
	}
	
	for j = 1 to length(s4) do
	    s4[j] = get_char(s4[j], 1)
	end for
	test_equal("get_char utf_8 5", {4, 3, 5, 2, 2}, s4)
end procedure
ut1()	

procedure ut2()
	object c
	sequence s
	
	s = u"7a 6c34 d834 dd1e"
	c = get_char(s, 1, utf_16)
	test_equal("get_char utf_16 z", {'z', 2}, c)
	
	c = get_char(s, 2, utf_16)
	test_equal("get_char utf_16 water", {0x6c34, 3}, c)

	c = get_char(s, 3, utf_16)
	test_equal("get_char utf_16 G-Clef", {0x1d11e, 5}, c)
	
	sequence s4 = {
	u"DFFF", -- Bad leader
	u"D828 D828", -- Bad trailer
	u"D828 ", -- Missing trailer
	u"D8FF DFFF", -- Not a valid UCS char (0x4FFFF)
	$
	}

	for j = 1 to length(s4) do
	    s4[j] = get_char(s4[j], 1, utf_16, 1) -- Use 'strict' option
	end for
	test_equal("get_char utf_16 5", {7,8,3,5}, s4)
	
end procedure
ut2()

procedure ut3()
	object c
	sequence s
	
	s = U"7a 6c34 1d11e"
	c = get_char(s, 1, utf_32)
	test_equal("get_char utf_32 z", {'z', 2}, c)
	
	c = get_char(s, 2, utf_32)
	test_equal("get_char utf_32 water", {0x6c34, 3}, c)

	c = get_char(s, 3, utf_32)
	test_equal("get_char utf_32 G-Clef", {0x1d11e, 4}, c)
	
	sequence s4 = {
	{-1}, -- Bad data item
	U"D8FF", -- Not a valid UCS char 
	U"4FFFF", -- Not a valid UCS char
	$
	}

	for j = 1 to length(s4) do
	    s4[j] = get_char(s4[j], 1, utf_32, 1) -- Use 'strict' option
	end for
	test_equal("get_char utf_16 5", {1,5,5}, s4)
	
end procedure
ut3()

test_equal("encode utf_8 z", x"7a", encode(0x7a, utf_8))
test_equal("encode utf_8 copyright", x"c2a9", encode(0xa9, utf_8))
test_equal("encode utf_8 water", x"e6b0b4", encode(0x6c34, utf_8))
test_equal("encode utf_8 G-Clef", x"f09d849e", encode(0x1d11e, utf_8))

test_equal("encode utf_16 z", u"7a", encode(0x7a, utf_16))
test_equal("encode utf_16 copyright", u"a9", encode(0xa9, utf_16))
test_equal("encode utf_16 water", u"6c34", encode(0x6c34, utf_16))
test_equal("encode utf_16 G-Clef", u"d834 dd1e", encode(0x1d11e, utf_16))

test_equal("encode utf_32 z", U"7a", encode(0x7a, utf_32))
test_equal("encode utf_32 copyright", U"a9", encode(0xa9, utf_32))
test_equal("encode utf_32 water", U"6c34", encode(0x6c34, utf_32))
test_equal("encode utf_32 G-Clef", U"1d11e", encode(0x1d11e, utf_32))

test_equal("code_length utf_8 z", 1, code_length(0x7a, utf_8))
test_equal("code_length utf_8 copyright", 2, code_length(0xa9, utf_8))
test_equal("code_length utf_8 water", 3, code_length(0x6c34, utf_8))
test_equal("code_length utf_8 G-Clef", 4, code_length(0x1d11e, utf_8))

test_equal("code_length utf_16 z", 1, code_length(0x7a, utf_16))
test_equal("code_length utf_16 copyright", 1, code_length(0xa9, utf_16))
test_equal("code_length utf_16 water", 1, code_length(0x6c34, utf_16))
test_equal("code_length utf_16 G-Clef", 2, code_length(0x1d11e, utf_16))

test_equal("code_length utf_32 z", 1, code_length(0x7a, utf_32))
test_equal("code_length utf_32 copyright", 1, code_length(0xa9, utf_32))
test_equal("code_length utf_32 water", 1, code_length(0x6c34, utf_32))
test_equal("code_length utf_32 G-Clef", 1, code_length(0x1d11e, utf_32))
	
test_equal("validate utf_8 1", 0, validate(x"7a C2A9 E6B0B4 F09d849e", utf_8))
test_equal("validate utf_8 2", 1, validate(x"dfff", utf_8))
test_equal("validate utf_8 3", 2, validate(x"7a E289", utf_8))
test_equal("validate utf_8 4", 3, validate(x"7a 7a EDBFBF", utf_8))
test_equal("validate utf_8 5", 4, validate(x"7a 7a 7a F88080808A", utf_8))
test_equal("validate utf_8 6", 5, validate(x"7a 7a 7a 7a FC808080808A", utf_8))

test_equal("validate utf_16 1", 0, validate(u"7a 6c34 d834 dd1e", utf_16))
test_equal("validate utf_16 2", 1, validate(u"dfff", utf_16))
test_equal("validate utf_16 3", 2, validate(u"7a d828 d828", utf_16))
test_equal("validate utf_16 4", 3, validate(u"7a 7a d828", utf_16))
test_equal("validate utf_16 5", 0, validate(u"7a 7a 7a d8ff dfff", utf_16, 0))
test_equal("validate utf_16 5", 4, validate(u"7a 7a 7a d8ff dfff", utf_16, 1))

test_equal("validate utf_32 1", 0, validate(U"7a A9 6c34 1d11e", utf_32))
test_equal("validate utf_32 2", 1, validate({-1}, utf_32))
test_equal("validate utf_32 3", 2, validate(U"7a D8FF", utf_32))
test_equal("validate utf_32 4", 0, validate(U"7a 7a 4FFFF", utf_32, 0))
test_equal("validate utf_32 4", 3, validate(U"7a 7a 4FFFF", utf_32, 1))

test_equal("utf8 to utf8",   x"7a C2A9 E6B0B4 F09d849e", toUTF(x"7a C2A9 E6B0B4 F09d849e", utf_8, utf_8))
test_equal("utf8 to utf16",  u"7a A9 6c34 d834 dd1e",    toUTF(x"7a C2A9 E6B0B4 F09d849e", utf_8, utf_16))
test_equal("utf8 to utf32",  U"7a A9 6c34 1d11e",        toUTF(x"7a C2A9 E6B0B4 F09d849e", utf_8, utf_32))

test_equal("utf16 to utf8",  x"7a C2A9 E6B0B4 F09d849e", toUTF(u"7a A9 6c34 d834 dd1e", utf_16, utf_8))
test_equal("utf16 to utf16", u"7a A9 6c34 d834 dd1e",    toUTF(u"7a A9 6c34 d834 dd1e", utf_16, utf_16))
test_equal("utf16 to utf32", U"7a A9 6c34 1d11e",        toUTF(u"7a A9 6c34 d834 dd1e", utf_16, utf_32))

test_equal("utf32 to utf8",  x"7a C2A9 E6B0B4 F09d849e", toUTF(U"7a A9 6c34 1d11e", utf_32, utf_8))
test_equal("utf32 to utf16", u"7a A9 6c34 d834 dd1e",    toUTF(U"7a A9 6c34 1d11e", utf_32, utf_16))
test_equal("utf32 to utf32", U"7a A9 6c34 1d11e",        toUTF(U"7a A9 6c34 1d11e", utf_32, utf_32))

sequence sc = x"7a C2A9 E6B0B4 F09d849e"
sequence sr 
sr = toUTF(sc, utf_8, utf_16)
sr = toUTF(sr, utf_16, utf_32)
sr = toUTF(sr, utf_32, utf_8)
test_equal("toUTF round trip", sc, sr)


test_report()

