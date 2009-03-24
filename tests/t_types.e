include std/types.e
include std/unittest.e

-- boolean testes
test_true("boolean(1)", boolean(1))
test_true("boolean(0)", boolean(0))
test_true("boolean(FALSE)", boolean(FALSE))
test_true("boolean(TRUE)", boolean(TRUE))
test_false("boolean('1')", boolean('1'))
test_false("boolean('0')", boolean('0'))
test_false("boolean(\"TRUE\")",boolean("TRUE"))
test_false("boolean(\"FALSE\")",boolean("FALSE"))
test_false("boolean('a')", boolean('a'))
test_false("boolean(\"John\")", boolean("John"))
test_false("boolean({0,5})", boolean({0,5}))
test_false("boolean(-1)", boolean(-1))
test_false("boolean(1.234)", boolean(1.234))
test_false("boolean({1,2,\"abc\"})", boolean({1,2,"abc"}))
test_false("boolean({1, 2, 9.7})", boolean({1, 2, 9.7}))
test_false("boolean({})", boolean({}))

test_false("t_boolean(-1)", t_boolean(-1))
test_true ("t_boolean(0)", t_boolean(0))
test_true ("t_boolean(1)", t_boolean(1))
test_true ("t_boolean({1, 1, 0})", t_boolean({1, 1, 0}))
test_false("t_boolean({1, 1, 9.7})", t_boolean({1, 1, 9.7}))
test_false("t_boolean({})", t_boolean({}))

test_true("t_alnum() #1", t_alnum('a'))
test_true("t_alnum() #2", t_alnum('A'))
test_false("t_alnum() #3", t_alnum('-'))
test_false("t_alnum() #4", t_alnum('('))
test_true("t_alnum() #5", t_alnum('0'))
test_true("t_alnum() #6", t_alnum('8'))
test_false("t_alnum() #7", t_alnum("ab-!"))

test_true("t_alpha() #1", t_alpha('a'))
test_true("t_alpha() #2", t_alpha('Z'))
test_true("t_alpha() #3", t_alpha('b'))
test_true("t_alpha() #4", t_alpha('g'))
test_false("t_alpha() #5", t_alpha('-'))
test_false("t_alpha() #6", t_alpha('.'))
test_false("t_alpha() #7", t_alpha('0'))
test_false("t_alpha() #8", t_alpha('3'))
test_false("t_alpha() #9", t_alpha("ab9."))

test_true("t_ascii() #1", t_ascii('~'))
test_true("t_ascii() #2", t_ascii('a'))
test_false("t_ascii() #3", t_ascii(232))
test_false("t_ascii() #4", t_ascii({52, 99, 132, 232}))

test_true("t_cntrl() #1", t_cntrl(7))
test_false("t_cntrl() #2", t_cntrl('h'))
test_true("t_cntrl() #3", t_cntrl(30))
test_false("t_cntrl() #4", t_cntrl({7,18,'a', '8'}))

test_true("t_digit() #1", t_digit('3'))
test_false("t_digit() #2", t_digit(0))
test_false("t_digit() #3", t_digit('a'))
test_false("t_digit() #4", t_digit({'3', '9', 'z', 'g'}))

test_true("t_graph() #1", t_graph('A'))
test_false("t_graph() #2", t_graph(8))
test_false("t_graph() #3", t_graph(200))
test_false("t_graph() #3",  t_graph({'A', '4', 1, 253}))

test_true("t_lower() #1", t_lower('a'))
test_true("t_lower() #2", t_lower('z'))
test_false("t_lower() #3", t_lower('A'))
test_false("t_lower() #4", t_lower(13))
test_false("t_lower() #5", t_lower("joH9"))

test_true("t_print() #1", t_print('A'))
test_true("t_print() #2", t_print(' '))
test_false("t_print() #3", t_print(2))
test_false("t_print() #4", t_print(200))
test_false("t_print() #5", t_print({'a', '#', 7, 224}))

test_true("t_punct() #1", t_punct('.'))
test_true("t_punct() #2", t_punct('~'))
test_true("t_punct() #3", t_punct('!'))
test_true("t_punct() #4", t_punct('-'))
test_false("t_punct() #5", t_punct('a'))
test_false("t_punct() #6", t_punct('Z'))
test_false("t_punct() #7", t_punct({'!', '.', 'm', '9'}))

