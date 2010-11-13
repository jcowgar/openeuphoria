 -- The value of platform_names should be the equivalent of the perl map: 
-- { DOS32 => { "DOS" }, WIN32 => { "WIN" },  
-- LINUX(=FREEBSD=UNIX) =>{ "UNIX", "LINUX", "FREEBSD" },  
-- OSX => { "OSX" } } 

include std/unittest.e
include std/map.e
include std/os.e as os

function putm(map:map m, object k, object v, object act = map:PUT, integer trigger = 100)
	map:put(m, k, v, act, trigger)
	return m
end function

constant platform_names = 
		putm(  
			putm( 
				putm( 
					putm( 
						putm( 
							putm( 
								putm( 
									putm( 
										putm( map:new( 12 ), 
											os:WIN32, {}, ), 
										os:LINUX, {}, ), 
									os:FREEBSD, {}, ), 
								os:OSX, {}, ),  
							os:WIN32,  "WIN32" , map:APPEND, 100 ), 
						os:LINUX, "LINUX", map:APPEND, 100 ), 
					os:LINUX,    "UNIX", map:APPEND, 100 ), 
				os:FREEBSD,  "FREEBSD" , map:APPEND, 100 ), 
	      os:OSX,  "OSX" , map:APPEND, 100 )

constant platform_values = 
	putm(  
		putm( 
			putm( 
				putm( 
					putm( map:new(10), 
					"WIN32", os:WIN32 ), 
				"LINUX", os:LINUX ), 
			"FREEBSD", os:FREEBSD ), 
		"UNIX", os:LINUX ), 
	"OSX",  os:OSX )

constant compile_flags = 
	putm( 
		putm( 
			putm( 
				putm( 
					putm( 
						putm( map:new(10), 
							"DOS32", "-WAT " ), 
						"WIN32", "-WAT -CON " ), 
					"LINUX", "" ), 
				"FREEBSD", "" ), 
			"UNIX", "" ), 
		"OSX",  "" ) 

constant translator_names = 
	putm( 
		putm( 
			putm( 
				putm( 
					putm( 
						putm( map:new(10), 
							"DOS32", "eucd " ), 
						"WIN32", "euc " ), 
					"LINUX", "euc" ), 
				"FREEBSD", "euc" ), 
			"UNIX", "euc" ), 
		"OSX",  "euc" ) 

test_true("Created the Hashes:", 1) 

test_report()
