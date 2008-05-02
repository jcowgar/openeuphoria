-- (c) Copyright 2007 Rapid Deployment Software - See License.txt

-- Handlers for HTML output format
-- Special Enhanced HTML tags (ie, HTMX tags) that we created are processed.
-- Comments are deleted.
-- All other HTML is passed through unchanged.
-- All <_4clist>, <_3clist> and <_2clist> tags can contain any htmL (NOT htmX)
-- tag inside their fields. They will be all processed as usual.
-- rules about <_eucode>:
--   </_eucode> must appear on a new line, ie, not with the last line of eucode.
--   Also when <_eucode>.. </_eucode> appears in between <table>.. </table>, 
--   it cannot be the first row entry. And the table must be with <_2clist>,
--   <_3clist> or <_4clist> entries. 
-- written by: Junko C. Miura of Rapid Deployment Software (JCMiura@aol.com)

include wildcard.e

-- constants for colors necessary for syncolor.e
global constant NORMAL_COLOR  = #330033,
		COMMENT_COLOR = #FF0055,
		KEYWORD_COLOR = #0000FF,
		BUILTIN_COLOR = #FF00FF,
		STRING_COLOR  = #00A033,
		BRACKET_COLOR = {NORMAL_COLOR, #993333,
				 #0000FF, #5500FF, #00FF00}

-- from euphoria\bin
include keywords.e
include syncolor.e

constant YEAR_DELIMITER = 90, SINCE_YEAR = 1900
integer blank
blank = FALSE
sequence line, colorLine                -- both for <_eucode>... </_eucode>
integer firstLine, in2clist, in3clist   -- both for <_eucode>... </_eucode>

procedure tag_init_comment(sequence raw_text, sequence plist)
-- special handler for initial comment to write out
    write("<!-- GENERATED BY A EUPHORIA PROGRAM. DO NOT EDIT! -->\n\n")
end procedure

procedure tag_width(sequence raw_text, sequence plist)
    write("<table width=90% border=0><tr><td>\n")
end procedure

procedure tag_end_width(sequence raw_text, sequence plist)
    write("</td></tr></table>\n")
end procedure

procedure tag_css(sequence raw_text, sequence plist)
    write("<link rel=\"stylesheet\" media=\"screen\" href=\"display.css\">")
end procedure

procedure tag_literal(integer raw_text, sequence param_list)
-- handle one character of literal text (i.e. text that is not inside a tag).
-- Normally it will not output multiple blank chars, it writes only 1 blank 
-- char. But when raw_text is enclosed by <PRE> and </PRE>, it outputs every
-- character without a change (ie, writes out all the blanks).
    integer color
    sequence text
    
    if inEuCode then
	line = line & raw_text
	if raw_text = '\n' then
	    if firstLine then
		-- check if this line is to be put as a row of a table. Here,
		-- we accept/assume only a table of <_3clist>, <_2clist> and
		-- <_4clist> entries.
		if inTable then
		    if in2clist then
			write("<tr><td></td><td>\n")
		    elsif in3clist then
			write("<tr><td></td><td></td><td>\n")
		    else
			write("<tr><td></td><td></td><td></td><td>\n")
		    end if
		end if
		firstLine = FALSE
		write("<pre>")
		-- if the first line is a blank line, discard it
		if all_white(line) then
		    line = ""
		    return
		end if
	    end if
	    
	    colorLine = SyntaxColor(line)
	    for i = 1 to length(colorLine) do
		color = colorLine[i][1]
		text  = colorLine[i][2]
		write("<font color=\"#" & sprintf("%06x", color) & "\">")
		write(text & "</font>")
	    end for
	    write("\n")
	    line = ""
	end if
    else
	if not inPre then
	    if blank and raw_text = ' ' then
		return
	    end if
	    blank = raw_text = ' '
	end if
	write(raw_text)
    end if
end procedure

procedure tag_dul(sequence raw_text, sequence param_list)
-- do nothing 
end procedure

procedure tag_end_dul(sequence raw_text, sequence param_list)
-- do nothing
end procedure

procedure tag_sul(sequence raw_text, sequence param_list)
-- do nothing
end procedure

procedure tag_end_sul(sequence raw_text, sequence param_list)
-- do nothing
end procedure

procedure tag_comment(sequence raw_text, sequence param_list)
-- comment handler - do nothing - don't have any comments in html output file
end procedure

procedure tag_default(sequence raw_text, sequence param_list)
-- default handler - let most html pass through unchanged
    write(raw_text)
end procedure

procedure common3_4clist(sequence raw_text, sequence plist)
-- common code for tag_4clist() and tag_3clist()
    object temp
    
    in2clist = FALSE
    
    temp = pval("href", plist)
    if sequence(temp) and length(temp) > 0 then
	write("<a href=\"" & temp & "\">")
	write("<b>" & pval("name", plist) & "</b></a></td>\n")
    else
	write("<b>" & pval("name", plist) & "</b></td>\n")
    end if
    if in3clist then
	write("<td width=10 align=center valign=top>-</td>")
    else
	-- this is _4clist tag. Check the optional col3 field.
	temp = pval("col3", plist)
	if sequence(temp) then
	    write("<td align=center valign=top>" & temp & "</td>")
	else
	    -- generate exactly same htmL code as _3clist
	    write("<td width=10 align=center valign=top>-</td>")
	end if
    end if
    write("\n<td>" & pval("description", plist) & "</td></tr>\n")
end procedure

procedure tag_4clist(sequence raw_text, sequence plist)    
-- special handler for a list entry in a 4 column table. This is same form
-- with _3clist, except the first column is a filler. As _3clist, the second
-- column typically contains a link. As a deviation from _3clist, the third
-- column contents is optional parameter (not fixed as _3clist with "-").
    in3clist = FALSE
    
    write("<tr><td width=24 nowrap></td><td valign=top>")
    common3_4clist(raw_text, plist)
end procedure

procedure tag_3clist(sequence raw_text, sequence plist)    
-- special handler for a list entry in a 3 column table. In this form of tag,
-- the first column typically contains a link.
    in3clist = TRUE
    
    write("<tr><td valign=top>")
    common3_4clist(raw_text, plist)
end procedure

procedure tag_2clist(sequence raw_text, sequence plist)    
-- special handler for a list entry in a 2 column table. In this form of tag,
-- if you want to have a link in the first column, you embed an appropriate 
-- <a href...> tag inside the string. ie, no default link option provided. 
    in2clist = TRUE
    in3clist = FALSE
    
    write("<tr><td valign=top>")
    write("<b>" & pval("name", plist) & "</b></td>\n")
    write("<td>" & pval("description", plist) & "\n")
    write("</td></tr>\n")
end procedure

procedure tag_routine(sequence raw_text, sequence plist)    
-- special handler for an entry to be centered, bolded, colored, and named for
-- link. This tag is used in the library.doc for each routine/function title 
-- entry.
    sequence name       -- our policy: mandatory field won't be error checked
    name = pval("name", plist)
    write("<a name=" & name & "></a><font color=\"#006633\" size=+2><br>\n")
    write("<center><b>" & name & "</b></center>\n")
    write("</font><p>\n")
end procedure

procedure tag_table(sequence raw_text, sequence plist)
    -- prepare for <_eucode>... </_eucode>
    inTable = TRUE
    -- in2clist and in3clist may be reset in tag_end_table(), but this makes
    -- bit more sense
    in2clist = FALSE
    in3clist = FALSE
    write(raw_text)
end procedure

procedure tag_end_table(sequence raw_text, sequence plist)
    -- prepare for <_eucode>... </_eucode>
    inTable = FALSE
    write(raw_text)
end procedure

procedure tag_pre(sequence raw_text, sequence plist)
-- same to default handler except it sets inPre flag ON
    inPre = TRUE
    write(raw_text)
end procedure

procedure tag_end_pre(sequence raw_text, sequence plist)
-- same to default handler except it sets inPre flag OFF and resets blank flag
    inPre = FALSE
    blank = FALSE
    write(raw_text)
end procedure

procedure tag_eucode(sequence raw_text, sequence plist)
    inEuCode = TRUE
    firstLine = TRUE
    line = ""
    -- note: write("<pre>") must be delayed until just before actual first line
end procedure

procedure tag_end_eucode(sequence raw_text, sequence plist)
    inEuCode = FALSE
    blank = FALSE
    write("</pre>")

    if inTable then
	write("</td></tr>\n")
    end if          
end procedure

procedure tag_center(sequence raw_text, sequence plist)
-- <_center> should be treated just same as <center>
    write("<center>")
end procedure

procedure tag_end_center(sequence raw_text, sequence plist)
-- </_center> should be treated just same as </center>
    write("</center>")
end procedure

procedure tag_bq(sequence raw_text, sequence plist)
    write("<b>")
end procedure

procedure tag_end_bq(sequence raw_text, sequence plist)
    write("</b>")
end procedure

procedure tag_bsq(sequence raw_text, sequence plist)
    write("<b>")
end procedure

procedure tag_end_bsq(sequence raw_text, sequence plist)
    write("</b>")
end procedure

procedure tag_ba(sequence raw_text, sequence plist)
    write("<b>")
end procedure

procedure tag_end_ba(sequence raw_text, sequence plist)
    write("</b>")
end procedure

procedure tag_continue(sequence raw_text, sequence plist)
-- special handler for a title to continue to the next page
    object temp
    
    write("<p>&nbsp;<p><center>\n")
    write("<font color=\"#006633\" face=\"Arial, Helvetica\" size=+1>" &
	  "... continue \n")
    
    temp = pval("href", plist)
    if sequence(temp) and not equal(temp, "") then
	write("<a href=\"" & temp & "\">" &
	      pval("name", plist) & "</a></font>\n</center>\n<p>&nbsp;\n")
    else
	quit("no href data given in <_continue> tag")
    end if
end procedure

constant LIB_ID = {
        {"overview.htm", "Overview", ""},
        {"refman.htm", "Reference Manual", ""},
        {"library.htm", "Library Index", ""},
        {"lib_type.htm", "Type Checking", "type_checking"},
        {"lib_seq.htm", "Sequence Manipulation", "seq_manip"},
        {"lib_srch.htm", "Searching and Sorting", "srch_srt"},
        {"lib_math.htm", "Math", "math"},
        {"lib_bitw.htm", "Bitwise Logic", "bitw_logic"},
        {"lib_file.htm", "I/O", "i_o"},
        {"lib_mous.htm", "Mouse", "mouse_spt"},
        {"lib_os.htm", "O/S", "op_sys"},
        {"lib_dbg.htm", "Debugging", "debugging"},
        {"lib_grap.htm", "Graphics", "gr_sound"},
        {"lib_mach.htm", "Machine Level", "m_level_i"},
        {"lib_dyn.htm", "Dynamic Calls", "dyn_call"},
        {"lib_c.htm", "C Interface", "call_c_func"},
        {"lib_map.htm", "Map", "map"},
        {"lib_dtm.htm", "Date/Time", "datetime"},
        {"lib_task.htm", "Multitasking", "tasking"},
        {"lib_eds.htm", "EDS", "eds"}
    }

procedure tag_continueall(sequence raw_text, sequence plist, integer top)
-- special handler for braching to all the pages in the same category
    object  temp

    if top then
        write("<center>\n")
    else
        write("<p>&nbsp;<p><center>\n")
        write("<hr>\n")
    end if

    write("<font face=\"Arial, Helvetica\" size=-1>\n")
    
    temp = pval("libDoc", plist)
    if sequence(temp) and not equal(temp, "") then
        for i = 1 to length(LIB_ID) - 1 do
            if not equal(temp, LIB_ID[i][1]) then
            write("<a href=\"" & LIB_ID[i][1] & "\">" & LIB_ID[i][2] &
                  "</a> &nbsp; | &nbsp;\n")
            else
                write(LIB_ID[i][2] & " &nbsp; | &nbsp;\n")
            end if
        end for

        if not equal(temp, LIB_ID[length(LIB_ID)][1]) then
            write("<a href=\"" & LIB_ID[length(LIB_ID)][1] & "\">" &
              LIB_ID[length(LIB_ID)][2] &
              "</a>\n")
        else
            write(LIB_ID[length(LIB_ID)][2] & "\n")
        end if
    else
        quit("no identification of \"lib_\" given in <_continueAll> tag")
    end if

    if top then
        write("<hr>\n")
    end if
    write("</font></center>\n")
end procedure

procedure tag_continuealltop(sequence raw_text, sequence plist)
    tag_continueall(raw_text, plist, 1)
end procedure

procedure tag_continueallbottom(sequence raw_text, sequence plist)
    tag_continueall(raw_text, plist, 0)
end procedure

global procedure html_init()
-- set up handlers for html output
    add_handler("_init_comment", routine_id("tag_init_comment"))
    add_handler("_width",   routine_id("tag_width"))
    add_handler("/_width",  routine_id("tag_end_width"))
    add_handler("_continue",routine_id("tag_continue"))
    add_handler("_continueAll",routine_id("tag_continueallbottom"))
    add_handler("_continueAllTop",routine_id("tag_continuealltop"))
    add_handler("_bsq",     routine_id("tag_bsq"))
    add_handler("/_bsq",    routine_id("tag_end_bsq"))
    add_handler("!--",      routine_id("tag_comment"))
    add_handler("_center",  routine_id("tag_center"))
    add_handler("/_center", routine_id("tag_end_center"))
    add_handler("pre",      routine_id("tag_pre"))
    add_handler("/pre",     routine_id("tag_end_pre"))
    add_handler("_dul",     routine_id("tag_dul"))
    add_handler("/_dul",    routine_id("tag_end_dul"))
    add_handler("_sul",     routine_id("tag_sul"))
    add_handler("/_sul",    routine_id("tag_end_sul"))
    add_handler("_bq",      routine_id("tag_bq"))
    add_handler("/_bq",     routine_id("tag_end_bq"))
    add_handler("_ba",      routine_id("tag_ba"))
    add_handler("/_ba",     routine_id("tag_end_ba"))
    add_handler("_routine", routine_id("tag_routine"))
    add_handler("table",    routine_id("tag_table"))
    add_handler("/table",   routine_id("tag_end_table"))
    add_handler("_eucode",  routine_id("tag_eucode"))
    add_handler("/_eucode", routine_id("tag_end_eucode"))
    add_handler("_4clist",  routine_id("tag_4clist"))
    add_handler("_3clist",  routine_id("tag_3clist"))
    add_handler("_2clist",  routine_id("tag_2clist"))
    add_handler("_default", routine_id("tag_default"))
    add_handler("_literal", routine_id("tag_literal"))
    add_handler("_css",     routine_id("tag_css"))
    out_type = "htm"

    init_class()     -- defined in syncolor.e
end procedure

