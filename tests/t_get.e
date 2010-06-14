include std/get.e
include std/unittest.e

test_equal("value() no data supplied", {GET_EOF, 0}, value(""))
test_equal("value() integer", {GET_SUCCESS, 10}, value("10"))
test_equal("value() bad integer", {GET_FAIL, 0}, value("John"))
test_equal("value() float", {GET_SUCCESS, 10.5}, value("10.5"))
test_equal("value() sequence", {GET_SUCCESS, {1,2}}, value("{1,2}"))
test_equal("value_from() integer", {GET_SUCCESS, 10, 2, 0}, value("Data: 10", 7,GET_LONG_ANSWER))
test_equal("value_from() integer with leading whitespace",
    {GET_SUCCESS, 10, 3, 1}, value("Data: 10", 6,GET_LONG_ANSWER))

test_equal("defaulted_value() #1", 0, defaulted_value("abc", 0))
test_equal("defaulted_value() #2", 10, defaulted_value("10", 0))
test_equal("defaulted_value() #3", 10.5, defaulted_value("10.5", 0))
test_equal("defaulted_value() #4", 0, defaulted_value(10.5, 0))
test_equal("defaulted_value() #5", {1,2,3}, defaulted_value("123={1,2,3}", 0, 5))
test_equal("defaulted_value() #6", 0, defaulted_value("123={1,2,3}", 0, 4))

test_equal("value() scientific notation #1", {GET_SUCCESS, 3.14e2}, value("3.14e2"))
test_equal("value() scientific notation #2", {GET_SUCCESS, 3.14e-12}, value("3.14E-12"))
test_equal("value() scientific notation #3", {GET_SUCCESS, 3.14e+12}, value("+3.14e+12"))
test_equal("value() scientific notation #4 no exponent", {GET_FAIL, 0}, value("+3.14e"))

test_equal("value() no hex digits", {GET_FAIL, 0}, value("#"))
test_equal("value() decimal point only", {GET_FAIL, 0}, value("."))

test_report()