test_true("t_space() #1", t_space(' '))
test_false("t_space() #2", t_space('j'))
test_true("t_space() #3", t_space('\n'))
test_true("t_space() #4", t_space('\r'))
test_true("t_space() #5", t_space('\t'))
test_true("t_space() #6", t_space(11))
test_false("t_space() #7", t_space({' ', '\n', 'J', '4'}))

test_true("t_upper() #1", t_upper('A'))
test_true("t_upper() #2", t_upper('Z'))
test_false("t_upper() #3", t_upper('.'))
test_false("t_upper() #4", t_upper('a'))
test_false("t_upper() #5", t_upper({'D', 'Z', '$', '9'}))

test_true("t_xdigit() #1", t_xdigit('0'))
test_true("t_xdigit() #2", t_xdigit('9'))
test_true("t_xdigit() #3", t_xdigit('A'))
test_true("t_xdigit() #4", t_xdigit('a'))
test_true("t_xdigit() #5", t_xdigit('F'))
test_true("t_xdigit() #6", t_xdigit('f'))
test_false("t_xdigit() #7", t_xdigit('h'))
test_false("t_xdigit() #8", t_xdigit('z'))
test_false("t_xdigit() #9", t_xdigit({'0', 'F', '?', 't'}))


test_false("t_alnum(-1)", t_alnum(-1))
test_false("t_alnum(0)", t_alnum(0))
test_false("t_alnum(1)", t_alnum(1))
test_false("t_alnum(1.234)", t_alnum(1.234))
test_true("t_alnum('A')", t_alnum('A'))
test_true("t_alnum('9')", t_alnum('9'))
test_false("t_alnum('?')", t_alnum('?'))
test_true("t_alnum(\"abc\")", t_alnum("abc"))
test_true("t_alnum(\"ab3\")", t_alnum("ab3"))
test_false("t_alnum({1, 2, \"abc\"})", t_alnum({1, 2, "abc"}))
test_false("t_alnum({1, 2, 9.7})", t_alnum({1, 2, 9.7}))
test_false("t_alnum({})", t_alnum({}))
test_false("t_alnum(-1)", t_alnum(-1))
test_false("t_alpha(0)", t_alpha(0))
test_false("t_alpha(1)", t_alpha(1))
test_false("t_alpha(1.234)", t_alpha(1.234))
test_true("t_alpha('A')", t_alpha('A'))
test_false("t_alpha('9')", t_alpha('9'))
test_false("t_alpha('?')", t_alpha('?'))
test_true("t_alpha(\"abc\")", t_alpha("abc"))
test_false("t_alpha(\"ab3\")", t_alpha("ab3"))
test_false("t_alpha({1, 2, \"abc\"})", t_alpha({1, 2, "abc"}))
test_false("t_alpha({1, 2, 9.7})", t_alpha({1, 2, 9.7}))
test_false("t_alpha({})", t_alpha({}))
test_false("t_ascii(-1)", t_ascii(-1))
test_true("t_ascii(0)", t_ascii(0))
test_true("t_ascii(1)", t_ascii(1))
test_false("t_ascii(1.234)", t_ascii(1.234))
test_true("t_ascii('A')", t_ascii('A'))
test_true("t_ascii('9')", t_ascii('9'))
test_true("t_ascii('?')", t_ascii('?'))
test_true("t_ascii(\"abc\")", t_ascii("abc"))
test_true("t_ascii(\"ab3\")", t_ascii("ab3"))
test_false("t_ascii({1, 2, \"abc\"})", t_ascii({1, 2, "abc"}))
test_false("t_ascii({1, 2, 9.7})", t_ascii({1, 2, 9.7}))
test_false("t_ascii({})", t_ascii({}))
test_false("t_cntrl(-1)", t_cntrl(-1))
test_true("t_cntrl(0)", t_cntrl(0))
test_true("t_cntrl(1)", t_cntrl(1))
test_false("t_cntrl(1.234)", t_cntrl(1.234))
test_false("t_cntrl('A')", t_cntrl('A'))
test_false("t_cntrl('9')", t_cntrl('9'))
test_false("t_cntrl('?')", t_cntrl('?'))
test_false("t_cntrl(\"abc\")", t_cntrl("abc"))
test_false("t_cntrl(\"ab3\")", t_cntrl("ab3"))
test_false("t_cntrl({1, 2, \"abc\"})", t_cntrl({1, 2, "abc"}))
test_false("t_cntrl({1, 2, 9.7})", t_cntrl({1, 2, 9.7}))
test_false("t_cntrl({1, 2, 'a'})", t_cntrl({1, 2, 'a'}))
test_false("t_cntrl({})", t_cntrl({}))
test_false("t_digit(-1)", t_digit(-1))
test_false("t_digit(0)", t_digit(0))
test_false("t_digit(1)", t_digit(1))
test_false("t_digit(1.234)", t_digit(1.234))
test_false("t_digit('A')", t_digit('A'))
test_true("t_digit('9')", t_digit('9'))
test_false("t_digit('?')", t_digit('?'))
test_false("t_digit(\"abc\")", t_digit("abc"))
test_false("t_digit(\"ab3\")", t_digit("ab3"))
test_true("t_digit(\"123\")", t_digit("123"))
test_false("t_digit({1, 2, \"abc\"})", t_digit({1, 2, "abc"}))
test_false("t_digit({1, 2, 9.7})", t_digit({1, 2, 9.7}))
test_false("t_digit({1, 2, 'a'})", t_digit({1, 2, 'a'}))
test_false("t_digit({})", t_digit({}))
test_false("t_graph(-1)", t_graph(-1))
test_false("t_graph(0)", t_graph(0))
test_false("t_graph(1)", t_graph(1))
test_false("t_graph(1.234)", t_graph(1.234))
test_true("t_graph('A')", t_graph('A'))
test_true("t_graph('9')", t_graph('9'))
test_true("t_graph('?')", t_graph('?'))
test_false("t_graph(' ')", t_graph(' '))
test_true("t_graph(\"abc\")", t_graph("abc"))
test_true("t_graph(\"ab3\")", t_graph("ab3"))
test_true("t_graph(\"123\")", t_graph("123"))
test_false("t_graph({1, 2, \"abc\"})", t_graph({1, 2, "abc"}))
test_false("t_graph({1, 2, 9.7})", t_graph({1, 2, 9.7}))
test_false("t_graph({1, 2, 'a'})", t_graph({1, 2, 'a'}))
test_false("t_graph({})", t_graph({}))
test_false("t_lower(-1)", t_lower(-1))
test_false("t_lower(0)", t_lower(0))
test_false("t_lower(1)", t_lower(1))
test_false("t_lower(1.234)", t_lower(1.234))
test_false("t_lower('A')", t_lower('A'))
test_false("t_lower('9')", t_lower('9'))
test_false("t_lower('?')", t_lower('?'))
test_true("t_lower(\"abc\")", t_lower("abc"))
test_false("t_lower(\"ab3\")", t_lower("ab3"))
test_false("t_lower(\"123\")", t_lower("123"))
test_false("t_lower({1, 2, \"abc\"})", t_lower({1, 2, "abc"}))
test_false("t_lower({1, 2, 9.7})", t_lower({1, 2, 9.7}))
test_false("t_lower({1, 2, 'a'})", t_lower({1, 2, 'a'}))
test_false("t_lower({})", t_lower({}))
test_false("t_print(-1)", t_print(-1))
test_false("t_print(0)", t_print(0))
test_false("t_print(1)", t_print(1))
test_false("t_print(1.234)", t_print(1.234))
test_true("t_print('A')", t_print('A'))
test_true("t_print('9')", t_print('9'))
test_true("t_print('?')", t_print('?'))
test_true("t_print(\"abc\")", t_print("abc"))
test_true("t_print(\"ab3\")", t_print("ab3"))
test_true("t_print(\"123\")", t_print("123"))
test_false("t_print({1, 2, \"abc\"})", t_print({1, 2, "abc"}))
test_false("t_print({1, 2, 9.7})", t_print({1, 2, 9.7}))
test_false("t_print({1, 2, 'a'})", t_print({1, 2, 'a'}))
test_false("t_print({})", t_print({}))
test_false("t_punct(-1)", t_punct(-1))
test_false("t_punct(0)", t_punct(0))
test_false("t_punct(1)", t_punct(1))
test_false("t_punct(1.234)", t_punct(1.234))
test_false("t_punct('A')", t_punct('A'))
test_false("t_punct('9')", t_punct('9'))
test_true("t_punct('?')", t_punct('?'))
test_false("t_punct(\"abc\")", t_punct("abc"))
test_true("t_punct(\"(-)\")", t_punct("(-)"))
test_false("t_punct(\"123\")", t_punct("123"))
test_false("t_punct({1, 2, \"abc\"})", t_punct({1, 2, "abc"}))
test_false("t_punct({1, 2, 9.7})", t_punct({1, 2, 9.7}))
test_false("t_punct({1, 2, 'a'})", t_punct({1, 2, 'a'}))
test_false("t_punct({})", t_punct({}))
test_false("t_space(-1)", t_space(-1))
test_false("t_space(0)", t_space(0))
test_false("t_space(1)", t_space(1))
test_false("t_space(1.234)", t_space(1.234))
test_false("t_space('A')", t_space('A'))
test_false("t_space('9')", t_space('9'))
test_true("t_space('\t')", t_space('\t'))
test_false("t_space(\"abc\")", t_space("abc"))
test_false("t_space(\"123\")", t_space("123"))
test_false("t_space({1, 2, \"abc\"})", t_space({1, 2, "abc"}))
test_false("t_space({1, 2, 9.7})", t_space({1, 2, 9.7}))
test_false("t_space({1, 2, 'a'})", t_space({1, 2, 'a'}))
test_false("t_space({})", t_space({}))
test_false("t_upper(-1)", t_upper(-1))
test_false("t_upper(0)", t_upper(0))
test_false("t_upper(1)", t_upper(1))
test_false("t_upper(1.234)", t_upper(1.234))
test_true("t_upper('A')", t_upper('A'))
test_false("t_upper('9')", t_upper('9'))
test_false("t_upper('?')", t_upper('?'))
test_false("t_upper(\"abc\")", t_upper("abc"))
test_true("t_upper(\"ABC\")", t_upper("ABC"))
test_false("t_upper(\"123\")", t_upper("123"))
test_false("t_upper({1, 2, \"abc\"})", t_upper({1, 2, "abc"}))
test_false("t_upper({1, 2, 9.7})", t_upper({1, 2, 9.7}))
test_false("t_upper({1, 2, 'a'})", t_upper({1, 2, 'a'}))
test_false("t_upper({})", t_upper({}))
test_false("t_xdigit(-1)", t_xdigit(-1))
test_false("t_xdigit(0)", t_xdigit(0))
test_false("t_xdigit(1)", t_xdigit(1))
test_false("t_xdigit(1.234)", t_xdigit(1.234))
test_true("t_xdigit('A')", t_xdigit('A'))
test_true("t_xdigit('9')", t_xdigit('9'))
test_false("t_xdigit('?')", t_xdigit('?'))
test_true("t_xdigit(\"abc\")", t_xdigit("abc"))
test_false("t_xdigit(\"fgh\")", t_xdigit("fgh"))
test_true("t_xdigit(\"123\")", t_xdigit("123"))
test_false("t_xdigit({1, 2, \"abc\"})", t_xdigit({1, 2, "abc"}))
test_false("t_xdigit({1, 2, 9.7})", t_xdigit({1, 2, 9.7}))
test_false("t_xdigit({1, 2, 'a'})", t_xdigit({1, 2, 'a'}))
test_false("t_xdigit({})", t_xdigit({}))
test_false("t_vowel(-1)", t_vowel(-1))
test_false("t_vowel(0)", t_vowel(0))
test_false("t_vowel(1)", t_vowel(1))
test_false("t_vowel(1.234)", t_vowel(1.234))
test_true("t_vowel('A')", t_vowel('A'))
test_false("t_vowel('9')", t_vowel('9'))
test_false("t_vowel('?')", t_vowel('?'))
test_false("t_vowel(\"abc\")", t_vowel("abc"))
test_true("t_vowel(\"aiu\")", t_vowel("aiu"))
test_false("t_vowel(\"123\")", t_vowel("123"))
test_false("t_vowel({1, 2, \"abc\"})", t_vowel({1, 2, "abc"}))
test_false("t_vowel({1, 2, 9.7})", t_vowel({1, 2, 9.7}))
test_false("t_vowel({1, 2, 'a'})", t_vowel({1, 2, 'a'}))
test_false("t_vowel({})", t_vowel({}))
test_false("t_consonant(-1)", t_consonant(-1))
test_false("t_consonant(0)", t_consonant(0))
test_false("t_consonant(1)", t_consonant(1))
test_false("t_consonant(1.234)", t_consonant(1.234))
test_false("t_consonant('A')", t_consonant('A'))
test_false("t_consonant('9')", t_consonant('9'))
test_false("t_consonant('?')", t_consonant('?'))
test_false("t_consonant(\"abc\")", t_consonant("abc"))
test_true("t_consonant(\"rTfM\")", t_consonant("rTfM"))
test_false("t_consonant(\"123\")", t_consonant("123"))
test_false("t_consonant({1, 2, \"abc\"})", t_consonant({1, 2, "abc"}))
test_false("t_consonant({1, 2, 9.7})", t_consonant({1, 2, 9.7}))
test_false("t_consonant({1, 2, 'a'})", t_consonant({1, 2, 'a'}))
test_false("t_consonant({})", t_consonant({}))

