-- (c) Copyright - See License.txt
--
namespace stack

--****
-- == Stack
--
-- **Page Contents**
--
-- <<LEVELTOC depth=2>>

include std/error.e
include std/eumem.e

--****
-- === Constants
--

--**
-- Stack types
-- * FIFO: like people standing in line: first item in is first item out
-- * FILO: like for a stack of plates  : first item in is last item out


public constant
	FIFO = 1,
	FILO = 2

--****
-- === Types
--

enum type_tag, stack_type, data
constant type_is_stack = "Eu:StdStack"

--**
-- A stack is a sequence of objects with some internal data.

public type stack(object obj_p)
	if not valid(obj_p, "") then return 0 end if

	object o = ram_space[obj_p]
	if not sequence(o) then return 0 end if
	if not length(o) = data then return 0 end if
	if not equal(o[type_tag], type_is_stack) then return 0 end if
	if not find(o[stack_type], { FIFO, FILO }) then return 0 end if
	if not sequence(o[data]) then return 0 end if

	return 1
end type

--****
-- === Routines
--

--**
-- Create a new stack.
--
-- Parameters:
--		# ##stack_type##: an integer, defining the semantics of the stack. The
--                        default is FILO.
--
-- Returns:
--		An empty **stack**.  Note that the variable storing the stack must
--      not be an integer.  The resources allocated for the stack will
--      be automatically cleaned up if the reference count of the returned value drops
--      to zero, or if passed in a call to [[:delete]].
--
-- Comments:
-- There are two sorts of stacks, designated by the types ##FIFO## and ##FILO##:
-- * A ##FIFO## stack is one where the first item to be pushed is popped first.
--   People standing in queue form a ##FIFO## stack.
-- * A ##FILO## stack is one where the item pushed last is popped first. 
--   A column of coins is of the ##FILO## kind.
--
-- See Also:
-- [[:is_empty]]

public function new(integer typ = FILO)
	atom new_stack = malloc()

	ram_space[new_stack] = { type_is_stack, typ, {} }

	return new_stack
end function


--**
-- Determine whether a stack is empty.
--
-- Parameters:
--		# ##sk##: the stack being queried.
--
-- Returns:
--		An **integer**, 1 if the stack is empty, else 0.
--
-- See Also:
-- [[:size]]

public function is_empty(stack sk)
	return length(ram_space[sk][data]) = 0
end function

--**
-- Returns how many elements a stack has.
--
-- Parameters:
--		# ##sk##: the stack being queried.
--
-- Returns:
--		An **integer**, the number of elements in ##sk##.

public function size(stack sk)
	return length(ram_space[sk][data])
end function

--**
-- Fetch a value from the stack without removing it from the stack.
--
-- Parameters:
--   # ##sk##: the stack being queried
--   # ##idx##: an integer, the place to inspect. The default is 1 (top item).
--
-- Returns:
--   An **object**, the ##idx##-th item of the stack.
--
-- Errors:
--   If the supplied value of ##idx## does not correspond to an existing element,
--   an error occurs.
--
-- Comments:
--   * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
--   * For ##FILO## stacks, the top item is the newest item in the stack.
--
--   ##idx## can be less than 1, in which case it refers relative to the end item.
--   Thus, 0 stands for the end element.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk,2.3)
-- ? at(sk,0) -- 5
-- ? at(sk,-1) -- "abc"
-- ? at(sk,1) -- 2.3
-- ? at(sk,2) -- "abc"
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk,2.3)
-- ? at(sk,0) -- 2.3
-- ? at(sk,-1) -- "abc"
-- ? at(sk,1) -- 5
-- ? at(sk,2) -- "abc"
-- </eucode>
--
-- See Also:
-- [[:size]], [[:top]], [[:peek_top]], [[:peek_end]]

public function at(stack sk, integer idx = 1)
	sequence o = ram_space[sk][data]
	integer oidx = idx

	if idx <= 0 then
		-- number from end
		idx = 1 - idx
	else
		idx = length(o) - idx + 1
	end if
	
	if idx < 1 or idx > length(o) then
		crash("stack index (%d) out of bounds for at()", oidx)
	end if

	return o[idx]
end function

