-- (c) Copyright 2008 Rapid Deployment Software - See License.txt
--
-- Euphoria 4.0
-- Sequence routines

--****
-- Category: 
--   sequence
--
-- File:
--   lib_sequence
--
-- Title:
--   Euphoria Database System
--****

include machine.e
include search.e

--**
-- Signature:
-- global procedure append(sequence s1, object x)
--
-- Description:
-- Create a new sequence (s2) identical to s1 but with x added on the end as the last element. The length of s2 will be length(s1) + 1.
--
-- Comments:
-- If x is an atom this is equivalent to <strong>s2 = s1 & x</strong>. If x is a sequence it is not equivalent.
--
-- The extra storage is allocated automatically and very efficiently with Euphoria's dynamic storage allocation. The case where s1 and s2 are actually the same variable (as in Example 1 below) is highly optimized. 
--
-- Example 1:
-- You can use append() to dynamically grow a sequence, e.g.
-- 
-- sequence x
--
-- x = {}
-- for i = 1 to 10 do
--     x = append(x, i)
-- end for
-- -- x is now {1,2,3,4,5,6,7,8,9,10}
--
-- Example 2: 	Any kind of Euphoria object can be appended to a sequence, e.g.
--
-- sequence x, y, z
--
-- x = {"fred", "barney"}
-- y = append(x, "wilma")
-- -- y is now {"fred", "barney", "wilma"}
--
-- z = append(append(y, "betty"), {"bam", "bam"})
-- -- z is now {"fred", "barney", "wilma", "betty", {"bam", "bam"}}
--**

--**
-- Signature:
-- global procedure prepend(sequence s1, object x)
--
-- Description:
-- Create a new sequence (s2) identical to s1 but with x added onto the start of s1 as the first element. The length of s2 will be length(s1) + 1.
--
-- Comments:
-- If x is an atom this is the same as s2 = x & s1. If x is a sequence it is not the same.
--
-- The case where s1 and s2 are the same variable is handled very efficiently.
--
-- Example 1: 	
-- prepend({1,2,3}, {0,0})   -- {{0,0}, 1, 2, 3}
-- -- Compare with concatenation:
-- {0,0} & {1,2,3}           -- {0, 0, 1, 2, 3}
-- 	
-- Example 2: 	
-- s = {}
-- for i = 1 to 10 do
--     s = prepend(s, i)
-- end for
-- -- s is {10,9,8,7,6,5,4,3,2,1}
--**

--**
-- Signature:
-- global procedure repeat(sequence x, atom a)
--
-- Description:
-- Create a sequence of length a where each element is x.
--
-- Comments:
-- When you repeat a sequence or a floating-point number the
--  interpreter does not actually make multiple copies in memory.
--  Rather, a single copy is "pointed to" a number of times.
--
-- Example: 	
-- repeat(0, 10)      -- {0,0,0,0,0,0,0,0,0,0}
--
-- repeat("JOHN", 4)  -- {"JOHN", "JOHN", "JOHN", "JOHN"}
-- -- The interpreter will create only one copy of "JOHN"
-- -- in memory
--**

--**
-- Signature:
-- global procedure length(sequence s)
--
-- Description:
-- Return the length of a sequence s. An error will occur if s is an atom.
--
-- Comments:
-- The length of each sequence is stored internally by the
--  interpreter for quick access. (In other languages this
--  operation requires a search through memory for an end marker.)
--
-- Example 1:
-- length({{1,2}, {3,4}, {5,6}})   -- 3
--
-- length("")    -- 0
--
-- length({})    -- 0
--**

--**
-- Reverse the order of elements in a sequence.
--
-- Comments:
-- A new sequence is created where the top-level elements appear in reverse order compared to the original sequence.
--
-- Example:
-- reverse({1,3,5,7})          -- {7,5,3,1}
--
-- reverse({{1,2,3}, {4,5,6}}) -- {{4,5,6}, {1,2,3}}
--
-- reverse({99})               -- {99}
--
-- reverse({})                 -- {}

