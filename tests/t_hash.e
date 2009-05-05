-- t_hash.e
include std/unittest.e
constant s = "Euphoria Programming Language brought to you by Rapid Deployment Software"
constant hashalgo = {-9.123, -5, -4, -3, -2, -1, 0, 0.5, 1, 2, 9, 9.123, #3FFFFFFF, "abc", "abb", ""}
constant expected = {
{#B7F48C20,#F8C6DB45,#32EE1F21,#E99E6554,#70CA9A7C,#F0CA6A78,#D0FC1278,#A5472C74,#E9FC1361,#BF6F937D,#7C6C3F8F,#339E9365,#A547AC74,#EEE47627,#31046996}, -- (-9.123)
{#3C0D29F1,#B99D68D8,#B53F7BDB,#3C0D29F0,#6D67AA1D,#27DC0C95,#2F451A8C,#04975F5F,#ABE977C9,#60FD495F,#42A636FF,#D197B438,#F3660E8B,#00000000,#E5E9967B}, -- (-5)
{#F7D71B77,#00460046,#E5861F90,#F7D71B78,#00460046,#00620062,#00630063,#0C1802CE,#14D00483,#12460440,#209000AB,#009D009D,#0C98034E,#00000001,#30FD0A1E}, -- (-4)
{#543F7601,#45014501,#991D2072,#543F7602,#00460046,#00620062,#00630063,#EAB31DB2,#B895C0C5,#FC2B0042,#FFE58A01,#FFFFFFBC,#6AB39DB2,#00000001,#489B1012}, -- (-3)
{#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000}, -- (-2)
{#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000,#00000000}, -- (-1)
{#9298160C,#362C50CA,#39C1BE55,#DC04A126,#41D79A79,#A9D74D94,#89E134AB,#5E53AF98,#B8E15EA0,#F162824B,#69D46578,#C2838048,#1C5AEDA9,#F3D1A620,#3B0A32D1}, -- (0)
{#A2C54F29,#68326E84,#6AC6820C,#1547B095,#1FD7DDDB,#9FD72DDF,#BFE155DF,#CA5A6BD3,#86E154C6,#D072D4DA,#695DFC86,#5C83D4C2,#CA5AEBD3,#F3A3D14E,#3A8BEBB9}, -- (0.5)
{#54F0C740,#19206EE7,#68155604,#01D8C0F6,#96D7DDEA,#16D72DEE,#36E155EE,#435A6BE2,#0FE154F7,#5972D4EB,#9F6874EF,#D583D4F3,#435AEBE2,#F3A3E0C5,#C206DFA7}, -- (1)
{#6C22F765,#5500AE4B,#285FE7CC,#0D2D605A,#86D7BDDC,#06D74DD8,#26E135D8,#535A0BD4,#1FE134C1,#4972B4DD,#A7BA44CA,#C583B4C5,#535A8BD4,#F3C3D6D5,#4D744CA6}, -- (2)
{#766DA67E,#69526CE7,#DA6B133E,#FC18C2F6,#AED6DDEA,#2ED62DEE,#0EE055EE,#7B5B6BE2,#37E054F7,#6173D4EB,#BDF515D1,#ED82D4F3,#7B5BEBE2,#F2A3E0FD,#7348EDF5}, -- (9)
{#B75E8D74,#F9C6DB44,#30461E74,#6C256555,#F0CA9A7C,#70CA6A78,#50FC1278,#25472C74,#69FC1361,#3F6F937D,#7CC63EDB,#B39E9365,#2547AC74,#EEE476A7,#A4307983}, -- (9.123)
{#3EFDAC4F,#13FFE5B9,#5C31CCF6,#F956C5B9,#E7C9069E,#67C9F69A,#47FF8E9A,#3244B096,#7EFF8F83,#286C0F9F,#F5651FE0,#A49D0F87,#32443096,#ED7894B6,#E5B38385}, -- (3FFFFFFF)
{#D293F868,#02D998E3,#FE45AD31,#0046E6F2,#62D72613,#E2D7D617,#C2E1AE17,#B75A901B,#FBE1AF0E,#AD722F12,#190B4BC7,#21832F0A,#B75A101B,#F3581939,#3EAE0B9C}, -- "abc"
{#1AB62664,#1C3EBB39,#A45D1782,#74F86130,#11D7B76F,#91D7476B,#B1E13F6B,#C45A0167,#88E13E72,#DE72BE6E,#D12E95CB,#5283BE76,#C45A8167,#F3C96548,#3FF8236D}, -- "abb"
{#CA3E47E3,#DE9EF010,#C752FDF0,#5D469E01,#41D792DE,#C1D762DA,#E1E11ADA,#945A24D6,#D8E11BC3,#8E729BDF,#01A6F44C,#02839BC7,#945AA4D6,#F3ECD418,#142557A4}  -- ""
             }

sequence test_data = {}
test_data = append(test_data, s									)
test_data = append(test_data, s[1..1]							)
test_data = append(test_data, s & 1.2345						)
test_data = append(test_data, {s}								)
test_data = append(test_data, s[1]								)
test_data = append(test_data, 'a' 								)
test_data = append(test_data, 'b' 								)
test_data = append(test_data, s[1] + 0.123						)
test_data = append(test_data, 0.123		        				)
test_data = append(test_data, 0.124     						)
test_data = append(test_data, -s								)
test_data = append(test_data, -s[1]								)
test_data = append(test_data, -s[1] - 0.123						)
test_data = append(test_data, ""								)
test_data = append(test_data, s[1..5] & {{1,1.1,{2.23,9}}}		)


for i = 1 to length(hashalgo) do
	for x = 1 to length(test_data) do
		ifdef SHOWHASH then
    		printf(1, "#%08x,", hash(test_data[x], hashalgo[i]))
    	elsedef
    		test_equal(sprintf("hash test# %d hashalgo=%d",{x,i}), expected[i][x], hash(test_data[x], hashalgo[i]) )
    	end ifdef
    end for
    ifdef SHOWHASH then
    	puts(1, "\n")
    end ifdef
end for


test_report()