--**
-- Adds something to a stack.
--
-- Parameters:
--		# ##sk##: the stack to augment
--		# ##value##: an object, the value to push.
--
-- Comments:
-- ##value## appears at the end of ##FIFO## stacks and the top of ##FILO## stacks.
--  The size of the stack increases by one.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? top(sk) -- 5
-- ? last(sk) -- 2.3
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? top(sk) -- 2.3
-- ? last(sk) -- 5
-- </eucode>
--
-- See Also:
-- [[:pop]], [[:top]]

public procedure push(stack sk, object value)
	-- The last element in the data sequence is always the top item, 
	-- regardless of the stack type.
	
	-- Type checking ensures type is either FIFO or FILO
	switch ram_space[sk][stack_type] do
		case FIFO then
			ram_space[sk][data] = prepend(ram_space[sk][data], value)

		case FILO then
			ram_space[sk][data] = append(ram_space[sk][data], value)
			
		case else
			crash("Internal error in stack.e: Stack %d has invalid stack type %d", {sk,ram_space[sk][stack_type]})
			
	end switch
end procedure

--**
-- Retrieve the top element on a stack.
--
-- Parameters:
--		# ##sk##: the stack to inspect.
--
-- Returns:
--		An **object**, the top element on a stack.
--
-- Comments:
-- This call is equivalent to ##at(sk,1)##.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? top(sk) -- 2.3
-- </eucode>
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? top(sk) -- 5
-- </eucode>
--
-- See Also:
-- [[:at]], [[:pop]], [[:peek_top]], [[:last]]

public function top(stack sk)
	if length(ram_space[sk][data]) = 0 then
		crash("stack is empty so there is no top()", {})
	end if

	return ram_space[sk][data][$]
end function

--**
-- Retrieve the end element on a stack.
--
-- Parameters:
--		# ##sk##: the stack to inspect.
--
-- Returns:
--		An **object**, the end element on a stack.
--
-- Comments:
-- This call is equivalent to ##at(sk,0)##.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? last(sk) -- 5
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- ? last(sk) -- 2.3
-- </eucode>
--
-- See Also:
-- [[:at]], [[:pop]], [[:peek_end]], [[:top]]

public function last(stack sk)
	if length(ram_space[sk][data]) = 0 then
		crash("stack is empty so there is no last()", {})
	end if

	return ram_space[sk][data][1]
end function

--**
-- Removes an object from a stack.
--
-- Parameters:
--		# ##sk##: the stack to pop
--      # ##idx##: integer. The n-th item to pick from the stack. The default is 1.
--
-- Returns:
--   An item from the stack, which is also removed from the stack.
--
-- Errors:
-- * If the stack is empty, an error occurs. 
-- * If the ##idx## is greater than the number of items in the stack, an error occurs.
--
-- Comments:
-- * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
-- * For ##FILO## stacks, the top item is the newest item in the stack.
--
-- When ##idx## is omitted the 'top' of the stack is removed and returned. 
-- When ##idx## is supplied, it represents the N-th item from the top to be
-- removed and returned. Thus an ##idx## of 2 returns the 2nd item from the
-- top, a value of 3 returns the 3rd item from the top, etc ...
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? size(sk) -- 3
-- ? pop(sk) -- 1
-- ? size(sk) -- 2
-- ? pop(sk) -- 2
-- ? size(sk) -- 1
-- ? pop(sk) -- 3
-- ? size(sk) -- 0
-- ? pop(sk) -- *error*
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? size(sk) -- 3
-- ? pop(sk) -- 3
-- ? size(sk) -- 2
-- ? pop(sk) -- 2
-- ? size(sk) -- 1
-- ? pop(sk) -- 1
-- ? size(sk) -- 0
-- ? pop(sk) -- *error*
-- </eucode>
--
-- Example 3:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- push(sk, 4)
-- -- stack contains {1,2,3,4} (oldest to newest)
-- ? size(sk) -- 4
-- ? pop(sk, 2) -- Pluck out the 2nd newest item .. 3
-- ? size(sk) -- 3 
-- -- stack now contains {1,2,4}
-- </eucode>
--
-- Example 4:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- push(sk, 4)
-- -- stack contains {1,2,3,4} (oldest to newest)
-- ? size(sk) -- 4
-- ? pop(sk, 2) -- Pluck out the 2nd oldest item .. 2
-- ? size(sk) -- 3 
-- -- stack now contains {1,3,4}
-- </eucode>
--
-- See Also:
-- [[:push]], [[:top]], [[:is_empty]]

