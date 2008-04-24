-- Date and Time functions
-- 2008

-- No timezone offset.

-- Engine created by CyrekSoft --

-- Change this to 1 for extended leap year rules
constant
    XLEAP = 1,
    Gregorian_Reformation = 1752,
    Gregorian_Reformation00 = 1700,
    DaysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31},
    EPOCH_1970 = 62135856000,
    DayLengthInSeconds = 86400

-- Date Handling ------------------------------------------------------------

function isLeap(integer year) -- returns integer (0 or 1)
    sequence ly

	ly = (remainder(year, {4, 100, 400, 3200, 80000})=0)
	
	if not ly[1] then return 0 end if
	
	if year <= Gregorian_Reformation then
		return 1 -- ly[1] can't possibly be 0 here so set shortcut as '1'.
	elsif XLEAP then
		return ly[1] - ly[2] + ly[3] - ly[4] + ly[5]
	else -- Standard Gregorian Calendar
		return ly[1] - ly[2] + ly[3]
	end if
end function

function daysInMonth(integer year, integer month) -- returns a month_
	if year = Gregorian_Reformation and month = 9 then
		return 19
	elsif month != 2 then
		return DaysPerMonth[month]
	else
		return DaysPerMonth[month] + isLeap(year)
	end if
end function

function daysInYear(integer year) -- returns a jday_ (355, 365 or 366)
	if year = Gregorian_Reformation then
		return 355
	end if
	return 365 + isLeap(year)
end function

-- Functions using the new data-types

function julianDayOfYear(object ymd) -- returns an integer
    integer year, month, day
    integer d

    year = ymd[1]
    month = ymd[2]
    day = ymd[3]

    if month = 1 then return day end if

    d = 0
    for i = 1 to month - 1 do
	d += daysInMonth(year, i)
    end for

    d += day

    if year = Gregorian_Reformation and month = 9 then
	if day > 13 then
	    d -= 11
	elsif day > 2 then
	    return 0
	end if
    end if

    return d
end function

function julianDay(object ymd) -- returns an integer
    integer year
    integer j, greg00

    year = ymd[1]
    j = julianDayOfYear(ymd)

    year  -= 1
    greg00 = year - Gregorian_Reformation00

    j += (
	365 * year
	+ floor(year/4)
	+ (greg00 > 0)
	    * (
		- floor(greg00/100)
		+ floor(greg00/400+.25)
	    )
	- 11 * (year >= Gregorian_Reformation)
    )

    if XLEAP then
	j += (
	    - (year >=  3200) * floor(year/ 3200)
	    + (year >= 80000) * floor(year/80000)
	)
    end if

    return j
end function

function julianDate(integer j) -- returns a Date
    integer year, doy

    -- Take a guesstimate at the year -- this is usually v.close
    if j >= 0 then
	year = floor(j / (12 * 30.43687604)) + 1
    else
	year = -floor(-j / 365.25) + 1
    end if

    -- Calculate the day in the guessed year
    doy = j - (julianDay({year, 1, 1}) - 1) -- = j - last day of prev year

    -- Correct any errors

    -- The guesstimate is usually so close that these whiles could probably
    -- be made into ifs, but I haven't checked all possible dates yet... ;)

    while doy <= 0 do -- we guessed too high for the year
	year -= 1
	doy += daysInYear(year)
    end while

    while doy > daysInYear(year) do -- we guessed too low
	doy -= daysInYear(year)
	year += 1
    end while

    -- guess month
    if doy <= daysInMonth(year, 1) then
	return {year, 1, doy}
    end if
    for month = 2 to 12 do
	doy -= daysInMonth(year, month-1)
	if doy <= daysInMonth(year, month) then
	    return {year, month, doy}
	end if
    end for

    -- Skip to the next year on overflow
    -- The alternative is a crash, listed below
    return {year+1, 1, doy-31}
end function

-- Conversions to and from seconds

function datetimeToSeconds(object dt) -- returns an atom
    return julianDay(dt) * DayLengthInSeconds + (dt[4] * 60 + dt[5]) * 60 + dt[6]
end function

function secondsToDateTime(atom seconds) -- returns a DateTime
integer days, minutes, hours
atom secs

    days = floor(seconds / DayLengthInSeconds)
    seconds = remainder(seconds, DayLengthInSeconds)

    secs = remainder(seconds, 60)
    seconds = floor(seconds / 60)
    minutes = remainder(seconds, 60)
    hours = remainder(floor(seconds / 60), 24)
    
    return julianDate(days) & {hours, minutes, seconds}
