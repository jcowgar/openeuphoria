with define SAFE

include std/machine.e
include std/unittest.e

atom addr = allocate( 4 )
eu:poke( addr - 1, 0 )
free( addr )

test_report()