public function pop(stack sk, integer idx = 1)
	sequence t
	
	t = ram_space[sk][data]
	if idx < 0 or idx > length(t) then
		if length(t) = 0 then
			crash("stack is empty, cannot pop")
		else
			crash("stack idx (%d) out of bounds in pop()", {idx})
		end if
	end if
	idx = length(t) - idx + 1

	object top_obj = t[idx]
	ram_space[sk][data] = t[1 .. idx - 1] & t[idx + 1 .. $]
	return top_obj
end function

--**
-- Gets an object, relative to the top, from a stack.
--
-- Parameters:
--		# ##sk##: the stack to get from.
--      # ##idx##: integer. The n-th item to get from the stack. The default is 1.
--
-- Returns:
--   An item from the stack, which is **not** removed from the stack.
--
-- Errors:
-- * If the stack is empty, an error occurs. 
-- * If the ##idx## is greater than the number of items in the stack, an error occurs.
--
-- Comments:
-- This is identical to [[:pop]] except that it does not remove the item.
--
-- * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
-- * For ##FILO## stacks, the top item is the newest item in the stack.
--
-- When ##idx## is omitted the 'top' of the stack is returned. 
-- When ##idx## is supplied, it represents the N-th item from the top to be
-- returned. Thus an ##idx## of 2 returns the 2nd item from the
-- top, a value of 3 returns the 3rd item from the top, etc ...
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? peek_top(sk) -- 1
-- ? peek_top(sk,2) -- 2
-- ? peek_top(sk,3) -- 3
-- ? peek_top(sk,4) -- *error*
-- ? peek_top(sk, size(sk)) -- 3 (end item)
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? peek_top(sk) -- 3
-- ? peek_top(sk,2) -- 2
-- ? peek_top(sk,3) -- 1
-- ? peek_top(sk,4) -- *error*
-- ? peek_top(sk, size(sk)) -- 1 (end item)
-- </eucode>
--
-- See Also:
-- [[:pop]], [[:top]], [[:is_empty]], [[:size]], [[:peek_end]]

public function peek_top(stack sk, integer idx = 1)
	sequence t
	
	t = ram_space[sk][data]
	if idx < 0 or idx > length(t) then
		if length(t) = 0 then
			crash("stack is empty, cannot peek_top")
		else
			crash("stack idx (%d) out of bounds in peek_top()", {idx})
		end if
	end if
	idx = length(t) - idx + 1

	object top_obj = t[idx]
	return top_obj
end function

--**
-- Gets an object, relative to the end, from a stack.
--
-- Parameters:
--		# ##sk##: the stack to get from.
--      # ##idx##: integer. The n-th item from the end to get from the stack. The default is 1.
--
-- Returns:
--   An item from the stack, which is **not** removed from the stack.
--
-- Errors:
-- * If the stack is empty, an error occurs. 
-- * If the ##idx## is greater than the number of items in the stack, an error occurs.
--
-- Comments:
-- * For ##FIFO## stacks (queues), the end item is the newest item in the stack.
-- * For ##FILO## stacks, the end item is the oldest item in the stack.
--
-- When ##idx## is omitted the 'end' of the stack is returned. 
-- When ##idx## is supplied, it represents the N-th item from the end to be
-- returned. Thus an ##idx## of 2 returns the 2nd item from the
-- end, a value of 3 returns the 3rd item from the end, etc ...
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? peek_end(sk) -- 3
-- ? peek_end(sk,2) -- 2
-- ? peek_end(sk,3) -- 1
-- ? peek_end(sk,4) -- *error*
-- ? peek_end(sk, size(sk)) -- 3 (top item)
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk, 1)
-- push(sk, 2)
-- push(sk, 3)
-- ? peek_end(sk) -- 1
-- ? peek_end(sk,2) -- 2
-- ? peek_end(sk,3) -- 3
-- ? peek_end(sk,4) -- *error*
-- ? peek_end(sk, size(sk)) -- 3 (top item)
-- </eucode>
--
-- See Also:
-- [[:pop]], [[:top]], [[:is_empty]], [[:size]], [[:peek_top]]

public function peek_end(stack sk, integer idx = 1)
	sequence t
	
	t = ram_space[sk][data]
	if idx < 0 or idx > length(t) then
		if length(t) = 0 then
			crash("stack is empty, cannot peek_end")
		else
			crash("stack idx (%d) out of bounds in peek_end()", {idx})
		end if
	end if
	idx = length(t) - idx + 1

	object top_obj = t[idx]
	return top_obj
end function

