--****
-- == Map (hash table)
--
-- <<LEVELTOC level=2 depth=4>>
--
-- A map is a special array, often called an associative array or dictionary,
-- in which the index to the data can be any Euphoria object and not just
-- an integer. These sort of indexes are also called keys.
-- For example we can code things like this...
-- <eucode>
--    custrec = new() -- Create a new map
--    put(custrec, "Name", "Joe Blow")
--    put(custrec, "Address", "555 High Street")
--    put(custrec, "Phone", 555675632)
-- </eucode>
-- This creates three elements in the map, and they are indexed by "Name", 
-- "Address" and "Phone", meaning that to get the data associated with those
-- keys we can code ...
-- <eucode>
--    object data = get(custrec, "Phone")
--    -- data now set to 555675632
-- </eucode>
-- **Note~:** Only one instance of a given key can exist in a given map, meaning
-- for example, we couldn't have two separate "Name" values in the above //custrec//
-- map.
--
-- Maps automatically grow to accommodate all the elements placed into it.
--
-- Associative arrays can be implemented in many different ways, depending
-- on what efficiency trade-offs have been made. This implementation allows
-- you to decide if you want a //small// map or a //large// map.\\
-- ;small map: Faster for small numbers of elements. Speed is usually proportional
-- to the number of elements.
-- ;large map: Faster for large number of elements. Speed is usually the same
-- regardless of how many elements are in the map. The speed is often slower than
-- a small map.\\
-- **Note~:** If the number of elements placed into a //small// map take it over
-- the initial size of the map, it is automatically converted to a //large// map.
--

namespace map

include std/hash.e
include std/datetime.e
include std/error.e
include std/eumem.e
include std/get.e
include std/io.e
include std/math.e
include std/pretty.e
include std/primes.e
include std/search.e
include std/serialize.e
include std/sort.e
include std/stats.e as stats
include std/text.e
include std/types.e

include euphoria/info.e

enum
	 TYPE_TAG,       -- ==> 'tag' for map type
	 ELEMENT_COUNT,  -- ==> elementCount
	 IN_USE,         -- ==> count of non-empty buckets
	 MAP_TYPE,       -- ==> Either SMALLMAP or LARGEMAP
	 KEY_BUCKETS,    -- ==> bucket[] --> bucket = {key[], value[]}
	 VALUE_BUCKETS,  -- ==> bucket[] --> bucket = {key[], value[]}
	 KEY_LIST   = 5, -- ==> Small map keys
	 VALUE_LIST,     -- ==> Small map values
	 FREE_LIST       -- ==> Small map freespace

constant type_is_map   = "Eu:StdMap"


--****
-- === Operation codes for put

public enum
	PUT,
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	APPEND,
	CONCAT,
	LEAVE

constant INIT_OPERATIONS = { PUT, APPEND, CONCAT, ADD, SUBTRACT, LEAVE }

--****
-- === Types of Maps

public constant SMALLMAP = 's'
public constant LARGEMAP = 'L'

integer threshold_size = 23

-- This is a improbable value used to initialize a small map's keys list. 
constant init_small_map_key = -75960.358941

--****
-- === Types
--

--**
-- Defines the datatype 'map'
--
-- Comments:
-- Used when declaring a map variable.
--
-- Example:
--   <eucode>
--   map SymbolTable = new() -- Create a new map to hold the symbol table.
--   </eucode>

public type map(object obj_p)
-- Must be a valid EuMem pointer.
	if not eumem:valid(obj_p, "") then return 0 end if
	
-- Large maps have six data elements:
--   (1) Data type magic value
--   (2) Count of elements 
--   (3) Number of slots being used
--   (4) The map type
--   (5) Key Buckets 
--   (6) Value Buckets
-- A bucket contains one or more lists of items.

-- Small maps have seven data elements:
--   (1) Data type magic value
--   (2) Count of elements 
--   (3) Number of slots being used
--   (4) The map type
--   (5) Sequence of keys
--   (6) Sequence of values, in the same order as the keys.
--   (7) Sequence. A Free space map.
	object m_
	
	m_ = eumem:ram_space[obj_p]
	if not sequence(m_) then return 0 end if
	if length(m_) < 6 then return 0 end if
	if length(m_) > 7 then return 0 end if
	if not equal(m_[TYPE_TAG], type_is_map) then return 0 end if
	if not integer(m_[ELEMENT_COUNT]) then return 0 end if
	if m_[ELEMENT_COUNT] < 0 		then return 0 end if
	if not integer(m_[IN_USE]) then return 0 end if
	if m_[IN_USE] < 0		then return 0 end if
	if equal(m_[MAP_TYPE],SMALLMAP) then
		if atom(m_[KEY_LIST]) 		then return 0 end if
		if atom(m_[VALUE_LIST]) 		then return 0 end if
		if atom(m_[FREE_LIST]) 		then return 0 end if
		if length(m_[KEY_LIST]) = 0  then return 0 end if
		if length(m_[KEY_LIST]) != length(m_[VALUE_LIST]) then return 0 end if
		if length(m_[KEY_LIST]) != length(m_[FREE_LIST]) then return 0 end if
	elsif  equal(m_[MAP_TYPE],LARGEMAP) then
		if atom(m_[KEY_BUCKETS]) 		then return 0 end if
		if atom(m_[VALUE_BUCKETS]) 		then return 0 end if
		if length(m_[KEY_BUCKETS]) != length(m_[VALUE_BUCKETS])	then return 0 end if
	else
		return 0
	end if
	return 1
end type

constant maxInt = #3FFFFFFF

--****
-- === Routines
--

--**
-- Calculate a Hashing value from the supplied data.
--
-- Parameters:
--   # ##key_p## : The data for which you want a hash value calculated.
--   # ##max_hash_p## :  The returned value will be no larger than this value.
--
-- Returns:
--   An **integer**, the value of which depends only on the supplied data.
--
-- Comments:
--   This is used whenever you need a single number to represent the data you supply.
--   It can calculate the number based on all the data you give it, which can be
--   an atom or sequence of any value.
--
-- Example 1:
--   <eucode>
--   integer h1
--   -- calculate a hash value and ensure it will be a value from 1 to 4097.
--   h1 = calc_hash( symbol_name, 4097 )
--   </eucode>
--

public function calc_hash(object key_p, integer max_hash_p)
	integer ret_

    ret_ = hash(key_p, stdhash:HSIEH30)
	return remainder(ret_, max_hash_p) + 1 -- 1-based

end function