test_true("char_test(\"ABCD\", {{'A', 'D'}})", char_test("ABCD", {{'A', 'D'}}))
test_false("char_test(\"ABCD\", {{'A', 'C'}})", char_test("ABCD", {{'A', 'C'}}))
test_true("char_test(\"Harry\", {{'a', 'z'}, {'D', 'J'}})", char_test("Harry", {{'a', 'z'}, {'D', 'J'}}))
test_false("char_test(\"Potter\", \"novel\")", char_test("Potter", "novel"))

test_false("t_bytearray(-1)", t_bytearray(-1))
test_true("t_bytearray(0)", t_bytearray(0))
test_true("t_bytearray(1)", t_bytearray(1))
test_true("t_bytearray(10)", t_bytearray(10))
test_true("t_bytearray(100)", t_bytearray(100))
test_false("t_bytearray(1000)", t_bytearray(1000))
test_false("t_bytearray(1.234)", t_bytearray(1.234))
test_true("t_bytearray('A')", t_bytearray('A'))
test_true("t_bytearray('9')", t_bytearray('9'))
test_true("t_bytearray('?')", t_bytearray('?'))
test_true("t_bytearray(' ')", t_bytearray(' '))
test_true("t_bytearray(\"abc\")", t_bytearray("abc"))
test_true("t_bytearray(\"ab3\")", t_bytearray("ab3"))
test_true("t_bytearray(\"123\")", t_bytearray("123"))
test_false("t_bytearray({1, 2, \"abc\"})", t_bytearray({1, 2, "abc"}))
test_false("t_bytearray({1, 2, 9.7)", t_bytearray({1, 2, 9.7}))
test_true("t_bytearray({1, 2, 'a')", t_bytearray({1, 2, 'a'}))
test_false("t_bytearray({})", t_bytearray({}))