global function reverse(sequence s)
-- moved from misc.e
-- Thanks to Hawke' for helping to make this run faster.
	integer lower, n, n2
	sequence t

	n = length(s)
	n2 = floor(n/2)+1
	t = repeat(0, n)
	lower = 1
	for upper = n to n2 by -1 do
		t[upper] = s[lower]
		t[lower] = s[upper]
		lower += 1
	end for
	return t
end function
--**

--**
-- Return the first size items of st. If size is greater than the length of st, then the entire st will be returned.
--
-- Comments:
-- A new sequence is created.
--
-- st can be any type of sequence, including nested sequences.
--
-- Example:
-- s2 = head("John Doe", 4)
-- -- s2 is John
--
-- s2 = head("John Doe", 50)
-- -- s2 is John Doe
--
-- s2 = head({1, 5.4, "John", 30}, 3)
-- -- s2 is {1, 5.4, "John"}

global function head(sequence st, integer size)
	if size < length(st) then
		return st[1..size]
	end if

	return st
end function
--**

--**
-- Return len items starting at start. If start + len is greater than the length of st, then everything in st starting at start will be returned.
-- 
-- Comments:
-- A new sequence is created.
--
-- st can be any type of sequence, including nested sequences.
--
-- Example:
-- s2 = mid("John Middle Doe", 6, 6)
-- -- s2 is Middle

-- s2 = left("John Middle Doe", 6, 50)
-- -- s2 is Middle Doe

-- s2 = left({1, 5.4, "John", 30}, 2, 2)
-- -- s2 is {5.4, "John"}

global function mid(sequence st, atom start, atom len)
	if len<0 then
		len += length(st)
		if len<0 then
			crash("mid(): len was %d and should be greater than %d.",{len-length(st),-length(st)})
		end if
	end if
	if start > length(st) or len=0 then
		return ""
	end if
	if start<1 then
		start=1
	end if
	if start+len-1 >= length(st) then
		return st[start..$]
	else
		return st[start..len+start-1]
	end if
end function
--**

--**
-- Return items start to stop from st. If stop is greater than the length of st, then from start to the
-- end of st will be returned. If stop is zero, it will be treated as the end of st. If stop is a
-- negative value, then it will be treated as stop positions from the end of st.
--
-- Comments:
-- A new sequence is created.
--
-- st can be any type of sequence, including nested sequences.
--
-- Example:
-- s2 = slice("John Doe", 6, 8)
-- -- s2 is Doe
--
-- s2 = slice("John Doe", 6, 50)
-- -- s2 is Doe
--
-- s2 = slice({1, 5.4, "John", 30}, 2, 3)
-- -- s2 is {5.4, "John"}
--
-- s2 = slice({1,2,3,4,5}, 2, -1)
-- -- s2 is {2,3,4}
--
-- s2 = slice({1,2,3,4,5}, 2, 0)
-- -- s2 is {2,3,4,5}

global function slice(sequence st, atom start, atom stop)
	if stop < 0 then stop = length(st) + stop end if
	if stop = 0 then stop = length(st) end if
	if start < 1 then start = 1 end if
	if stop > length(st) then stop = length(st) end if
	if start > stop then return "" end if

	return st[start..stop]
end function
--**

--**
-- Perform a vertical slice on a nested sequence
--
-- Example:
-- s = vsplice({5,1}, {5,2}, {5,3}}, 2)
-- -- s is {1,2,3}

-- s = vsplice({5,1}, {5,2}, {5,3}}, 1)
-- -- s is {5,5,5}

global function vslice(sequence s, atom colno)
	sequence ret

	ret = s

	for i = 1 to length(s) do
		ret[i] = s[i][colno]
	end for

	return ret
end function
--**

--**
-- Return the last n items of st. If n is greater than the length of st, then the entire st will be returned.
--
-- Comments:
-- A new sequence is created.
--
-- st can be any type of sequence, including nested sequences.
--
-- Example:
-- s2 = tail("John Doe", 3)
-- -- s2 is Doe

-- s2 = tail("John Doe", 50)
-- -- s2 is John Doe

-- s2 = tail({1, 5.4, "John", 30}, 3)
-- -- s2 is {5.4, "John", 30}