--**
-- Gets or Sets the threshold value that determines at what point a small map
-- converts into a large map structure. Initially this has been set to 23,
-- meaning that maps up to 23 elements use the //small map// structure.
--
-- Parameters:
-- # ##new_value_p## : If this is greater than zero then it **sets** the threshold
-- value.
--
-- Returns:
--  An **integer**, the current value (when ##new_value_p## is less than 1) or the
-- old value prior to setting it to ##new_value_p##.
--

public function threshold(integer new_value_p = 0)

	if new_value_p < 1 then
		return threshold_size
	end if

	integer old_value_ = threshold_size
	threshold_size = new_value_p
	return old_value_
		
end function
	
--**
-- Determines the type of the map.
--
-- Parameters:
-- # ##m## : A map
--
-- Returns:
-- An **integer**, Either //SMALLMAP// or //LARGEMAP//
--

public function type_of(map the_map_p)
	return eumem:ram_space[the_map_p][MAP_TYPE]
end function
	
--**
-- Changes the width, i.e. the number of buckets, of a map. Only effects
-- //large// maps.
--
-- Parameters:
--   # ##m## : the map to resize
--   # ##requested_bucket_size_p## : a lower limit for the new size.
--
-- Comment:
-- If ##requested_bucket_size_p## is not greater than zero, a new width is automatically derived from the current one.
--
-- See Also:
--		[[:statistics]], [[:optimize]]

public procedure rehash(integer the_map_p, integer requested_bucket_size_p = 0)
	integer size_
	integer index_2_
	sequence old_key_buckets_
	sequence old_val_buckets_
	sequence new_key_buckets_
	sequence new_val_buckets_
	object key_
	object value_
	integer pos
	sequence new_keys
	integer in_use
	integer elem_count
	
	if eumem:ram_space[the_map_p][MAP_TYPE] = SMALLMAP then
		return -- small maps are not hashed.
	end if
	
	if requested_bucket_size_p <= 0 then
		-- grow bucket size_
		size_ = floor(length(eumem:ram_space[the_map_p][KEY_BUCKETS]) * 3.5) + 1
	else
		size_ = requested_bucket_size_p
	end if
	
	size_ = primes:next_prime(size_, -size_, 2)	-- Allow up to 2 seconds to calc next prime.
	if size_ < 0 then
		return  -- don't do anything. New size would take too long.
	end if

	old_key_buckets_ = eumem:ram_space[the_map_p][KEY_BUCKETS]
	old_val_buckets_ = eumem:ram_space[the_map_p][VALUE_BUCKETS]
	
	-- Preallocate buckets to be the (current threshold length + 1) each.
	-- The last element in each keys bucket is an index to where the
	-- next key/value is to be stored. 
	new_key_buckets_ = repeat(repeat(1, threshold_size + 1), size_)
	new_val_buckets_ = repeat(repeat(0, threshold_size), size_)
	
	elem_count = eumem:ram_space[the_map_p][ELEMENT_COUNT]
	in_use = 0
	
	eumem:ram_space[the_map_p] = 0
	for index = 1 to length(old_key_buckets_) do
		for entry_idx = 1 to length(old_key_buckets_[index]) do
			-- Get existing key/value pair.
			key_ = old_key_buckets_[index][entry_idx]
			value_ = old_val_buckets_[index][entry_idx]
			
			-- calc the key's new hash value.
			index_2_ = calc_hash(key_, size_)
			
			-- cache the relevant set of keys
			new_keys = new_key_buckets_[index_2_]
			
			-- grab the next position index
			pos = new_keys[$]
			if length(new_keys) = pos then
				-- the set of keys is full now, so we expand it and the value set too.
				new_keys &= repeat(pos, threshold_size)
				new_val_buckets_[index_2_] &= repeat(0, threshold_size)
			end if
			-- store the key and value
			new_keys[pos] = key_
			new_val_buckets_[index_2_][pos] = value_
			
			-- increment the index.
			new_keys[$] = pos + 1
			
			-- put back the cached keys
			new_key_buckets_[index_2_] = new_keys
			
			if pos = 1 then
				-- count the number of buckets actually in use.
				in_use += 1
			end if
		end for
	end for

	-- Ensure each bucket is trimmed to the right count	for it.
	for index = 1 to length(new_key_buckets_) do
		pos = new_key_buckets_[index][$]
		new_key_buckets_[index] = remove(new_key_buckets_[index], pos, 
				length(new_key_buckets_[index]))
		new_val_buckets_[index] = remove(new_val_buckets_[index], pos, 
				length(new_val_buckets_[index]))
	end for

	eumem:ram_space[the_map_p] = { 
		type_is_map, elem_count, in_use, LARGEMAP, new_key_buckets_, new_val_buckets_ 
	}
end procedure

--**
-- Create a new map data structure
--
-- Parameters:
--		# ##initial_size_p## : An estimate of how many initial elements will be stored
--   in the map. If this value is less than the [[:threshold]] value, the map
--   will initially be a //small// map otherwise it will be a //large// map.
--
-- Returns:
--		An empty **map**.
--
-- Comments:
--   A new object of type map is created.  The resources allocated for the map will
--   be automatically cleaned up if the reference count of the returned value drops
--  to zero, or if passed in a call to [[:delete]].
--
-- Example 1:
--   <eucode>
--   map m = new()  -- m is now an empty map
--   map x = new(threshold()) -- Forces a small map to be initialized
--   x = new()    -- the resources for the map previously stored in x are released automatically
--   delete( m )  -- the resources for the map are released
--   </eucode>

public function new(integer initial_size_p = 690)
	integer buckets_
	sequence new_map_
	atom temp_map_

	if initial_size_p < 3 then
		initial_size_p = 3
	end if
	
	if initial_size_p > threshold_size then
		-- Return a large map
		buckets_ = floor((initial_size_p + threshold_size - 1) / threshold_size)
		buckets_ = primes:next_prime(buckets_)
		
		new_map_ = { type_is_map, 0, 0, LARGEMAP, repeat({}, buckets_), repeat({}, buckets_) }
	else
		-- Return a small map
		new_map_ = {
			type_is_map, 0,0, SMALLMAP, repeat(init_small_map_key, initial_size_p), 
				repeat(0, initial_size_p), repeat(0, initial_size_p)
		}
	end if
	
	temp_map_ = eumem:malloc()
	eumem:ram_space[temp_map_] = new_map_
	
	return temp_map_
end function

--**
-- Returns either the supplied map or a new map.
--
-- Parameters:
--      # ##the_map_p## : An object, that could be an existing map
--		# ##initial_size_p## : An estimate of how many initial elements will be stored
--   in a new map.
--
-- Returns:
-- A **map**,
--		If ##m## is an existing map then it is returned otherwise this 
--      returns a new empty **map**.
--
-- Comments:
--   This is used to return a new map if the supplied variable isn't already
--   a map.
--
-- Example 1:
--   <eucode>
--   map m = new_extra( foo() ) -- If foo() returns a map it is used, otherwise
--                              --  a new map is created.
--   </eucode>
--

public function new_extra(object the_map_p, integer initial_size_p = 690)
	if map(the_map_p) then
		return the_map_p
	else
		return new(initial_size_p)
	end if
end function

--**
-- Compares two maps to test equality.
--
-- Parameters:
--		# ##map_1_p## : A map
--		# ##map_2_p## : A map
--      # ##scope_p## : An integer that specifies what to compare.
--        ** 'k' or 'K' to only compare keys.
--        ** 'v' or 'V' to only compare values.
--        ** 'd' or 'D' to compare both keys and values. This is the default.
--
-- Returns:
--   An **integer**,
--   * -1 if they are not equal.
--   * 0 if they are literally the same map.
--   * 1 if they contain the same keys and/or values.
--
-- Example 1:
--   <eucode>
--   map map_1_p = foo()
--   map map_2_p = bar()
--   if compare(map_1_p, map_2_p, 'k') >= 0 then
--        ... -- two maps have the same keys
--   </eucode>
--

public function compare(map map_1_p, map map_2_p, integer scope_p = 'd')
	sequence data_set_1_
	sequence data_set_2_

	if map_1_p = map_2_p then
		return 0
	end if
	
	switch scope_p do
		case 'v', 'V' then
			data_set_1_ = stdsort:sort(values(map_1_p))
			data_set_2_ = stdsort:sort(values(map_2_p))
			
		case 'k', 'K' then
			data_set_1_ = keys(map_1_p, 1)
			data_set_2_ = keys(map_2_p, 1)
			
		case else
			data_set_1_ = pairs(map_1_p, 1)
			data_set_2_ = pairs(map_2_p, 1)

	end switch
				
	if equal(data_set_1_, data_set_2_) then
		return 1
	end if
	
	return -1
	
end function

--**
-- Check whether map has a given key.
--
-- Parameters:
-- 		# ##the_map_p## : the map to inspect
--		# ##the_key_p## : an object to be looked up
--
-- Returns:
--		An **integer**, 0 if not present, 1 if present.
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, "name", "John")
--   ? has(the_map_p, "name") -- 1
--   ? has(the_map_p, "age")  -- 0
--   </eucode>
--
-- See Also:
--   [[:get]]
--

public function has(integer the_map_p, object the_key_p)
	integer index_
	integer pos_
	integer from_
	
	if eumem:ram_space[the_map_p][MAP_TYPE] = LARGEMAP then
		index_ = calc_hash(the_key_p, length(eumem:ram_space[the_map_p][KEY_BUCKETS]))
		pos_ = find(the_key_p, eumem:ram_space[the_map_p][KEY_BUCKETS][index_])
	else
		if equal(the_key_p, init_small_map_key) then
			from_ = 1
			
			while from_ > 0 do
				pos_ = find(the_key_p, eumem:ram_space[the_map_p][KEY_LIST], from_)
				if pos_ then
					if eumem:ram_space[the_map_p][FREE_LIST][pos_] = 1 then
						return 1
					end if
				else
					return 0
				end if
				
				from_ = pos_ + 1
			end while
		else
			pos_ = find(the_key_p, eumem:ram_space[the_map_p][KEY_LIST])
		end if
	end if
	
	return (pos_  != 0)	
end function

