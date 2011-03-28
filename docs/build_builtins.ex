include std/math.e
include euphoria/keywords.e

integer fh = open("builtins.txt", "w")

puts(fh, `
== Built-in Methods

These methods are built into Euphoria and require no includes.


`)

integer x = 1
for i = 1 to length(builtins) do
	if equal(builtins[i], "?") then
		printf(fh, "| ##[[%s -> :q_print]]## ", { builtins[i] })
	else
		printf(fh, "| ##[[:%s]]## ", { builtins[i] })
	end if

	if x = 4 then
		printf(fh, "|\n")
		x = 1
	else
		x += 1
	end if
end for

if x > 1 then
	for i = x - 1 to 4 do
		printf(fh, " | ")
	end for
end if

printf(fh, "\n")

close(fh)
