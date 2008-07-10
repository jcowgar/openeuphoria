include sequence.e as seq
include unittest.e

test_equal("reverse() integer sequence", {3,2,1}, reverse({1,2,3}))
test_equal("reverse() string", "nhoJ", reverse("John"))
test_equal("reverse() sub-string 1", "ayxwvutsrqponmlkjihgfedcbz", reverse("abcdefghijklmnopqrstuvwxyz", 2, -1))
test_equal("reverse() sub-string 2", "azyxwvutsrqponmlkjihgfedcb", reverse("abcdefghijklmnopqrstuvwxyz", 2, 0))
test_equal("reverse() sub-string 3", "yxwvutsrqponmlkjihgfedcbaz", reverse("abcdefghijklmnopqrstuvwxyz", 1, -1))
test_equal("reverse() even count", "fedcba", reverse("abcdef"))
test_equal("reverse() odd count", "edcba", reverse("abcde"))
test_equal("reverse() 2-elements", "ba", reverse("ab"))
test_equal("reverse() 1-elements", "a", reverse("a"))
test_equal("reverse() 0-elements", "", reverse(""))
test_equal("reverse() atom", 42, reverse(42))
test_equal("reverse() with sub-seq", {{-10,-200}, {5,6,7}, {1,2}}, reverse({{1,2}, {5,6,7}, {-10, -200}}))


test_equal("head() string default", "J", head("John Doe"))
test_equal("head() string", "John", head("John Doe", 4))
test_equal("head() sequence", {1,2,3}, head({1,2,3,4,5,6}, 3))
test_equal("head() nested sequence", {{1,2}, {3,4}}, head({{1,2},{3,4},{5,6}}, 2))
test_equal("head() bounds", "Name", head("Name", 50))

test_equal("mid() string", "Middle", mid("John Middle Doe", 6, 6))
test_equal("mid() sequence", {2,3,4}, mid({1,2,3,4,5,6}, 2, 3))
test_equal("mid() nested sequence", {{3,4},{5,6}}, mid({{1,2},{3,4},{5,6},{7,8}}, 2, 2))
test_equal("mid() bounds #1", {2,3}, mid({1,2,3}, 2, 50))
test_equal("mid() bounds #2",{1,2},mid({1,2,3},0,2))
test_equal("mid() bounds #3",{1,2},mid({1,2,3},1,-1))

test_equal("slice() string", "Middle", slice("John Middle Doe", 6, 11))
test_equal("slice() string, zero end", "Middle Doe", slice("John Middle Doe", 6, 0))
test_equal("slice() string, neg end", "Middle", slice("John Middle Doe", 6, -4))
test_equal("slice() sequence", {2,3}, slice({1,2,3,4}, 2, 3))
test_equal("slice() nested sequence", {{3,4},{5,6}}, slice({{1,2},{3,4},{5,6},{7,8}}, 2, 3))
test_equal("slice() bounds", "Middle Doe", slice("John Middle Doe", 6, 50))

test_equal("tail() string default", "ohn Middle Doe", tail("John Middle Doe"))
test_equal("tail() string", "Doe", tail("John Middle Doe", 3))
test_equal("tail() sequence", {3,4}, tail({1,2,3,4}, 2))
test_equal("tail() nested sequence", {{3,4},{5,6}}, tail({{1,2},{3,4},{5,6}}, 2))
test_equal("tail() bounds", {1,2,3,4}, tail({1,2,3,4}, 50))

test_equal("split() simple string", {"a","b","c"}, split("a,b,c", ","))
test_equal("split() sequence", {{1},{2},{3},{4}}, split({1,0,2,0,3,0,4}, 0))
test_equal("split() nested sequence", {{"John"}, {"Doe"}}, split({"John", 0, "Doe"}, 0))
test_equal("split() limit set", {"a", "b,c"}, split("a,b,c", ',', 2))
test_equal("split() any character", {"a", "b", "c"}, split("a,b.c", ",.", 0, 1))
test_equal("split() limit and any character", {"a", "b", "c|d"},
    split("a,b.c|d", ",.|", 3, 1))
test_equal("split() single sequence delimiter",{"while 1 "," end while ",""},
    split("while 1 do end while do","do"))

test_equal("join() simple string default", "a b c", join({"a", "b", "c"}))
test_equal("join() simple string", "a,b,c", join({"a", "b", "c"}, ","))
test_equal("join() nested sequence", {"John", 0, "Doe"}, join({{"John"}, {"Doe"}}, 0))

test_equal("remove() integer sequence", {1,3}, remove({1,2,3}, 2))
test_equal("remove() string", "Jon", remove("John", 3))
test_equal("remove() nested sequence", {{1,2}, {5,6}}, remove({{1,2},{3,4},{5,6}}, 2))
test_equal("remove() bounds", "John", remove("John", 55))