--**
-- Retrieves the value associated to a key in a map.
--
-- Parameters:
--		# ##the_map_p## : the map to inspect
--		# ##the_key_p## : an object, the the_key_p being looked tp
--		# ##default_value_p## : an object, a default value returned if ##the_key_p## not found.
--                         The default is 0.
--
-- Returns:
--		An **object**, the value that corresponds to ##the_key_p## in ##the_map_p##. 
--      If ##the_key_p## is not in ##the_map_p##, ##default_value_p## is returned instead.
--
-- Example 1:
--   <eucode>
--   map ages
--   ages = new()
--   put(ages, "Andy", 12)
--   put(ages, "Budi", 13)
--
--   integer age
--   age = get(ages, "Budi", -1)
--   if age = -1 then
--       puts(1, "Age unknown")
--   else
--       printf(1, "The age is %d", age)
--   end if
--   </eucode>
--
-- See Also:
--   [[:has]]
--

public function get(integer the_map_p, object the_key_p, object default_value_p = 0)
	integer bucket_
	integer pos_
	integer from_
	
	sequence themap
	
	themap = eumem:ram_space[the_map_p]
	if themap[MAP_TYPE] = LARGEMAP then
		sequence thekeys
		thekeys = themap[KEY_BUCKETS]
		bucket_ = calc_hash(the_key_p, length(thekeys))
		pos_ = find(the_key_p, thekeys[bucket_])
		if pos_ > 0 then
			return themap[VALUE_BUCKETS][bucket_][pos_]
		end if
		
		return default_value_p
	else
		if equal(the_key_p, init_small_map_key) then
			from_ = 1
			
			while from_ > 0 do
				pos_ = find(the_key_p, themap[KEY_LIST], from_)
				if pos_ then
					if themap[FREE_LIST][pos_] = 1 then
						return themap[VALUE_LIST][pos_]
					end if
				else
					return default_value_p
				end if
				
				from_ = pos_ + 1
			end while
		else
			pos_ = find(the_key_p, themap[KEY_LIST])
			if pos_  then
				return themap[VALUE_LIST][pos_]
			end if
		end if
	end if
	
	return default_value_p
end function

--**
-- Returns the value that corresponds to the object ##the_keys_p## in the nested map 
-- the_map_p.  ##the_keys_p## is a sequence of keys.  If any key is not in the map, the 
-- object default_value_p is returned instead.
--

public function nested_get( map the_map_p, sequence the_keys_p, object default_value_p = 0)
	for i = 1 to length( the_keys_p ) - 1 do
		object val_ = get( the_map_p, the_keys_p[1], 0 )

		if not map( val_ ) then
			-- not a map
			return default_value_p
		else
			the_map_p = val_
			the_keys_p = the_keys_p[2..$]
		end if
	end for
	
	return get( the_map_p, the_keys_p[1], default_value_p )
end function

--**
-- Adds or updates an entry on a map.
--
-- Parameters:
--		# ##the_map_p## : the map where an entry is being added or updated
--		# ##the_key_p## : an object, the the_key_p to look up
--		# ##the_value_p## : an object, the value to add, or to use for updating.
--		# ##operation## : an integer, indicating what is to be done with ##the_value_p##. Defaults to PUT.
--		# ##trigger_p## : an integer. Default is the current threshold size. See Comments for details.
--
-- Comments:
-- * The operation parameter can be used to modify the existing value.  Valid operations are: 
-- 
-- ** ##PUT## ~--  This is the default, and it replaces any value in there already
-- ** ##ADD## ~--  Equivalent to using the += operator 
-- ** ##SUBTRACT## ~--  Equivalent to using the -= operator 
-- ** ##MULTIPLY## ~--  Equivalent to using the *= operator
-- ** ##DIVIDE## ~-- Equivalent to using the /= operator 
-- ** ##APPEND## ~-- Appends the value to the existing data 
-- ** ##CONCAT## ~-- Equivalent to using the &= operator
-- ** ##LEAVE## ~--  If it already exists, the current value is left unchanged
--               otherwise the new value is added to the map.
--
-- * The //trigger// parameter is used when you need to keep the average 
--     number of keys in a hash bucket to a specific maximum. The //trigger// 
--     value is the maximum allowed. Each time a //put// operation increases
--     the hash table's average bucket size to be more than the //trigger// value
--     the table is expanded by a factor of 3.5 and the keys are rehashed into the
--     enlarged table. This can be a time intensive action so set the value
--     to one that is appropriate to your application. 
--     ** By keeping the average bucket size to a certain maximum, it can
--        speed up lookup times. 
--     ** If you set the //trigger// to zero, it will not check to see if
--        the table needs reorganizing. You might do this if you created the original
--        bucket size to an optimal value. See [[:new]] on how to do this.
--
-- Example 1:
--   <eucode>
--   map ages
--   ages = new()
--   put(ages, "Andy", 12)
--   put(ages, "Budi", 13)
--   put(ages, "Budi", 14)
--
--   -- ages now contains 2 entries: "Andy" => 12, "Budi" => 14
--   </eucode>
--
-- See Also:
--		[[:remove]], [[:has]],  [[:nested_put]]
--

public procedure put(integer the_map_p, object the_key_p, object the_value_p, 
			integer operation_p = map:PUT, integer trigger_p = threshold_size)
	integer index_
	integer bucket_
	atom average_length_
	integer from_

	sequence map_data = eumem:ram_space[the_map_p]
	
	eumem:ram_space[the_map_p] = 0
	if map_data[MAP_TYPE] = LARGEMAP then
		bucket_ = calc_hash(the_key_p,  length(map_data[KEY_BUCKETS]))
		index_ = find(the_key_p, map_data[KEY_BUCKETS][bucket_])
		if index_ > 0 then
			-- The the_value_p already exists.
			switch operation_p do
				case PUT then
					map_data[VALUE_BUCKETS][bucket_][index_] = the_value_p
					
				case ADD then
					map_data[VALUE_BUCKETS][bucket_][index_] += the_value_p
					
				case SUBTRACT then
					map_data[VALUE_BUCKETS][bucket_][index_] -= the_value_p
					
				case MULTIPLY then
					map_data[VALUE_BUCKETS][bucket_][index_] *= the_value_p
					
				case DIVIDE then
					map_data[VALUE_BUCKETS][bucket_][index_] /= the_value_p
					
				case APPEND then
					sequence data = map_data[VALUE_BUCKETS][bucket_][index_]
					data = append( data, the_value_p )
					map_data[VALUE_BUCKETS][bucket_][index_] = data
					
				case CONCAT then
					map_data[VALUE_BUCKETS][bucket_][index_] &= the_value_p
					
				case LEAVE then
					-- Do nothing
					operation_p = operation_p
					
				case else
					error:crash("Unknown operation given to map.e:put()")
					
			end switch
			
			eumem:ram_space[the_map_p] = map_data
			
			return
		end if

		if not eu:find(operation_p, INIT_OPERATIONS) then
				error:crash("Inappropriate initial operation given to map.e:put()")
		end if
		
		if operation_p = LEAVE then
			eumem:ram_space[the_map_p] = map_data
			
			return
		end if
		
		-- write new entry
		if operation_p = APPEND then
			-- If appending, then the user wants the the_value_p to be an element, not the entire thing
			the_value_p = { the_value_p }
		end if

		map_data[IN_USE] += (length(map_data[KEY_BUCKETS][bucket_]) = 0)
		map_data[ELEMENT_COUNT] += 1 -- elementCount		
		
		sequence tmp_seqk
		tmp_seqk = map_data[KEY_BUCKETS][bucket_]
		map_data[KEY_BUCKETS][bucket_] = 0
		tmp_seqk = append( tmp_seqk, the_key_p)
		map_data[KEY_BUCKETS][bucket_] = tmp_seqk

		sequence tmp_seqv
		tmp_seqv = map_data[VALUE_BUCKETS][bucket_]
		map_data[VALUE_BUCKETS][bucket_] = 0
		tmp_seqv = append( tmp_seqv, the_value_p)
		map_data[VALUE_BUCKETS][bucket_] = tmp_seqv
		
		eumem:ram_space[the_map_p] = map_data
		if trigger_p > 0 then
			average_length_ = map_data[ELEMENT_COUNT] / map_data[IN_USE]
			if (average_length_ >= trigger_p) then
				map_data = {}
				rehash(the_map_p)
			end if
		end if
		
		return
	else -- Small Map
		-- First, check to see if the key is already in the map.
		if equal(the_key_p, init_small_map_key) then
			-- Special case when the key happens to be the magic init value.
			-- We have to double check the free list whenever we have a hit on the key.
			from_ = 1
			while index_ > 0 with entry do
				if map_data[FREE_LIST][index_] = 1 then
					exit
				end if
				
				from_ = index_ + 1
			  entry
				index_ = find(the_key_p, map_data[KEY_LIST], from_)
			end while
		else
			index_ = find(the_key_p, map_data[KEY_LIST])
		end if
		
		-- Did we find the key?
		if index_ = 0 then
			if not eu:find(operation_p, INIT_OPERATIONS) then
					error:crash("Inappropriate initial operation given to map.e:put()")
			end if
			
			-- No, so add it.
			index_ = find(0, map_data[FREE_LIST])
			if index_ = 0 then
				-- No room left, so now it becomes a large map.
				eumem:ram_space[the_map_p] = map_data
				map_data = {}
				convert_to_large_map(the_map_p)
				put(the_map_p, the_key_p, the_value_p, operation_p, trigger_p)
				return
			end if
			
			map_data[KEY_LIST][index_] = the_key_p
			map_data[FREE_LIST][index_] = 1
			map_data[IN_USE] += 1
			map_data[ELEMENT_COUNT] += 1
			
			if operation_p = APPEND then
				the_value_p = { the_value_p }
			end if
			
			if operation_p != LEAVE then
				operation_p = PUT	-- Initially, nearly everything is a PUT.
			end if
		end if
		
		switch operation_p do
			case PUT then
				map_data[VALUE_LIST][index_] = the_value_p
				
			case ADD then
				map_data[VALUE_LIST][index_] += the_value_p
				
			case SUBTRACT then
				map_data[VALUE_LIST][index_] -= the_value_p
				
			case MULTIPLY then
				map_data[VALUE_LIST][index_] *= the_value_p
				
			case DIVIDE then
				map_data[VALUE_LIST][index_] /= the_value_p
				
			case APPEND then
				map_data[VALUE_LIST][index_] = append( map_data[VALUE_LIST][index_], the_value_p )
				
			case CONCAT then
				map_data[VALUE_LIST][index_] &= the_value_p
				
			case LEAVE then
				-- do nothing
				operation_p = operation_p
				
			case else
				error:crash("Unknown operation given to map.e:put()")
				
		end switch
		
		eumem:ram_space[the_map_p] = map_data
		
		return
		
	end if
