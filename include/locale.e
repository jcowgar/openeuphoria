-- (c) Copyright 2008 Rapid Deployment Software - See License.txt
--
-- Euphoria 3.2
-- Locale routines

include misc.e
include dll.e
include machine.e
include datetime.e as dt

------------------------------------------------------------------------------------------
--
-- Local Constants
--
------------------------------------------------------------------------------------------

constant P = C_POINTER, I = C_INT, D = C_DOUBLE

------------------------------------------------------------------------------------------
--
-- Library Open/Checking
--
------------------------------------------------------------------------------------------

integer LC_ALL, f_strfmon, f_strfnum
atom lib, lib2

if platform() = WIN32 then
    lib = open_dll("MSVCRT.DLL") -- TODO
    lib2 = open_dll("KERNEL32.DLL")
    f_strfmon = define_c_func(lib2, "GetCurrencyFormatA", {I, I, P, P, P, I}, I)
    f_strfnum = define_c_func(lib2, "GetNumberFormatA", {I, I, P, P, P, I}, I)
    LC_ALL = 0
elsif platform() = LINUX or platform() = FREEBSD then
    lib = open_dll("")
    f_strfmon = define_c_func(lib, "strfmon", {P, I, P, D}, I)
    f_strfnum = -1
    LC_ALL = 6
else
    puts(2, "IupEu requires Windows, Linux or FreeBSD\n" &
            "It does not and will not run in DOS\n")
    abort(1)
end if

------------------------------------------------------------------------------------------
--
-- Global Functions/Procedures
--
------------------------------------------------------------------------------------------

constant
    f_setlocale = define_c_func(lib, "setlocale", {I, P}, P),
    f_strftime = define_c_func(lib, "strftime", {P, I, P, P}, I)

-- TODO: document
global procedure set(sequence new_locale)
    atom pLocale, ign

    pLocale = allocate_string(new_locale)
    ign = c_func(f_setlocale, {LC_ALL, pLocale})
    free(pLocale)
end procedure

-- TODO: document
global function get()
    sequence r
    atom p

    p = c_func(f_setlocale, {LC_ALL, NULL})
    if p = NULL then
        return ""
    end if

    r = peek_string(p)
    free(p)

    return r
end function

function money_unix(atom amount)
    atom pResult, pFmt
    sequence result
    integer size

    pResult = allocate(4 * 160)
    pFmt = allocate_string("%n")
    size = c_func(f_strfmon, {pResult, 4 * 160, pFmt, amount})
    free(pFmt)

    result = peek_string(pResult)
    free(pResult)

    return result
end function

function money_win32(atom amount)
    atom pAmount, pResult
    sequence result
    integer size

    pAmount = allocate_string(sprintf("%.8f", {amount}))
    pResult = allocate(4 * 160)
    size = c_func(f_strfmon, {LC_ALL, 0, pAmount, NULL, pResult, 4 * 160})
    result = peek_string(pResult)
    free(pAmount)
    free(pResult)

    return result
end function

-- TODO: document
global function money(atom amount)
    if platform() = WIN32 then
        return money_win32(amount)
    else
        return money_unix(amount)
    end if
end function

function number_unix(atom num)
    atom pResult, pFmt
    sequence result
    integer size

    pResult = allocate(4 * 160)
    pFmt = allocate_string("%!n")
    size = c_func(f_strfmon, {pResult, 4 * 160, pFmt, num})
    free(pFmt)

    result = peek_string(pResult)
    free(pResult)

    return result
end function

function number_win32(atom num)
    atom pNum, pResult
    sequence result
    integer size

    pNum = allocate_string(sprintf("%.8f", {num}))
    pResult = allocate(4 * 160)
    size = c_func(f_strfnum, {LC_ALL, 0, pNum, NULL, pResult, 4 * 160})
    result = peek_string(pResult)
    free(pNum)
    free(pResult)

    return result
end function

-- TODO: document
global function number(atom num)
    if platform() = WIN32 then
        return number_win32(num)
    else
        return number_unix(num)
    end if
end function

function mk_tm_struct(dt:datetime dtm)
    atom pDtm

    pDtm = allocate(36)
    poke4(pDtm,    dtm[SECOND])        -- int tm_sec
    poke4(pDtm+4,  dtm[MINUTE])        -- int tm_min
    poke4(pDtm+8,  dtm[HOUR])          -- int tm_hour
    poke4(pDtm+12, dtm[DAY])           -- int tm_mday
    poke4(pDtm+16, dtm[MONTH] - 1)     -- int tm_mon
    poke4(pDtm+20, dtm[YEAR] - 1900)   -- int tm_year
    poke4(pDtm+24, dt:dow(dtm) - 1)    -- int tm_wday
    poke4(pDtm+28, dt:doy(dtm))        -- int tm_yday
    poke4(pDtm+32, 0)                  -- int tm_isdst

    return pDtm
end function

-- TODO: document
global function datetime(sequence fmt, dt:datetime dtm)
    atom pFmt, pRes, pDtm
    integer size
    sequence res

    pDtm = mk_tm_struct(dtm)
    pFmt = allocate_string(fmt)
    pRes = allocate(1024)
    size = c_func(f_strftime, {pRes, 256, pFmt, pDtm})
    res = peek_string(pRes)
    free(pRes)
    free(pFmt)
    free(pDtm)

    return res
end function