test_equal("remove() range integer sequence", {1,5}, remove({1,2,3,4,5}, 2, 4))
test_equal("remove() range string", "John Doe", remove("John M Doe", 5, 6))
test_equal("remove() range bounds #1", "John", remove("John Doe", 5, 100))
test_equal("remove() range bounds #2", "John Doe", remove("John Doe", 3, 1))
test_equal("remove() range bounds #3", "John Doe", remove("John Doe", -3, -1))
test_equal("remove() range bounds with floats", "n Doe", remove("John Doe", 1.5, 3))

test_equal("remove_all() 1", {2,3,4,3,2}, remove_all(1,{1,2,3,1,4,3,1,2,1}))
test_equal("remove_all() 2", "Ask what you can do for your country.", 
           remove_all('x',"xAxsk whxat you caxn do for yoxur countryx.x"))

test_equal("insert() integer sequence", {1,2,3}, insert({1,3}, 2, 2))
test_equal("insert() string", {'J','o',"h",'n'}, insert("Jon", "h", 3))

test_equal("splice() integer sequence", {1,2,3}, splice({1,3}, 2, 2))
test_equal("splice() string", "John", splice("Jon", "h", 3))

test_equal("replace() integer sequence", {1,2,3}, replace({1,8,9,3}, 2, 2, 3))
test_equal("replace() integer sequence w/sequence", {1,2,3,4},
    replace({1,8,9,4}, {2,3}, 2, 3))
test_equal("replace() string sequence", "John", replace("Jahn", 'o', 2))
test_equal("replace() string sequence 2", "Jane", replace("John", "ane", 2, 4))
test_equal("replace() 2,5 #3a", "/--ething         "
              , replace("//something         ", "--" , 2, 5))

test_equal("replace() 2,5 #3b", "/--eething         "
             , replace("//something         ", "--e", 2, 5))

--unittest crashing pretty.e:133 in procedure rPrint()
--subscript value 34 is out of bounds, reading from a sequence of length 33
test_equal("replace() 2,5 #3c", " --something         "
             , replace(" //something         ", "--", 2, 3))

test_equal("pad_head() #1", "   ABC", pad_head("ABC", 6))
test_equal("pad_head() #2", "ABC", pad_head("ABC", 3))
test_equal("pad_head() #3", "ABC", pad_head("ABC", 1))
test_equal("pad_head() #4", "...ABC", pad_head("ABC", 6, '.'))

test_equal("pad_tail() #1", "ABC   ", pad_tail("ABC", 6))
test_equal("pad_tail() #2", "ABC", pad_tail("ABC", 3))
test_equal("pad_tail() #3", "ABC", pad_tail("ABC", 1))
test_equal("pad_tail() #4", "ABC...", pad_tail("ABC", 6, '.'))

test_equal("chunk() sequence", {{1,2,3}, {4,5,6}}, chunk({1,2,3,4,5,6}, 3))
test_equal("chunk() string", {"AB", "CD", "EF"}, chunk("ABCDEF", 2))
test_equal("chunk() odd size", {"AB", "CD", "E"}, chunk("ABCDE", 2))

test_equal("flatten() nested", {1,2,3}, flatten({{1}, {2}, {3}}))
test_equal("flatten() deeply nested", {1,2,3}, flatten({{{{1}}}, 2, {{{{{3}}}}}}))
test_equal("flatten() string", "JohnDoe", flatten({{"John", {"Doe"}}}))

test_equal("vslice() #1", {1,2,3}, vslice({{5,1}, {5,2}, {5,3}}, 2))
test_equal("vslice() #2", {5,5,5}, vslice({{5,1}, {5,2}, {5,3}}, 1))

test_equal("can_add #1",0,can_add({{1,2},{3,4}},{5,6,7}))
test_equal("can_add #2",1,can_add({{1,2},{3,4}},{{5,6},7}))

test_equal("linear",{{1,5},{4,8},{7,11},{10,14}},linear({1,5},3,4))

sequence s
s={0,1,2,3,{"aaa",{{3},{1},{2}},"ccc"},4}
test_equal("fetch",{2},fetch(s,{5,2,3}))
test_equal("store",{0,1,2,3,{"aaa",{{3},{1},{98,98,98}},"ccc"},4},store(s,{5,2,3},"bbb"))

test_equal("repeat_pattern",{1,2,1,2,1,2,1,2},repeat_pattern({1,2},4))
sequence vect,coords
vect={{21,22,23},{4,5,6,7},{8,9,0},{10,-1,-2,-3}}
coords={{2,1},{1,3},{2}}
test_equal("project",{{{22,21},{21,23},{22}},{{5,4},{4,6},{5}},{{9,8},{8,0},{9}},{{-1,10},{10,-2},{-1}}},seq:project(vect,coords))

sequence S1
S1={{2,3,5,7,11,13},{17,19,23,29,31,37},{41,43,47,53,59,61}}

test_equal("project()",
{{{3,5,11},{2,7,13}},{{19,23,31},{17,29,37}},{{43,47,59},{41,53,61}}},
project(S1,{{2,3,5},{1,4,6}}))

test_equal("extract 1",{11,17,13},extract({13,11,9,17},{2,4,1}))
test_equal("extract 2",{11,13,11,13,9,9},extract({13,11,9,17},{2,1,2,1,3,3}))
test_equal("extract 3",{},extract({13,11,9,17},{}))
test_equal("extract 4",{17},extract({13,11,9,17},{4}))