end procedure


--**
-- Adds or updates an entry on a map.
--
-- Parameters:
--		# ##the_map_p## : the map where an entry is being added or updated
--		# ##the_keys_p## : a sequence of keys for the nested maps
--		# ##the_value_p## : an object, the value to add, or to use for updating.
--		# ##operation_p## : an integer, indicating what is to be done with ##value##. Defaults to PUT.
--		# ##trigger_p## : an integer. Default is the current threshold size. See Comments for details.
--
-- Valid operations are: 
-- 
-- * ##PUT## ~--  This is the default, and it replaces any value in there already
-- * ##ADD## ~--  Equivalent to using the += operator 
-- * ##SUBTRACT## ~--  Equivalent to using the -= operator 
-- * ##MULTIPLY## ~--  Equivalent to using the *= operator 
-- * ##DIVIDE## ~-- Equivalent to using the /= operator 
-- * ##APPEND## ~-- Appends the value to the existing data 
-- * ##CONCAT## ~-- Equivalent to using the &= operator
--
-- Comments:
--   * If existing entry with the same key is already in the map, the value of the entry is updated.
--   * The //trigger// parameter is used when you need to keep the average 
--     number of keys in a hash bucket to a specific maximum. The //trigger// 
--     value is the maximum allowed. Each time a //put// operation increases
--     the hash table's average bucket size to be more than the //trigger// value
--     the table is expanded by a factor 3.5 and the keys are rehashed into the
--     enlarged table. This can be a time intensive action so set the value
--     to one that is appropriate to your application. 
--     ** By keeping the average bucket size to a certain maximum, it can
--        speed up lookup times. 
--     ** If you set the //trigger// to zero, it will not check to see if
--        the table needs reorganizing. You might do this if you created the original
--        bucket size to an optimal value. See [[:new]] on how to do this.
--
-- Example 1:
-- <eucode>
-- map city_population
-- city_population = new()
-- nested_put(city_population, {"United States", "California", "Los Angeles"},
--     3819951 )
-- nested_put(city_population, {"Canada",        "Ontario",    "Toronto"},     
--     2503281 )
-- </eucode>
--
-- See also:
--   [[:put]]
--

public procedure nested_put( map the_map_p, sequence the_keys_p, object the_value_p, 
			integer operation_p = PUT, integer trigger_p = threshold_size )
	atom temp_map_

	if length( the_keys_p ) = 1 then
		put( the_map_p, the_keys_p[1], the_value_p, operation_p, trigger_p )
	else
		temp_map_ = new_extra( get( the_map_p, the_keys_p[1] ) )
		nested_put( temp_map_, the_keys_p[2..$], the_value_p, operation_p, trigger_p )
		put( the_map_p, the_keys_p[1], temp_map_, PUT, trigger_p )
	end if
end procedure

--**
-- Remove an entry with given key from a map.
--
-- Parameters:
--		# ##the_map_p## : the map to operate on
--		# ##key## : an object, the key to remove.
--
-- Comments:
--   * If ##key## is not on ##the_map_p##, the ##the_map_p## is returned unchanged.
--   * If you need to remove all entries, see [[:clear]]
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, "Amy", 66.9)
--   remove(the_map_p, "Amy")
--   -- the_map_p is now an empty map again
--   </eucode>
--
-- See Also:
--		[[:clear]], [[:has]]
--

public procedure remove(map the_map_p, object the_key_p)
	integer index_
	integer bucket_
	sequence temp_map_
	integer from_
	
	temp_map_ = eumem:ram_space[the_map_p]
	if temp_map_[MAP_TYPE] = LARGEMAP then
		bucket_ = calc_hash(the_key_p, length(temp_map_[KEY_BUCKETS]))
	
		index_ = find(the_key_p, temp_map_[KEY_BUCKETS][bucket_])
		if index_ != 0 then
			temp_map_[ELEMENT_COUNT] -= 1
			if length(temp_map_[KEY_BUCKETS][bucket_]) = 1 then
				temp_map_[IN_USE] -= 1
				temp_map_[KEY_BUCKETS][bucket_] = {}
				temp_map_[VALUE_BUCKETS][bucket_] = {}
			else
				temp_map_[VALUE_BUCKETS][bucket_] = temp_map_[VALUE_BUCKETS][bucket_][1 .. index_-1] & 
						temp_map_[VALUE_BUCKETS][bucket_][index_+1 .. $]
				temp_map_[KEY_BUCKETS][bucket_] = temp_map_[KEY_BUCKETS][bucket_][1 .. index_-1] & 
						temp_map_[KEY_BUCKETS][bucket_][index_+1 .. $]
			end if
			
			if temp_map_[ELEMENT_COUNT] < floor(51 * threshold_size / 100) then
				eumem:ram_space[the_map_p] = temp_map_
				convert_to_small_map(the_map_p)
				
				return
			end if
		end if
	else
		from_ = 1
		
		while from_ > 0 do
			index_ = find(the_key_p, temp_map_[KEY_LIST], from_)
			if index_ then
				if temp_map_[FREE_LIST][index_] = 1 then
					temp_map_[FREE_LIST][index_] = 0
					temp_map_[KEY_LIST][index_] = init_small_map_key
					temp_map_[VALUE_LIST][index_] = 0
					temp_map_[IN_USE] -= 1
					temp_map_[ELEMENT_COUNT] -= 1
				end if
			else
				exit
			end if
			
			from_ = index_ + 1
		end while
	end if
	
	eumem:ram_space[the_map_p] = temp_map_
end procedure

--**
-- Remove all entries in a map.
--
-- Parameters:
--		# ##the_map_p## : the map to operate on
--
-- Comments:
--   * This is much faster than removing each entry individually.
--   * If you need to remove just one entry, see [[:remove]]
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, "Amy", 66.9)
--   put(the_map_p, "Betty", 67.8)
--   put(the_map_p, "Claire", 64.1)
--   ...
--   clear(the_map_p)
--   -- the_map_p is now an empty map again
--   </eucode>
--
-- See Also:
--		[[:remove]], [[:has]]
--