global function tail(sequence st, atom n)
	if n >= length(st) then
		return st
	else
		return st[$-n+1..$]
	end if
end function
--**

--**
-- Remove an item or a range of items from st. If index is an integer, then only that element will be removed.
-- If index is a sequence, it must be a sequence of two integers representing start and stop index.
--
-- Comments:
-- A new sequence is created. st can be a string or complex sequence.
--
-- Example:
-- s = remove("Johnn Doe", 4)
-- -- s is "John Doe"
--
-- s = remove({1,2,3,3,4}, 4)
-- -- s is {1,2,3,4}
--
-- s = remove("John Middle Doe", {6, 12})
-- -- s is "John Doe"
--
-- s = remove({1,2,3,3,4,4}, {4, 5})
-- -- s is {1,2,3,4}

global function remove(sequence st, object index)
	atom start, stop

	if atom(index) then
		if index > length(st) or index < 1 then
			return st
		end if

		return st[1..index-1] & st[index+1..$]
	end if

	if length(index) != 2 then
		crash("second parameter to remove(), when a sequence, must be a length of 2, " &
			  "representing start and to indexes.", {})
	end if

	start = index[1]
	stop = index[2]

	if start > length(st) or start > stop or stop < 0 then
		return st
	elsif start<2 then
		if stop>=length(st) then
			return ""
		else
			return st[stop+1..$]
		end if
	elsif stop >= length(st) then
		return st[1..start-1]
	end if

	return st[1..start-1] & st[stop+1..$]
end function
--**

constant dummy = 0

--**
-- Insert what into st at index index as a new element. The item is inserted before index, not after. insert()ing a sequence into a string returns a sequence which is no longer a string.
--
-- Comments:
-- A new sequence is created. st and what can be any type of sequence, including nested sequences.
-- what is inserted as a new element in st, so that the length of the new sequence is always length(st)+1.
--
-- Example 1:
-- s = insert("John Doe", " Middle", 5)
-- -- s is {'J','o','h','n'," Middle ",'D','o','e'}
--
-- Example 2:
-- s = insert({10,30,40}, 20, 2)
-- -- s is {10,20,30,40}

global function insert(sequence st, object what, integer index)
	if index > length(st) then
		return append(st, what)
	elsif index <= 1 then
		return prepend(what, st)
	end if

	st &= dummy -- avoids creating/destroying a temp on each invocation
	st[index+1..$] = st[index..$-1]
	st[index] = what
	return st
end function
--**

--**
-- Insert what into st at index index. The item is inserted before index, not after. what is inserted as a subsequence. splicing a string into another yields a new string.
--
-- Comments:
-- A new sequence is created. st and what can be any type of sequence, including nested sequences. The length of this new sequence is the sum of the lengths of st and what (atoms are of length 1 for this purpose). splice() is equivalent to insert() when x is an atom.
--
-- Example 1:
-- s = splice("John Doe", " Middle", 5)
-- -- s is "John Middle Doe"
--
-- Example 2:
-- s = splice({10,30,40}, 20, 2)
-- -- s is {10,20,30,40}

global function splice(sequence st, object what, integer index)
	if index > length(st) then
		return st & what
	elsif index <= 1 then
		return what & st
	end if

	return st[1..index-1] & what & st[index..$]
end function
--**

--**
-- Replace from index start to stop of st with object what. what can be any object.
--
-- Comments:
-- A new sequence is created. st can be a string or complex sequence.
--
-- To replace just one element, simply: s[index] = new_item
--
-- Example 1:
-- s = replace("John Middle Doe", "Smith", 6, 11)
-- -- s is "John Smith Doe"

-- s = replace({45.3, "John", 5, {10, 20}}, 25, 2, 3)
-- -- s is {45.3, 25, {10, 20}}

global function replace(sequence st, object what, integer start, integer stop)
	st = remove(st, {start, stop})
	return splice(st, what, start)
end function
--**

