include locale.e as l
include datetime.e as d
include unittest.e

set_test_module_name("locale.e")
sequence locale

if platform() = LINUX or platform() = FREEBSD then
    locale = "en_US"
elsif platform() = WIN32 then
    locale = "English_United States.1252"
end if

test_true("set()", l:set(locale))
test_equal("set/get", locale, l:get())
test_equal("money", "$1,020.50", l:money(1020.50))
test_equal("number", "1,020.50", l:number(1020.5))

d:datetime dt1
dt1 = d:new(2008, 5, 4, 9, 55, 23)

test_equal("datetime", "Sunday, May 04, 2008",
    l:datetime("%A, %B %d, %Y", dt1))

------------------------------------------------------------------------------------------
--
-- Test PO translation
--
------------------------------------------------------------------------------------------

l:set_po_path("") -- current director
test_equal("set_po_path/get_po_path", "", l:get_po_path())

test_true("po_load() #1", l:po_load("test"))
test_equal("w() #1", "Hello", l:w("hello"))
test_equal("w() #2", "World", l:w("world"))
test_equal("w() #3", "%s, %s!", l:w("greeting"))
test_equal("w() sprintf() #1", "Hello, World!",
    sprintf(l:w("greeting"), {l:w("hello"), l:w("world")}))

test_true("po_load() #2", l:po_load("test2"))
test_equal("w() #4", "Hola", l:w("hello"))
test_equal("w() #5", "Mundo", l:w("world"))
test_equal("w() #6", "%s, %s!", l:w("greeting"))
test_equal("w() sprintf() #2", "Hola, Mundo!",
    sprintf(l:w("greeting"), {l:w("hello"), l:w("world")}))