public procedure clear(map the_map_p)
	sequence temp_map_

	temp_map_ = eumem:ram_space[the_map_p]
	if temp_map_[MAP_TYPE] = LARGEMAP then
		temp_map_[ELEMENT_COUNT] = 0
		temp_map_[IN_USE] = 0
		temp_map_[KEY_BUCKETS] = repeat({}, length(temp_map_[KEY_BUCKETS]))
		temp_map_[VALUE_BUCKETS] = repeat({}, length(temp_map_[VALUE_BUCKETS]))
	else
		temp_map_[ELEMENT_COUNT] = 0
		temp_map_[IN_USE] = 0
		temp_map_[KEY_LIST] = repeat(init_small_map_key, length(temp_map_[KEY_LIST]))
		temp_map_[VALUE_LIST] = repeat(0, length(temp_map_[VALUE_LIST]))
		temp_map_[FREE_LIST] = repeat(0, length(temp_map_[FREE_LIST]))
	end if

	eumem:ram_space[the_map_p] = temp_map_
end procedure

--**
-- Return the number of entries in a map.
--
-- Parameters:
--   ##the_map_p## : the map being queried
--
-- Returns:
--   An **integer**, the number of entries it has.
--
-- Comments:
--   For an empty map, size will be zero
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   put(the_map_p, 1, "a")
--   put(the_map_p, 2, "b")
--   ? size(the_map_p) -- outputs 2
--   </eucode>
--
-- See Also:
--   [[:statistics]]
--

public function size(map the_map_p)
	return eumem:ram_space[the_map_p][ELEMENT_COUNT]
end function

public enum
	NUM_ENTRIES,
	NUM_IN_USE,
	NUM_BUCKETS,
	LARGEST_BUCKET,
	SMALLEST_BUCKET,
	AVERAGE_BUCKET,
	STDEV_BUCKET

--**
-- Retrieves characteristics of a map.
--
-- Parameters:
--   # ##the_map_p## : the map being queried
--
-- Returns:
--   A  **sequence**, of 7 integers:
--       * ##NUM_ENTRIES## ~-- number of entries
--       * ##NUM_IN_USE## ~-- number of buckets in use
--       * ##NUM_BUCKETS## ~-- number of buckets
--       * ##LARGEST_BUCKET## ~-- size of largest bucket
--       * ##SMALLEST_BUCKET## ~-- size of smallest bucket
--       * ##AVERAGE_BUCKET## ~-- average size for a bucket
--       * ##STDEV_BUCKET## ~-- standard deviation for the bucket length series
--
-- Example 1:
--   <eucode>
--   sequence s = statistics(mymap)
--   printf(1, "The average size of the buckets is %d", s[AVERAGE_BUCKET])
--   </eucode>
--

public function statistics(map the_map_p)
	sequence statistic_set_
	sequence lengths_
	integer length_
	sequence temp_map_
	
	temp_map_ = eumem:ram_space[the_map_p]

	if temp_map_[MAP_TYPE] = LARGEMAP then
		statistic_set_ = { 
			temp_map_[ELEMENT_COUNT], temp_map_[IN_USE], length(temp_map_[KEY_BUCKETS]), 
			0, maxInt, 0, 0
		}
		
		lengths_ = {}
		for i = 1 to length(temp_map_[KEY_BUCKETS]) do
			length_ = length(temp_map_[KEY_BUCKETS][i])
			
			if length_ > 0 then
				if length_ > statistic_set_[LARGEST_BUCKET] then
					statistic_set_[LARGEST_BUCKET] = length_
				end if
				
				if length_ < statistic_set_[SMALLEST_BUCKET] then
					statistic_set_[SMALLEST_BUCKET] = length_
				end if
				
				lengths_ &= length_
			end if
		end for
		
		statistic_set_[AVERAGE_BUCKET] = stats:average(lengths_)
		statistic_set_[STDEV_BUCKET] = stats:stdev(lengths_)
	else
		statistic_set_ = {
			temp_map_[ELEMENT_COUNT], 
			temp_map_[IN_USE], 
			length(temp_map_[KEY_LIST]), 
			length(temp_map_[KEY_LIST]), 
			length(temp_map_[KEY_LIST]), 
			length(temp_map_[KEY_LIST]),
			0
		}
	end if
	
	return statistic_set_
end function

--**
-- Return all keys in a map.
--
-- Parameters:
--   # ##the_map_p##: the map being queried
--   # ##sorted_result##: optional integer. 0 [default] means do not sort the
--                        output and 1 means to sort the output before returning.
--
-- Returns:
--   A **sequence** made of all the keys in the map.
--
-- Comments:
--   If ##sorted_result## is not used, the order of the keys returned is not predicable. 
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, 10, "ten")
--   put(the_map_p, 20, "twenty")
--   put(the_map_p, 30, "thirty")
--   put(the_map_p, 40, "forty")
--
--   sequence keys
--   keys = keys(the_map_p) -- keys might be {20,40,10,30} or some other order
--   keys = keys(the_map_p, 1) -- keys will be {10,20,30,40}
--   </eucode>
--
-- See Also:
--   [[:has]], [[:values]], [[:pairs]]
--

public function keys(map the_map_p, integer sorted_result = 0)
	sequence buckets_
	sequence current_bucket_
	sequence results_
	integer pos_
	sequence temp_map_
	
	temp_map_ = eumem:ram_space[the_map_p]

	results_ = repeat(0, temp_map_[ELEMENT_COUNT])
	pos_ = 1

	if temp_map_[MAP_TYPE] = LARGEMAP then
		buckets_ = temp_map_[KEY_BUCKETS]
		for index = 1 to length(buckets_) do
			current_bucket_ = buckets_[index]
			if length(current_bucket_) > 0 then
				results_[pos_ .. pos_ + length(current_bucket_) - 1] = current_bucket_
				pos_ += length(current_bucket_)
			end if
		end for
	else
		for index = 1 to length(temp_map_[FREE_LIST]) do
			if temp_map_[FREE_LIST][index] !=  0 then
				results_[pos_] = temp_map_[KEY_LIST][index]
				pos_ += 1
			end if
		end for
	end if
	
	if sorted_result then
		return stdsort:sort(results_)
	else
		return results_
	end if
end function

--**
-- Return values, without their keys, from a map.
--
-- Parameters:
--   # ##the_map## : the map being queried
--   # ##keys## : optional, key list of values to return. 
--   # ##default_values## : optional default values for keys list
--
-- Returns:
--   A **sequence**, of all values stored in ##the_map##.
--
-- Comments:
--   * The order of the values returned may not be the same as the putting order. 
--   * Duplicate values are not removed.
--   * You use the ##keys## parameter to return a specific set of values from
--     the map. They are returned in the same order as the ##keys## parameter. If
--     no ##default_values## is given and one is needed, 0 will be used.
--   * If ##default_values## is an atom, it represents the default value for all
--     values in ##keys##.
--   * If ##default_values## is a sequence, and its length is less than ##keys##,
--     then the last item in ##default_values## is used for the rest of the ##keys##.
--
-- Example 1:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, 10, "ten")
--   put(the_map_p, 20, "twenty")
--   put(the_map_p, 30, "thirty")
--   put(the_map_p, 40, "forty")
--
--   sequence values
--   values = values(the_map_p)
--   -- values might be {"twenty","forty","ten","thirty"}
--   -- or some other order
--   </eucode>
--
-- Example 2:
--   <eucode>
--   map the_map_p
--   the_map_p = new()
--   put(the_map_p, 10, "ten")
--   put(the_map_p, 20, "twenty")
--   put(the_map_p, 30, "thirty")
--   put(the_map_p, 40, "forty")
--
--   sequence values
--   values = values(the_map_p, { 10, 50, 30, 9000 })
--   -- values WILL be { "ten", 0, "thirty", 0 }
--   values = values(the_map_p, { 10, 50, 30, 9000 }, {-1,-2,-3,-4})
--   -- values WILL be { "ten", -2, "thirty", -4 }
--   </eucode>
--
-- See Also:
--   [[:get]], [[:keys]], [[:pairs]]
--

public function values(map the_map, object keys=0, object default_values=0)
	if sequence(keys) then
		if atom(default_values) then
			default_values = repeat(default_values, length(keys))
		elsif length(default_values) < length(keys) then
			default_values &= repeat(default_values[$], length(keys) - length(default_values))
		end if

		for i = 1 to length(keys) do
			keys[i] = get(the_map, keys[i], default_values[i])
		end for

		return keys
	end if

	sequence buckets_
	sequence bucket_
	sequence results_
	integer pos_
	sequence temp_map_
	
	temp_map_ = eumem:ram_space[the_map]

	results_ = repeat(0, temp_map_[ELEMENT_COUNT])
	pos_ = 1

	if temp_map_[MAP_TYPE] = LARGEMAP then
		buckets_ = temp_map_[VALUE_BUCKETS]
		for index = 1 to length(buckets_) do
			bucket_ = buckets_[index]
			if length(bucket_) > 0 then
				results_[pos_ .. pos_ + length(bucket_) - 1] = bucket_
				pos_ += length(bucket_)
			end if
		end for
	else
		for index = 1 to length(temp_map_[FREE_LIST]) do
			if temp_map_[FREE_LIST][index] !=  0 then
				results_[pos_] = temp_map_[VALUE_LIST][index]
				pos_ += 1
			end if
		end for
		
	end if

	return results_