--**
-- split st by delim.
--
-- If limit is > 0 then limit the number of tokens that will be split to limit.
--
-- If any is 1 then split by any one item in delim not delim as a whole. If any is 0 then split
-- by delim as a whole.
--
-- Comments:
-- This function may be applied to a string sequence or a complex sequence
--
-- Example:
-- result = split_adv("John,Middle,Doe", ",", 2, 0)
-- -- result is {"John", "Middle,Doe"}

-- result = split_adv("One,Two|Three.Four", ".,|", 0, 1)
-- -- result is {"One", "Two", "Three", "Four"}

global function split_adv(sequence st, object delim, integer limit, integer any)
	sequence ret
	integer pos,start,next_pos
	ret={}
	start=1

	if atom(delim) then
		delim = {delim}
	end if

	while 1 do
		if any then
			pos = find_any_from(delim, st, start)
			next_pos = pos+1
		else
			pos = match_from(delim, st, start)
			next_pos = pos+length(delim)
		end if

		if pos then
			ret = append(ret, st[start..pos-1])
			start = next_pos
			if limit = 2 then
				exit
			end if
			limit -= 1
		else
			exit
		end if
	end while

	ret = append(ret, st[start..$])

	return ret
end function
--**

--**
-- split st by delim
--
-- Comments:
-- This function may be applied to a string sequence or a complex sequence
--
-- Example:
-- result = split("John,Middle,Doe", ",")
-- -- result is {"John", "Middle", "Doe"}

global function split(sequence st, object delim)
	return split_adv(st, delim, 0, 0)
end function
--**

--**
-- Join s by delim
--
-- Comments:
-- This function may be applied to a string sequence or a complex sequence
--
-- Example:
-- result = join({"John", "Middle", "Doe"}, " ")
-- -- result is "John Middle Doe"

global function join(sequence s, object delim)
	object ret

	if not length(s) then return {} end if

	ret = {}
	for i=1 to length(s)-1 do
		ret &= s[i] & delim
	end for

	ret &= s[length(s)]

	return ret
end function
--**

-- In Unicode (Unicode Character Database) the following codepoints are defined as whitespace:
--    U0009-U000D (Control characters, containing TAB, CR and LF)
--    U0020 SPACE
--    U0085 NEL
--    U00A0 NBSP
--    U1680 OGHAM SPACE MARK
--    U180E MONGOLIAN VOWEL SEPARATOR
--    U2000-U200A (different sorts of spaces)
--    U2028 LSP
--    U2029 PSP
--    U202F NARROW NBSP
--    U205F MEDIUM MATHEMATICAL SPACE
--    U3000 IDEOGRAPHIC SPACE

