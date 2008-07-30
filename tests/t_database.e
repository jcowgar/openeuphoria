include std/unittest.e
include std/eds.e
include std/filesys.e
include std/sort.e

-- TODO: add actual tests
object void

void = delete_file("testunit.edb")

test_equal("current db #1", "", db_current_database())
test_equal("create db #1", DB_OK, db_create("testunit.edb", DB_LOCK_EXCLUSIVE))
test_equal("current db #2", "testunit.edb", db_current_database())
test_equal("create db #2", DB_EXISTS_ALREADY, db_create("testunit.edb", DB_LOCK_SHARED))
test_equal("current db #3", "testunit.edb", db_current_database())
db_close()
test_equal("current db #4", "", db_current_database())


test_equal("open db", DB_OK, db_open("testunit.edb", DB_LOCK_EXCLUSIVE))
test_equal("current db #4", "testunit.edb", db_current_database())

test_equal("create table #1", DB_OK, db_create_table("first"))
test_equal("current table #1", "first", db_current_table())

test_equal("create table #2", DB_OK, db_create_table("second"))
test_equal("current table #2", "second", db_current_table())

test_equal("create table #3", DB_OK, db_create_table("third"))
test_equal("current table #3", "third", db_current_table())

test_equal("create table #4", DB_EXISTS_ALREADY, db_create_table("third"))
test_equal("current table #4", "third", db_current_table())

db_delete_table("first")
db_delete_table("third")
db_delete_table("second")
test_equal("delete table #1", "", db_current_table())


test_equal("create table #5", DB_OK, db_create_table("second"))
test_equal("create table #6", DB_OK, db_create_table("first"))
test_equal("create table #7", DB_OK, db_create_table("third"))
test_equal("table_list", {"first", "second", "third"}, sort(db_table_list()))

test_equal("select table #1", DB_OK, db_select_table("first"))
test_equal("current table #5", "first", db_current_table())

test_equal("select table #2", DB_OK, db_select_table("second"))
test_equal("current table #6", "second", db_current_table())

test_equal("select table #3", DB_OK, db_select_table("third"))
test_equal("current table #7", "third", db_current_table())
test_equal("select table #4", DB_OK, db_select_table("third"))
test_equal("current table #8", "third", db_current_table())

test_equal("select table #4", DB_OPEN_FAIL, db_select_table("bad table name"))
test_equal("current table #9", "third", db_current_table())

db_dump("lowlvl.txt", 1)
db_close()
void = delete_file("testunit.edb")

test_report()
