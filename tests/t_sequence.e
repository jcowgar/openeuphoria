include sequence.e
include unittest.e

set_test_module_name("sequence.e")

test_equal("reverse() integer sequence", {3,2,1}, reverse({1,2,3}))
test_equal("reverse() string", "nhoJ", reverse("John"))

test_equal("findany_from() string", 7, findany_from("aeiou", "John Doe", 3))
test_equal("findany_from() integers", 6, findany_from({1,3,5,8}, {2,4,5,6,7,8,9}, 4))
test_equal("findany_from() floats", 6,
        findany_from({1.3,3.5,5.6,8.3}, {2.1,4.2,5.3,6.4,7.5,8.3,9.1}, 4))

test_equal("findany() string", 2, findany("aeiou", "John Doe"))
test_equal("findany() integers", 3, findany({1,3,5,7,9}, {2,4,5,6,7,8,9}))
test_equal("findany() floats", 3, findany({1.1,3.2,5.3,7.4,9.5}, {2.1,4.2,5.3,6.4,7.5,8.6,9.7}))

test_equal("head() string", "John", head("John Doe", 4))
test_equal("head() sequence", {1,2,3}, head({1,2,3,4,5,6}, 3))
test_equal("head() nested sequence", {{1,2}, {3,4}}, head({{1,2},{3,4},{5,6}}, 2))
test_equal("head() bounds", "Name", head("Name", 50))

test_equal("mid() string", "Middle", mid("John Middle Doe", 6, 6))
test_equal("mid() sequence", {2,3,4}, mid({1,2,3,4,5,6}, 2, 3))
test_equal("mid() nested sequence", {{3,4},{5,6}}, mid({{1,2},{3,4},{5,6},{7,8}}, 2, 2))
test_equal("mid() bounds", {2,3}, mid({1,2,3}, 2, 50))

test_equal("slice() string", "Middle", slice("John Middle Doe", 6, 11))
test_equal("slice() string, zero end", "Middle Doe", slice("John Middle Doe", 6, 0))
test_equal("slice() string, neg end", "Middle", slice("John Middle Doe", 6, -4))
test_equal("slice() sequence", {2,3}, slice({1,2,3,4}, 2, 3))
test_equal("slice() nested sequence", {{3,4},{5,6}}, slice({{1,2},{3,4},{5,6},{7,8}}, 2, 3))
test_equal("slice() bounds", "Middle Doe", slice("John Middle Doe", 6, 50))

test_equal("tail() string", "Doe", tail("John Middle Doe", 3))
test_equal("tail() sequence", {3,4}, tail({1,2,3,4}, 2))
test_equal("tail() nested sequence", {{3,4},{5,6}}, tail({{1,2},{3,4},{5,6}}, 2))
test_equal("tail() bounds", {1,2,3,4}, tail({1,2,3,4}, 50))

test_equal("split() simple string", {"a","b","c"}, split("a,b,c", ','))
test_equal("split() sequence", {{1},{2},{3},{4}}, split({1,0,2,0,3,0,4}, 0))
test_equal("split() nested sequence", {{"John"}, {"Doe"}}, split({"John", 0, "Doe"}, 0))
test_equal("split_adv() limit set", {"a", "b,c"}, split_adv("a,b,c", ',', 2, 0))
test_equal("split_adv() any character", {"a", "b", "c"}, split_adv("a,b.c", ",.", 0, 1))
test_equal("split_adv() limit and any character", {"a", "b", "c|d"},
    split_adv("a,b.c|d", ",.|", 3, 1))

test_equal("join() simple string", "a,b,c", join({"a", "b", "c"}, ","))
test_equal("join() nested sequence", {"John", 0, "Doe"}, join({{"John"}, {"Doe"}}, 0))

test_equal("remove() integer sequence", {1,3}, remove({1,2,3}, 2))
test_equal("remove() string", "Jon", remove("John", 3))
test_equal("remove() nested sequence", {{1,2}, {5,6}}, remove({{1,2},{3,4},{5,6}}, 2))
test_equal("remove() bounds", "John", remove("John", 55))

test_equal("remove_range() integer sequence", {1,5}, remove_range({1,2,3,4,5}, 2, 4))
test_equal("remove_range() string", "John Doe", remove_range("John M Doe", 5, 6))
test_equal("remove_range() bounds", "John", remove_range("John Doe", 5, 100))

test_equal("insert() integer sequence", {1,2,3}, insert({1,3}, 2, 2))
test_equal("insert() string", "John", insert("Jon", "h", 3))

test_equal("replace_range() integer sequence", {1,2,3}, replace_range({1,8,9,3}, 2, 2, 3))
test_equal("replace_range() integer sequence w/sequence", {1,2,3,4},
    replace_range({1,8,9,4}, {2,3}, 2, 3))

test_equal("trim_head() default", "John", trim_head(" \r\n\t John", 0))
test_equal("trim_head() specified", "Doe", trim_head("John Doe", " hoJn"))
test_equal("trim_head() integer", "John", trim_head("\nJohn", 10))

test_equal("trim_tail() defaults", "John", trim_tail("John\r \n\t", 0))
test_equal("trim_tail() specified", "John", trim_tail("John Doe", " eDo"))
test_equal("trim_tail() integer", "John", trim_tail("John\n", 10))

test_equal("trim() defaults", "John", trim("\r\n\t John \n\r\t", 0))
test_equal("trim() specified", "John", trim("abcJohnDEF", "abcDEF"))
test_equal("trim() integer", "John\t\n", trim(" John\t\n ", 32))

test_equal("truncate() #1", "ABC", truncate("ABCDEFG", 3))
test_equal("truncate() #2", "ABC", truncate("ABC", 15))

test_equal("pad_head() #1", "   ABC", pad_head("ABC", 6))
test_equal("pad_head() #2", "ABC", pad_head("ABC", 3))
test_equal("pad_head() #3", "ABC", pad_head("ABC", 1))

test_equal("pad_tail() #1", "ABC   ", pad_tail("ABC", 6))
test_equal("pad_tail() #2", "ABC", pad_tail("ABC", 3))
test_equal("pad_tail() #3", "ABC", pad_tail("ABC", 1))

test_equal("chunk() sequence", {{1,2,3}, {4,5,6}}, chunk({1,2,3,4,5,6}, 3))
test_equal("chunk() string", {"AB", "CD", "EF"}, chunk("ABCDEF", 2))
test_equal("chunk() odd size", {"AB", "CD", "E"}, chunk("ABCDE", 2))