end function

--**
--
-- Return all key/value pairs in a map.
--
-- Parameters:
--   # ##the_map_p## : the map to get the data from
--   # ##sorted_result## : optional integer. 0 [default] means do not sort the
--                         output and 1 means to sort the output before returning.
--
-- Returns:
--   A **sequence**, of all key/value pairs stored in ##the_map_p##. Each pair is a 
--   sub-sequence in the form {key, value}
--
-- Comments:
--   If ##sorted_result## is not used, the order of the values returned is not predicable. 
--
-- Example 1:
-- <eucode>
-- map the_map_p
--
-- the_map_p = new()
-- put(the_map_p, 10, "ten")
-- put(the_map_p, 20, "twenty")
-- put(the_map_p, 30, "thirty")
-- put(the_map_p, 40, "forty")
--
-- sequence keyvals
-- keyvals = pairs(the_map_p) 
-- -- might be {{20,"twenty"},{40,"forty"},{10,"ten"},{30,"thirty"}}
--
-- keyvals = pairs(the_map_p, 1) 
-- -- will be {{10,"ten"},{20,"twenty"},{30,"thirty"},{40,"forty"}}
-- </eucode>
--
-- See Also:
--		[[:get]], [[:keys]], [[:values]]
--

public function pairs(map the_map_p, integer sorted_result = 0)
	sequence key_bucket_
	sequence value_bucket_
	sequence results_
	integer pos_
	sequence temp_map_
	
	temp_map_ = eumem:ram_space[the_map_p]

	results_ = repeat({ 0, 0 }, temp_map_[ELEMENT_COUNT])
	pos_ = 1

	if temp_map_[MAP_TYPE] = LARGEMAP then
		for index = 1 to length(temp_map_[KEY_BUCKETS]) do
			key_bucket_ = temp_map_[KEY_BUCKETS][index]
			value_bucket_ = temp_map_[VALUE_BUCKETS][index]
			for j = 1 to length(key_bucket_) do
				results_[pos_][1] = key_bucket_[j]
				results_[pos_][2] = value_bucket_[j]
				pos_ += 1
			end for
		end for
	else
		for index = 1 to length(temp_map_[FREE_LIST]) do
			if temp_map_[FREE_LIST][index] !=  0 then
				results_[pos_][1] = temp_map_[KEY_LIST][index]
				results_[pos_][2] = temp_map_[VALUE_LIST][index]
				pos_ += 1
			end if
		end for	
	end if
	
	if sorted_result then
		return stdsort:sort(results_)
	else
		return results_
	end if
end function

--**
-- Widens a map to increase performance.
--
-- Parameters:
--		# ##the_map_p## : the map being optimized
--		# ##max_p## : an integer, the maximum desired size of a bucket. 
--                    Default is the current threshold size.
--                    This must be 3 or higher.
--      # ##grow_p## : an atom, the factor to grow the number of buckets for each
--                   iteration of rehashing. Default is 1.333. This must be 
--                   greater than 1.
--
-- Comments:
--      This rehashes the map until either the maximum bucket size is less than
--      the desired maximum or the maximum bucket size is less than the largest
--      size statistically expected (mean + 3 standard deviations).
--
-- See Also:
--		[[:statistics]], [[:rehash]]
--

public procedure optimize(map the_map_p, integer max_p = threshold_size, atom grow_p = 1.333)
	sequence stats_
	integer next_guess_
	integer prev_guess
	
	if eumem:ram_space[the_map_p][MAP_TYPE] = LARGEMAP then
		if grow_p < 1 then
			grow_p = 1.333
		end if
		
		if max_p < 3 then
			max_p = 3
		end if
		
		next_guess_ = math:max({1, floor(eumem:ram_space[the_map_p][ELEMENT_COUNT] / max_p)})
		while 1 with entry do
			if stats_[LARGEST_BUCKET] <= max_p then
				exit -- Largest is now smaller than the maximum I wanted.
			end if
			
			if stats_[LARGEST_BUCKET] <= (stats_[STDEV_BUCKET]*3 + stats_[AVERAGE_BUCKET]) then
				exit -- Largest is smaller than is statistically expected.
			end if
			
			prev_guess = next_guess_
			next_guess_ = floor(stats_[NUM_BUCKETS] * grow_p)
			if prev_guess = next_guess_ then
				next_guess_ += 1
			end if
			
		entry
			rehash(the_map_p, next_guess_)
			stats_ = statistics(the_map_p)
		end while
	end if
end procedure

--**
-- Loads a map from a file
--
-- Parameters:
--		# ##file_name_p## : The file to load from. This file may have been created
--                          by the [[:save_map]] function. This can either be a
--                          name of a file or an already opened file handle.
--
-- Returns:
--		Either a **map**, with all the entries found in ##file_name_p##, or **-1**
--      if the file failed to open, or **-2** if the file is incorrectly formatted.
--
-- Comments:
-- If ##file_name_p## is an already opened file handle, this routine will write
-- to that file and not close it. Otherwise, the named file will be created and
-- closed by this routine.
--
-- The input file can be either one created by the [[:save_map]] function or
-- a manually created/edited text file. See [[:save_map]] for details about
-- the required layout of the text file.
--
--
-- Example 1:
-- <eucode>
-- include std/error.e
--
-- object loaded
-- map AppOptions
-- sequence SavedMap = "c:\\myapp\\options.txt"
--
-- loaded = load_map(SavedMap)
-- if equal(loaded, -1) then
--     crash("Map '%s' failed to open", SavedMap)
-- end if
-- 
-- -- By now we know that it was loaded and a new map created,
-- -- so we can assign it to a 'map' variable.
-- AppOptions = loaded
-- if get(AppOptions, "verbose", 1) = 3 then
--     ShowIntructions()
-- end if
-- </eucode>
--
-- See Also:
--   [[:new]], [[:save_map]]
--

public function load_map(object input_file_name)
	integer file_handle
	object line_in
	object logical_line
	integer has_comment
	integer delim_pos
	object data_value
	object data_key
	sequence conv_res
	atom new_map
	sequence line_conts =   ",${"

	if sequence(input_file_name) then
		file_handle = open(input_file_name, "rb")
	else
		file_handle = input_file_name
	end if
	
	if file_handle = -1 then
		return -1
	end if
	
	new_map = new(threshold_size) -- Assume a small map initially.

	-- Look for a non-printable byte in the first 10 bytes. If none are found
	-- then this is a text-formated file otherwise it is a 'raw' saved file.
	
	for i = 1 to 10 do
		delim_pos = getc(file_handle)
		if delim_pos = -1 then 
			exit
		end if
	    
		if not t_print(delim_pos) then 
	    	if not t_space(delim_pos) then
	    		exit
	    	end if
	    end if
	    
	    delim_pos = -1
	end for
	
	if delim_pos = -1 then
	-- A text format file
		close(file_handle)
		file_handle = open(input_file_name, "r")
		
		while sequence(logical_line) with entry do
			delim_pos = find('=', logical_line)
			if delim_pos > 0 then
				data_key = text:trim(logical_line[1..delim_pos-1])
				if length(data_key) > 0 then
					data_key = search:match_replace("\\-", data_key, "-")
					if not t_alpha(data_key[1]) then
						conv_res = stdget:value(data_key,,stdget:GET_LONG_ANSWER)
						if conv_res[1] = stdget:GET_SUCCESS then
							if conv_res[3] = length(data_key) then
								data_key = conv_res[2]
							end if
						end if
					end if
									
					data_value = text:trim(logical_line[delim_pos+1..$])
					data_value = search:match_replace("\\-", data_value, "-")
					conv_res = stdget:value(data_value,,stdget:GET_LONG_ANSWER)
					if conv_res[1] = stdget:GET_SUCCESS then
						if conv_res[3] = length(data_value) then
							data_value = conv_res[2]
						end if
					end if
					
					put(new_map, data_key, data_value)
				end if
			end if
		entry
			logical_line = -1
			while sequence(line_in) with entry do
			
				if atom(logical_line) then
					logical_line = ""
				end if
				
				has_comment = search:rmatch("--", line_in)
				if has_comment != 0 then
					line_in = text:trim(line_in[1..has_comment-1])
				else
					line_in = text:trim(line_in)
				end if

				logical_line &= line_in
					
				if length(line_in) then
					if not find(line_in[$], line_conts) then
						-- This line is not being continued.
						
						-- Remove any ",$" combinations.
						logical_line = search:match_replace(`",$"`, logical_line, "")
						logical_line = search:match_replace(`,$`, logical_line, "")
						exit
					end if
				end if
			entry
				line_in = gets(file_handle)
			end while
		end while
	else
		io:seek(file_handle, 0)
		line_in  = serialize:deserialize(file_handle)
		if atom(line_in) then
			-- failed to decode the file.
			return -2
		end if

		if length(line_in) > 1 then
			switch line_in[1] do
				case 1, 2 then
					-- Saved Map Format version 1 and 2
					data_key   = serialize:deserialize(file_handle)
					data_value =  serialize:deserialize(file_handle)
					
					for i = 1 to length(data_key) do
						put(new_map, data_key[i], data_value[i])
					end for
				case else
					return -2
			end switch
		else
			-- Bad file format
			return -2
		end if
	end if
	
	if sequence(input_file_name) then
		close(file_handle)
	end if
	
	optimize(new_map)
	
	return new_map