test_equal("valid_index 1", 0,valid_index({1,2,3},3.5))
test_equal("valid_index 2", 0,valid_index({1,2,3}, -1))
test_equal("valid_index 3", 0,valid_index({1,2,3}, 0))
test_equal("valid_index 4", 0,valid_index({1,2,3}, 4))
test_equal("valid_index 5", 0,valid_index({1,2,3}, {}))
test_equal("valid_index 6", 0,valid_index({1,2,3}, {2}))
test_equal("valid_index 7", 1,valid_index({1,2,3}, 1))
test_equal("valid_index 8", 1,valid_index({1,2,3}, 2))
test_equal("valid_index 9", 1,valid_index({1,2,3}, 3))
test_equal("valid_index A", 0,valid_index({}, 0))
test_equal("valid_index B", 0,valid_index({}, 1))

test_equal("rotate: left -1", {1,6,2,3,4,5,7},rotate({1,2,3,4,5,6,7},-1*ROTATE_LEFT,2,6))
test_equal("rotate: left 0",  {1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 0*ROTATE_LEFT,2,6))
test_equal("rotate: left 1",  {1,3,4,5,6,2,7},rotate({1,2,3,4,5,6,7}, 1*ROTATE_LEFT,2,6))
test_equal("rotate: left 2",  {1,4,5,6,2,3,7},rotate({1,2,3,4,5,6,7}, 2*ROTATE_LEFT,2,6))
test_equal("rotate: left 3",  {1,6,2,3,4,5,7},rotate({1,2,3,4,5,6,7}, 4*ROTATE_LEFT,2,6))
test_equal("rotate: left 4",  {1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 5*ROTATE_LEFT,2,6))
test_equal("rotate: left 7",  {1,4,5,6,2,3,7},rotate({1,2,3,4,5,6,7}, 7*ROTATE_LEFT,2,6))
test_equal("rotate: left 2/0",{1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 2*ROTATE_LEFT,5,5))

test_equal("rotate: right -1", {1,3,4,5,6,2,7},rotate({1,2,3,4,5,6,7},-1*ROTATE_RIGHT,2,6))
test_equal("rotate: right 0",  {1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 0*ROTATE_RIGHT,2,6))
test_equal("rotate: right 1",  {1,6,2,3,4,5,7},rotate({1,2,3,4,5,6,7}, 1*ROTATE_RIGHT,2,6))
test_equal("rotate: right 2",  {1,5,6,2,3,4,7},rotate({1,2,3,4,5,6,7}, 2*ROTATE_RIGHT,2,6))
test_equal("rotate: right 3",  {1,3,4,5,6,2,7},rotate({1,2,3,4,5,6,7}, 4*ROTATE_RIGHT,2,6))
test_equal("rotate: right 4",  {1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 5*ROTATE_RIGHT,2,6))
test_equal("rotate: right 7",  {1,5,6,2,3,4,7},rotate({1,2,3,4,5,6,7}, 7*ROTATE_RIGHT,2,6))
test_equal("rotate: right 2/0",{1,2,3,4,5,6,7},rotate({1,2,3,4,5,6,7}, 2*ROTATE_RIGHT,5,5))



sequence a, b, c
a = split("John Doe")
b = a[1]
c = a[2]
test_equal("More defaulted params and tokens",{"John","Doe"},{b,c})
test_equal("replace()  #2,5a", "/--ething", replace("//something", "--", 2, 5))
test_equal("replace() #2,5b ", "/--ething        ", replace("//something        ", "--", 2, 5))
test_not_equal("replace() 2,5 #3a", "/--omeething         ", replace("//something                                        ", "--", 2, 5))
test_not_equal("replace() 2,5 #3b", "/--eething         ", replace("//something                                            ", "--", 2, 5))
test_not_equal("replace() 2,5 #3c", " --someething         ", replace(" //something                                           ", "--", 2, 3))


test_equal("pivot #1", {{2, -4.8, 3.341, -8}, {6, 6, 6, 6}, {7, 8.5, "text"}}, pivot( {7, 2, 8.5, 6, 6, -4.8, 6, 6, 3.341, -8, "text"}, 6 )) 
test_equal("pivot #2", {{-4, -1, -7}, {}, {4, 1, 6, 9, 10}}, pivot( {4, 1, -4, 6, -1, -7, 9, 10} ) )
test_equal("pivot #3", {{}, {}, {5}}, pivot( 5 ) )
test_equal("pivot #4", {{}, {5}, {}}, pivot( 5, 5 ) )
test_equal("pivot #5", {{5}, {}, {}}, pivot( 5, 10 ) )
test_equal("pivot #6", {{}, {}, {}}, pivot( {}) )
test_equal("pivot #7", {{"abc", "bcd"}, {}, {"def", "efg", "cdf"}}, pivot( {"abc", "def", "bcd", "efg", "cdf"}, "cat") )

test_report()