test_true("t_identifier(abc)", t_identifier("abc"))
test_true("t_identifier(ABC)", t_identifier("ABC"))
test_true("t_identifier(_abc)", t_identifier("_abc"))
test_true("t_identifier(_)", t_identifier("_"))
test_true("t_identifier(ab_c)", t_identifier("ab_c"))
test_true("t_identifier(abc_)", t_identifier("abc_"))
test_false("t_identifier(1abc)", t_identifier("1abc"))
test_false("t_identifier(1)", t_identifier("1"))
test_false("t_identifier(1293)", t_identifier("1293"))
test_false("t_identifier(1_)", t_identifier("1_"))

sequence dc
dc = get_charsets()
test_equal("get_charsets", CS_LAST-1, length(dc) )
test_true("Default WS", t_space(" \t\n\r"))
set_charsets({{CS_Whitespace, " \t" & 5}})
test_false("Altered WS #1", t_space(" \t\n\r"))
test_true("Altered WS #2", t_space(5 & "\t "))
set_charsets(dc)
test_true("Default WS", t_space(" \t\n\r"))
test_false("Altered WS #3", t_space(5 & "\t "))

test_true("Spec Word #1", t_specword('_'))
test_false("Spec Word #2", t_specword('$'))
set_charsets({{CS_SpecWord, "_-#$%"}})
test_true("Spec Word #3", t_specword('$'))

test_report()