end function

public enum
	SM_TEXT,
	SM_RAW

--**
-- Saves a map to a file.
--
-- Parameters:
--		# ##m## : a map.
--		# ##file_name_p## : Either a sequence, the name of the file to save to,
--                         or an open file handle as returned by [[:open]]().
--		# ##type## : an integer. SM_TEXT for a human-readable format (default),
--                SM_RAW for a smaller and faster format, but not human-readable.
--
-- Returns:
--	An **integer**, the number of keys saved to the file, or -1 if the
--                    save failed.
--
-- Comments:
-- If ##file_name_p## is an already opened file handle, this routine will write
-- to that file and not close it. Otherwise, the named file will be created and
-- closed by this routine.
--
-- The SM_TEXT type saves the map keys and values in a text format which can
-- be read and edited by standard text editor. Each entry in the map is saved as
-- a KEY/VALUE pair in the form \\
-- {{{
-- key = value
-- }}}
-- Note that if the 'key' value is a normal string value, it can be enclosed in
-- double quotes. If it is not thus quoted, the first character of the key
-- determines its Euphoria value type. A dash or digit implies an atom, an left-brace
-- implies a sequence, an alphabetic character implies a text string that extends to the
-- next equal '=' symbol, and anything else is ignored. 
--
-- Note that if a line contains a double-dash, then all text from the double-dash
-- to the end of the line will be ignored. This is so you can optionally add
-- comments to the saved map. Also, any blank lines are ignored too.
--
-- All text after the '=' symbol is assumed to be the map item's value data.
--
-- Because some map data can be rather long, it is possible to split the text into
-- multiple lines, which will be considered by [[:load_map]] as a single //logical//
-- line. If an line ends with a comma (,) or a dollar sign ($), then the next actual
-- line is appended to the end of it. After all these physical lines have been
-- joined into one logical line, all combinations of `",$"` and `,$` are removed.
--
-- For example:
-- {{{
-- one = {"first",
--        "second",
--        "third",
--        $
--       }
-- second = "A long text ",$
--        "line that has been",$
--        " split into three lines"
-- third = {"first",
--        "second",
--        "third"}
-- }}}
-- is equivalent to
-- {{{
-- one = {"first","second","third"}
-- second = "A long text line that has been split into three lines"
-- third = {"first","second","third"}
-- }}}
--
-- The SM_RAW type saves the map in an efficient manner. It is generally smaller
-- than the text format and is faster to process, but it is not human readable and
-- standard text editors can not be used to edit it. In this format, the file will
-- contain three serialized sequences:
-- # Header sequence: {integer:format version, string: date and time of save (YYMMDDhhmmss),
--                     sequence: euphoria version {major, minor, revision, patch}}
-- # Keys. A list of all the keys
-- # Values. A list of the corresponding values for the keys.
--
-- Example 1:
-- <eucode>
-- include std/error.e
--
-- map AppOptions
-- if save_map(AppOptions, "c:\myapp\options.txt") = -1
--     crash("Failed to save application options")
-- end if
--
-- if save_map(AppOptions, "c:\myapp\options.dat", SM_RAW) = -1
--     crash("Failed to save application options")
-- end if
-- </eucode>
--
-- See Also:
--   [[:load_map]]
--

public function save_map(map the_map_, object file_name_p, integer type_ = SM_TEXT)
	integer file_handle_ = -2
	sequence keys_
	sequence values_
	
	if sequence(file_name_p) then
		if type_ = SM_TEXT then
			file_handle_ = open(file_name_p, "w")
		else
			file_handle_ = open(file_name_p, "wb")
		end if
	else
		file_handle_ = file_name_p
	end if
	
	if file_handle_ < 0 then
		return -1
	end if
	
	keys_ = keys(the_map_)
	values_ = values(the_map_)
	
	if type_ = SM_RAW then
		puts(file_handle_, serialize:serialize({
				2, -- saved map version
				datetime:format(now_gmt(), "%Y%m%d%H%M%S" ), -- date of this saved map
				info:version_string()} -- Euphoria version
			 	))	
		puts(file_handle_, serialize:serialize(keys_))
		puts(file_handle_, serialize:serialize(values_))
	else
		for i = 1 to length(keys_) do
			keys_[i] = pretty:pretty_sprint(keys_[i], {2,0,1,0,"%d","%.15g",32,127,1,0})
			keys_[i] = search:match_replace("-", keys_[i], "\\-")
			values_[i] = pretty:pretty_sprint(values_[i], {2,0,1,0,"%d","%.15g",32,127,1,0})
			values_[i] = search:match_replace("-", values_[i], "\\-")
				
			printf(file_handle_, "%s = %s\n", {keys_[i], values_[i]})
		end for
	end if
	
	if sequence(file_name_p) then
		close(file_handle_)
	end if
	
	return length(keys_)
end function

--**
-- Duplicates a map.
--
-- Parameters:
--   # ##source_map## : map to copy from
--   # ##dest_map## : optional, map to copy to
--   # ##put_operation## : optional, operation to use when ##dest_map## is used.
--                         The default is PUT.
--
-- Returns:
--   If ##dest_map##  was not provided, an exact duplicate of ##source_map## otherwise
--   ##dest_map##, which does not have to be empty, is returned with the
--   new values copied from ##source_map##, according to the ##put_operation## value.
--
-- Example 1:
--   <eucode>
--   map m1 = new()
--   put(m1, 1, "one")
--   put(m1, 2, "two")
--
--   map m2 = copy(m1)
--   printf(1, "%s, %s\n", { get(m2, 1), get(m2, 2) })
--   -- one, two
--
--   put(m1, 1, "one hundred")
--   printf(1, "%s, %s\n", { get(m1, 1), get(m1, 2) })
--   -- one hundred, two
--
--   printf(1, "%s, %s\n", { get(m2, 1), get(m2, 2) })
--   -- one, two
--   </eucode>
--
-- Example 2:
--   <eucode>
--   map m1 = new()
--   map m2 = new()
--
--   put(m1, 1, "one")
--   put(m1, 2, "two")
--   put(m2, 3, "three")
--
--   copy(m1, m2)
--
--   ? keys(m2)
--   -- { 1, 2, 3 }
--   </eucode>
--
-- Example 3:
--   <eucode>
--   map m1 = new()
--   map m2 = new()
--
--   put(m1, "XY", 1)
--   put(m1, "AB", 2)
--   put(m2, "XY", 3)
--
--   pairs(m1) --> { {"AB", 2}, {"XY", 1} }
--   pairs(m2) --> { {"XY", 3} }
--
--   -- Add same keys' values.
--   copy(m1, m2, ADD)
--
--   pairs(m2) --> { {"AB", 2}, {"XY", 4} }
--   </eucode>
--
-- See Also:
--   [[:put]]
--