end function

-- ================= START newstdlib

include string.e

global constant
    DT_YEAR   = 1,
    DT_MONTH  = 2,
    DT_DAY    = 3,
    DT_HOUR   = 4,
    DT_MINUTE = 5,
    DT_SECOND = 6

global type datetime(object o)
	return sequence(o) and length(o) = 6
	    and integer(o[DT_YEAR]) and integer(o[DT_MONTH]) and integer(o[DT_DAY])
	    and integer(o[DT_HOUR]) and integer(o[DT_MINUTE]) and atom(o[DT_SECOND])
end type

-- Creates the datetime object for the specified parameters
global function datetime_new(integer year, integer month, integer day, integer hour, integer minute, atom second)
	return {year, month, day, hour, minute, second}
end function

-- Compare the receiver to the specified Date to determine the relative ordering. 
-- returns -1 or 0 or 1
global function datetime_compare(datetime dt1, datetime dt2)
    return compare(datetimeToSeconds(dt1) - datetimeToSeconds(dt2), 0)
end function

-- TODO: document
-- Converts the built-in date() format to datetime format
global function datetime_from_date(sequence src)
	return {src[DT_YEAR]+1900, src[DT_MONTH], src[DT_DAY], src[DT_HOUR], src[DT_MINUTE], src[DT_SECOND]}
end function

-- TODO: document
-- Returns the datetime object for now. No timezones!
global function datetime_now()
	return datetime_from_date(date())
end function

-- TODO: document
-- Answers the gregorian calendar day of the week. 
global function datetime_dow(datetime dt)
    return remainder(julianDay(dt)-1+4094, 7) + 1
end function

-- TODO: create, test, document
-- datetime datetime_parse(ustring string)
-- parse the string and returns the datetime
global function datetime_parse(ustring string)
	return 0
end function

-- TODO: create, document, test
-- ustring datetime_format(ustring format)
-- format the date according to the format string
-- format string some taken from date(1)
-- %%  a literal %
-- %a  locale's abbreviated weekday name (e.g., Sun)
-- %A  locale's full weekday name (e.g., Sunday)
-- %b  locale's abbreviated month name (e.g., Jan)
-- %B  locale's full month name (e.g., January)
-- %C  century; like %Y, except omit last two digits (e.g., 21)
-- %d  day of month (e.g, 01)
-- %g  last two digits of year of ISO week number (see %G)
-- %H  hour (00..23)
-- %I  hour (01..12)
-- %j  day of year (001..366)
-- %k  hour ( 0..23)
-- %l  hour ( 1..12)
-- %m  month (01..12)
-- %M  minute (00..59)
-- %p  locale's equivalent of either AM or PM; blank if not known
-- %P  like %p, but lower case
-- %s  seconds since 1970-01-01 00:00:00 UTC
-- %S  second (00..60)
-- %u  day of week (1..7); 1 is Monday
-- %w  day of week (0..6); 0 is Sunday
-- %y  last two digits of year (00..99)
-- %Y  year
global function datetime_format(ustring format)
	return 0
end function

-- TODO: document
-- returns the number of seconds since 1970-1-1 0:0 (no timezone!)
global function datetime_to_unix(datetime dt)
	return datetimeToSeconds(dt) - EPOCH_1970
end function

-- TODO: document
-- returns the number of seconds since 1970-1-1 0:0 (no timezone!)
global function datetime_from_unix(atom unix)
	return secondsToDateTime(EPOCH_1970 + unix)
end function

-- TODO: document
-- adds the date with specified number of seconds
global function datetime_add_seconds(datetime dt, atom seconds)
	return secondsToDateTime(datetimeToSeconds(dt) + seconds)
end function

-- TODO: document
-- adds the date with specified number of days
global function datetime_add_days(datetime dt, integer days)
	return secondsToDateTime(datetimeToSeconds(dt) + days * DayLengthInSeconds)
end function

-- TODO: document
-- returns the number of seconds between two datetimes
global function datetime_diff_seconds(datetime dt1, datetime dt2)
	return datetimeToSeconds(dt2) - datetimeToSeconds(dt1)
end function

-- TODO: document
-- returns the number of days between two datetimes
global function datetime_diff_days(datetime dt1, datetime dt2)
	return julianDay(dt2) - julianDay(dt1)
end function