constant TRIM_WHITESPACES = {9, 10, 11, 12, 13, ' ', #85, #A0, #1680, #180E,
	#2000, #2001, #2002, #2003, #2004, #2005, #2006, #2007, #2008, #2009, #200A, 
	#2028, #2029, #202F, #205F, #3000}

--**
-- Trim any item in what from the head (start) of str
--
-- Example:
-- s = trim_head("\r\nSentence read from a file\r\n", "\r\n")
-- -- s is "Sentence read from a file\r\n"

global function trim_head(sequence str, object what)
	if atom(what) then
		if what = 0.0 then
			what = TRIM_WHITESPACES
		else
			what = {what}
		end if
	end if

	for i = 1 to length(str) do
		if find(str[i], what) = 0 then
			return str[i..$]
		end if
	end for

	return ""
end function
--**

--**
-- Trim any item in what from the end (tail) of str
--
-- Example:
-- s = trim_head("\r\nSentence read from a file\r\n", "\r\n")
-- -- s is "\r\nSentence read from a file"

global function trim_tail(sequence str, object what)
	if atom(what) then
		if what = 0.0 then
			what = TRIM_WHITESPACES
		else
			what = {what}
		end if
	end if

	for i = length(str) to 1 by -1 do
		if find(str[i], what) = 0 then
			return str[1..i]
		end if
	end for

	return ""
end function
--**

--**
-- Trim any item in what from the head (start) and tail (end) of str
--
-- Example:
-- s = trim("\r\nSentence read from a file\r\n", "\r\n")
-- -- s is "Sentence read from a file"

global function trim(sequence str, object what)
	return trim_tail(trim_head(str, what), what)
end function
--**

--**
-- Pad the beginning of a sequence with spaces up to params in length or optionally params can
-- be a sequence {i1, i2} with i1 representing length and i2 the atom to pad with
--
-- Comments:
-- pad_head() will not remove characters. If length(str) is greater than params, this
-- function simply returns str. See <a href="lib_seq.htm#head">head()</a>
-- if you wish to truncate long sequences.
--
-- Example:
-- s = pad_head("ABC", 6)
-- -- s is "   ABC"
--
-- s = pad_head("ABC", {6, '-'})
-- -- s is "---ABC"

global function pad_head(sequence str, object params)
	integer size, ch

	if sequence(params) then
		size = params[1]
		ch = params[2]
	else
		size = params
		ch = ' '
	end if

	if size <= length(str) then
		return str
	end if

	return repeat(ch, size - length(str)) & str
end function
--**

--**
-- Pad the end of a sequence with spaces up to params in length or optionally params can
-- be a sequence {i1, i2} with i1 representing length and i2 the atom to pad with
--
-- Comments:
-- pad_tail() will not remove characters. If length(str) is greater than params, this
-- function simply returns str. See <a href="lib_seq.htm#head">head()</a>
-- if you wish to truncate long sequences.
--
-- Example:
-- s = pad_tail("ABC", 6)
-- -- s is "ABC   "
--
-- s = pad_tail("ABC", {6, '-'})
-- -- s is "ABC---"
global function pad_tail(sequence str, object params)
	integer size, ch

	if sequence(params) then
		size = params[1]
		ch = params[2]
	else
		size = params
		ch = ' '
	end if

	if size <= length(str) then
		return str
	end if
	return str & repeat(ch, size - length(str))
end function
--**

--**
-- Split s1 into multiple sequences of length size
--
-- Comments:
-- The very last sequence might not have i items if the length of s1 is not evenly divisible by i
--
-- Example 1:
-- s = chunk("5545112133234454", 4)
-- -- s is {"5545", "1121", "3323", "4454"}
--
-- Example 2:
-- s = chunk("12345", 2)
-- -- s is {"12", "34", "5"}
--
-- Example 2:
-- s = chunk({1,2,3,4,5,6}, 3)
-- -- s is {{1,2,3}, {4,5,6}}

global function chunk(sequence s, integer size)
	sequence ns
	integer stop

	ns = {}

	for i = 1 to length(s) by size do
		stop = i + size - 1
		if stop > length(s) then
			stop = length(s)
		end if

		ns = append(ns, s[i..stop])
	end for

	return ns
end function
--**

--**
-- Remove all nesting from a sequence
-- 
-- Example 1:
-- s = flatten({{18, 19}, 45, {18.4, 29.3}})
-- -- s is {18, 19, 45, 18.4, 29.3}

global function flatten(sequence s)
	sequence ret
	object x

	ret = {}
	for i = 1 to length(s) do
		x = s[i]
		if atom(x) then
			ret &= x
		else
			ret &= flatten(x)
		end if
	end for

	return ret
end function
--**

constant TO_LOWER = 'a' - 'A'

--**
-- Convert an atom or sequence to lower case.
-- 
-- Example:
-- s = lower("Euphoria")
-- -- s is "euphoria"
--
-- a = lower('B')
-- -- a is 'b'
--
-- s = lower({"Euphoria", "Programming"})
-- -- s is {"euphoria", "programming"}

global function lower(object x)
-- convert atom or sequence to lower case
	return x + (x >= 'A' and x <= 'Z') * TO_LOWER
end function
--**

--**
-- Convert an atom or sequence to upper case.
-- 
-- Example:
-- s = upper("Euphoria")
-- -- s is "EUPHORIA"
--
-- a = upper('b')
-- -- a is 'B'
--
-- s = upper({"Euphoria", "Programming"})
-- -- s is {"EUPHORIA", "PROGRAMMING"}

global function upper(object x)
-- convert atom or sequence to upper case
	return x - (x >= 'a' and x <= 'z') * TO_LOWER
end function
--**