public function copy(map source_map, object dest_map=0, integer put_operation = PUT)
	if map(dest_map) then
		-- Copies the contents of one map to another map.
		sequence keys_set
		sequence value_set		
		sequence source_data
		
		source_data = eumem:ram_space[source_map]	
		if source_data[MAP_TYPE] = LARGEMAP then
			for index = 1 to length(source_data[KEY_BUCKETS]) do
				keys_set = source_data[KEY_BUCKETS][index]
				value_set = source_data[VALUE_BUCKETS][index]
				for j = 1 to length(keys_set) do
					put(dest_map, keys_set[j], value_set[j], put_operation)
				end for
			end for
		else
			for index = 1 to length(source_data[FREE_LIST]) do
				if source_data[FREE_LIST][index] !=  0 then
					put(dest_map, source_data[KEY_LIST][index], 
						source_data[VALUE_LIST][index], put_operation)
				end if
			end for
			
		end if

		return dest_map
	else
		atom temp_map = eumem:malloc()
		
	 	eumem:ram_space[temp_map] = eumem:ram_space[source_map]
	 	
		return temp_map
	end if
end function

--**
-- Converts a set of Key-Value pairs to a map.
--
-- Parameters:
--   # ##kv_pairs## : A seqeuence containing any number of subsequences that
--                   have the format {KEY, VALUE}. These are loaded into a
--                   new map which is then returned by this function.
--
-- Returns:
--   A **map**, containing the data from ##kv_pairs##
--
-- Example 1:
-- <eucode>
-- map m1 = new_from_kvpairs( {
--     { "application", "Euphoria" },
--     { "version", "4.0" },
--     { "genre", "programming language" },
--     { "crc", 0x4F71AE10 }
-- })
--
-- v = map:get(m1, "application") --> "Euphoria"
-- </eucode>
--

public function new_from_kvpairs(sequence kv_pairs)
	object new_map
	
	new_map = new( floor(7 * length(kv_pairs) / 2) )
	for i = 1 to length(kv_pairs) do
		if length(kv_pairs[i]) = 2 then
			put(new_map, kv_pairs[i][1], kv_pairs[i][2])
		end if
	end for
	
	return new_map	
end function

--**
-- Converts a set of Key-Value pairs contained in a string to a map.
--
-- Parameters:
--   # ##kv_string## : A string containing any number of lines that
--                   have the format KEY=VALUE. These are loaded into a
--                   new map which is then returned by this function.
--
-- Returns:
--   A **map**, containing the data from ##kv_string##
--
-- Comment:
-- This function actually calls ##[[:keyvalues]]()## to convert the string to
-- key-value pairs, which are then used to create the map.
--
-- Example 1:
-- Given that a file called "xyz.config" contains the lines ...
-- {{{
-- 	application = Euphoria,
-- 	version     = 4.0,
-- 	genre       = "programming language",
-- 	crc         = 4F71AE10
-- }}}
--
-- <eucode>
-- map m1 = new_from_string( read_file("xyz.config", TEXT_MODE))
-- 
-- printf(1, "%s\n", {map:get(m1, "application")}) --> "Euphoria"
-- printf(1, "%s\n", {map:get(m1, "genre")})       --> "programming language"
-- printf(1, "%s\n", {map:get(m1, "version")})     --> "4.0"
-- printf(1, "%s\n", {map:get(m1, "crc")})         --> "4F71AE10"  
-- </eucode>
--

public function new_from_string(sequence kv_string)
	return new_from_kvpairs( text:keyvalues (kv_string) )
end function

--**
-- Calls a user-defined routine for each of the items in a map.
--
-- Parameters:
--   # ##source_map## : The map containing the data to process
--   # ##user_rid##: The routine_id of a user defined processing function
--   # ##user_data##: An object. Optional. This is passed, unchanged to each call
--                    of the user defined routine. By default, zero (0) is used.
--   # ##in_sorted_order##: An integer. Optional. If non-zero the items in the
--                    map are processed in ascending key sequence otherwise
--                    the order is undefined. By default they are not sorted.
--   # ##signal_boundary##: A integer; 0 (the default) means that the user 
--                    routine is not called if the map is empty and when the
--                    last item is passed to the user routine, the Progress Code
--                    is not negative.
--
-- Returns:
-- An integer: 0 means that all the items were processed, and anything else is whatever
-- was returned by the user routine to abort the ##for_each()## process.
--
-- Comment:
-- * The user defined routine is a function that must accept four parameters.
-- ## Object: an Item Key
-- ## Object: an Item Value
-- ## Object: The ##user_data## value. This is never used by ##for_each()## itself, 
-- merely passed to the user routine.
-- ## Integer: Progress code.
-- *** The ##abs()## value of the progress code is the ordinal call number. That
-- is 1 means the first call, 2 means the second call, etc ...
-- *** If the progress code is negative, it is also the last call to the routine.
-- *** If the progress code is zero, it means that the map is empty and thus the
-- item key and value cannot be used.
-- *** **note** that if ##signal_boundary## is zero, the Progress Code is never
--     less than 1.
-- * The user routine must return 0 to get the next map item. Anything else will
-- cause ##for_each()## to stop running, and is returned to whatever called 
-- ##for_each()##.
-- * Note that any changes that the user routine makes to the map do not affect the
-- order or number of times the routine is called. ##for_each()## takes a copy of the
-- map keys and data before the first call to the user routine and uses the copied
-- data to call the user routine. 
--
-- Example 1:
-- <eucode>
-- include std/map.e
-- include std/math.e
-- include std/io.e
--
-- function Process_A(object k, object v, object d, integer pc)
--     writefln("[] = []", {k, v})
--     return 0
-- end function
--
-- function Process_B(object k, object v, object d, integer pc)
--     if pc = 0 then
--       writefln("The map is empty")
--     else
--       integer c
--       c = abs(pc)
--       if c = 1 then
--           writefln("---[]---", {d}) -- Write the report title.
--       end if
--       writefln("[]: [:15] = []", {c, k, v})
--       if pc < 0 then
--           writefln(repeat('-', length(d) + 6), {}) -- Write the report end.
--       end if
--     end if
--     return 0
-- end function
--
-- map m1 = new()
-- map:put(m1, "application", "Euphoria")
-- map:put(m1, "version", "4.0")
-- map:put(m1, "genre", "programming language")
-- map:put(m1, "crc", "4F71AE10")
--
-- -- Unsorted 
-- map:for_each(m1, routine_id("Process_A"))
-- -- Sorted
-- map:for_each(m1, routine_id("Process_B"), "List of Items", 1)  
-- </eucode>
--
-- The output from the first call could be...
-- {{{
-- application = Euphoria
-- version = 4.0
-- genre = programming language
-- crc = 4F71AE10
-- }}}
--
-- The output from the second call should be...
-- {{{
-- ---List of Items---
-- 1: application     = Euphoria
-- 2: crc             = 4F71AE10
-- 3: genre           = programming language
-- 4: version         = 4.0
-- -------------------
-- }}}
--

public function for_each(map source_map, integer user_rid, object user_data = 0, 
			integer in_sorted_order = 0, integer signal_boundary = 0)
	sequence lKV
	object lRes
	integer progress_code
	
	lKV = pairs(source_map, in_sorted_order)	
	if length(lKV) = 0 and signal_boundary != 0 then
		return call_func(user_rid, {0,0,user_data,0} )
	end if
	
	for i = 1 to length(lKV) do
		if i = length(lKV) and signal_boundary then
			progress_code = -i
		else
			progress_code = i
		end if
	
		lRes = call_func(user_rid, {lKV[i][1], lKV[i][2], user_data, progress_code})
		if not equal(lRes, 0) then
			return lRes
		end if
	end for
	
	return 0
end function

-- LOCAL FUNCTIONS --

procedure convert_to_large_map(integer the_map_)
	sequence temp_map_
	atom map_handle_

	temp_map_ = eumem:ram_space[the_map_]

	map_handle_ = new()
	for index = 1 to length(temp_map_[FREE_LIST]) do
		if temp_map_[FREE_LIST][index] !=  0 then
			put(map_handle_, temp_map_[KEY_LIST][index], temp_map_[VALUE_LIST][index])
		end if
	end for

	eumem:ram_space[the_map_] = eumem:ram_space[map_handle_]
end procedure

procedure convert_to_small_map(integer the_map_)
	sequence keys_
	sequence values_

	keys_ = keys(the_map_)
	values_ = values(the_map_)
	
	eumem:ram_space[the_map_] = {
		type_is_map, 0,0, SMALLMAP, repeat(init_small_map_key, threshold_size), 
		repeat(0, threshold_size), repeat(0, threshold_size)
	}
	
	for i = 1 to length(keys_) do
		put(the_map_, keys_[i], values_[i], PUT, 0)
	end for
end procedure
