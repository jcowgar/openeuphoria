include std/unittest.e as ut

ut:puts( 1, "This should crash\n" )

test_pass("This should never happen")
test_report()