--**
-- Swap the top two elements of a stack
--
-- Parameters:
--		# ##sk##: the stack to swap.
--
-- Returns:
-- A copy of the original **stack**, with the top two elements swapped.
--
-- Comments:
-- * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
-- * For ##FILO## stacks, the top item is the newest item in the stack.
--
-- Errors:
-- If the stack has less than two elements, an error occurs.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- push(sk, "")
-- ? peek_top(sk,1)  -- ""
-- ? peek_top(sk,2)  -- 2.3
-- swap(sk)
-- ? peek_top(sk,1)  -- 2.3
-- ? peek_top(sk,2)  -- ""
-- </eucode>
--
-- Example 2:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, 2.3)
-- push(sk, "")
-- ? peek_top(sk,1)  -- 5
-- ? peek_top(sk,2)  -- "abc"
-- swap(sk)
-- ? peek_top(sk,1)  -- "abc"
-- ? peek_top(sk,2)  -- 5
-- </eucode>
--

public procedure swap(stack sk)
	sequence t
	
	t = ram_space[sk][data]
	if length(t) < 2 then
		crash("swap() needs at least 2 items in the stack", {})
	end if

	object tmp = t[$]
	t[$] = t[$-1]
	t[$-1] = tmp
	ram_space[sk][data] = t
end procedure

--**
-- Repeat the top element of a stack.
--
-- Parameters:
--		# ##sk##: the stack.
--
-- Side effects:
--   The value of top() is pushed onto the stack, thus
--   the stack size grows by one.
--
-- Comments:
-- * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
-- * For ##FILO## stacks, the top item is the newest item in the stack.
--
-- Errors:
--   If the stack has no elements, an error occurs.
--
-- Example 1:
-- <eucode>
-- stack sk = new(FILO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, "")
-- dup(sk)
-- ? peek_top(sk,1)  -- ""
-- ? peek_top(sk,2)  -- "abc"
-- ? size(sk)  -- 3
-- dup(sk)
-- ? peek_top(sk,1)  -- ""
-- ? peek_top(sk,2)  -- ""
-- ? peek_top(sk,3)  -- "abc"
-- ? size(sk)  -- 4
-- </eucode>
--
-- Example 1:
-- <eucode>
-- stack sk = new(FIFO)
-- push(sk,5)
-- push(sk,"abc")
-- push(sk, "")
-- dup(sk)
-- ? peek_top(sk,1)  -- 5
-- ? peek_top(sk,2)  -- "abc"
-- ? size(sk)  -- 3
-- dup(sk)
-- ? peek_top(sk,1)  -- 5
-- ? peek_top(sk,2)  -- 5
-- ? peek_top(sk,3)  -- "abc"
-- ? size(sk)  -- 4
-- </eucode>
--

public procedure dup(stack sk)
	sequence t
	
	t = ram_space[sk][data]
	if length(t) = 0 then
		crash("dup() needs at least one item in the stack", {})
	end if

	ram_space[sk][data] = append(t, t[$])
end procedure

--**
-- Update a value on the stack
--
-- Parameters:
--   # ##sk##: the stack being queried
--   # ##val##: an object, the value to place on the stack
--   # ##idx##: an integer, the place to inspect. The default is 1 (the top item)
--
-- Errors:
-- If the supplied value of ##idx## does not correspond to an existing element, an error occurs.
--
-- Comments:
-- * For ##FIFO## stacks (queues), the top item is the oldest item in the stack.
-- * For ##FILO## stacks, the top item is the newest item in the stack.
--
-- ##idx## can be less than 1, in which case it refers to an element relative
-- to the end of the stack. Thus, 0 stands for the end element.
--
-- See Also:
-- [[:size]], [[:top]]

public procedure set(stack sk, object val, integer idx = 1)
	sequence o = ram_space[sk][data]
	integer oidx = idx

	if idx <= 0 then
		-- number from end
		idx = 1 - idx
	else
		idx = length(o) - idx + 1
	end if
	
	if idx < 1 or idx > length(o) then
		crash("stack index (%d) out of bounds for set()", oidx)
	end if
	
	ram_space[sk][data][idx] = val
end procedure

--**
-- Wipe out a stack.
--
-- Parameters:
--   # ##sk##: the stack to clear.
--
-- Side effect:
--   The stack contents is emptied.
--
-- See Also:
-- [[:new]], [[:is_empty]]

public procedure clear(stack sk)
	ram_space[sk][data] = {}
end procedure
