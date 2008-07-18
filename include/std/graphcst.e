-- (c) Copyright 2008 Rapid Deployment Software - See License.txt
--
--****
-- == Graphical Image Constants
-- **Page Contents**
--
-- <<LEVELTOC depth=2>>
--
-- === Constants
--
-- error codes returned by read_bitmap(), save_bitmap() and save_screen()
-- * BMP_SUCCESS,
-- * BMP_OPEN_FAILED,
-- * BMP_UNEXPECTED_EOF,
-- * BMP_UNSUPPORTED_FORMAT,
-- * BMP_INVALID_MODE

export enum
	BMP_SUCCESS,
	BMP_OPEN_FAILED,
	BMP_UNEXPECTED_EOF,
	BMP_UNSUPPORTED_FORMAT,
	BMP_INVALID_MODE
		 
export enum
	VC_COLOR,
	VC_MODE,
	VC_LINES,
	VC_COLUMNS,
	VC_XPIXELS,
	VC_YPIXELS,
	VC_NCOLORS,
	VC_PAGES

--****
-- === Constants
--
-- ==== Colors
-- ===== Normal
-- * BLACK
-- * BLUE
-- * BROWN
-- * CYAN
-- * GRAY
-- * GREEN
-- * MAGENTA
-- * RED
-- * WHITE
-- * YELLOW
--
-- ===== Bright
-- * BRIGHT_BLUE
-- * BRIGHT_CYAN
-- * BRIGHT_GREEN
-- * BRIGHT_MAGENTA
-- * BRIGHT_RED
-- * BRIGHT_WHITE
--
-- ===== Miscellaneous
-- * BLINKING

-- COLOR values -- for characters and pixels
export constant
		 BLACK = 0,  -- in graphics modes this is "transparent"
		 GREEN = 2,
		 MAGENTA = 5,
		 WHITE = 7,
		 GRAY  = 8,
		 BRIGHT_GREEN = 10,
		 BRIGHT_MAGENTA = 13,
		 BRIGHT_WHITE = 15
		 
export integer BLUE, CYAN, RED, BROWN, BRIGHT_BLUE, BRIGHT_CYAN, BRIGHT_RED, YELLOW

ifdef UNIX then
	BLUE  = 4
	CYAN =  6
	RED   = 1
	BROWN = 3
	BRIGHT_BLUE = 12
	BRIGHT_CYAN = 14
	BRIGHT_RED = 9
	YELLOW = 11
else
	BLUE  = 1
	CYAN =  3
	RED   = 4
	BROWN = 6
	BRIGHT_BLUE = 9
	BRIGHT_CYAN = 11
	BRIGHT_RED = 12
	YELLOW = 14
end ifdef

export constant BLINKING = 16  -- add to color to get blinking text

export type color(integer x)
	return x >= 0 and x <= 255
end type

--**
-- Mixture Type
-- Comments:
-- A mixture is a ##{red, green, blue}## triple of intensities, which enables you to define 
-- custom colors. Intensities must be from 0 (weakest) to 63 (strongest). Thus, the brightest 
-- white is {63, 63, 63}.

export type mixture(sequence s)
	if length(s) != 3 then
		return 0
	end if
	for i=1 to 3 do
		if not integer(s[i]) or and_bits(s[i],#FFFFFFC0) then
			return 0
		end if
	end for
	return 1
end type

constant
	M_VIDEO_CONFIG   = 13

--**
-- Return a description of the current video configuration:
--
-- Returns:
-- 		A **sequence** of 8 nonnegative integers, laid out as follows:
--	# color monitor?: 1 0 if monochrome, 1 otherwise
--	# current video mode
-- 	# number of text rows
-- 	# number of text columns
--	# screen width in pixels
--	# screen height in pixels
--	# number of colors
--	# number of display pages
--
-- Comments:
-- An enum is available for convenient access to the returned configuration data:
-- <eucode>
-- export constant 
--     VC_COLOR   = 1,
--     VC_MODE    = 2,
--     VC_LINES   = 3,
--     VC_COLUMNS = 4,
--     VC_XPIXELS = 5,
--     VC_YPIXELS = 6,
--     VC_NCOLORS = 7,
--     VC_PAGES   = 8
-- </eucode>
-- This routine makes it easy for you to parameterize a program so it will work in many 
-- different graphics modes.
--
-- On the PC there are two types of graphics mode. The first type, text mode, lets you 
-- print text only. The second type, pixel-graphics mode, lets you plot pixels, or points, 
-- in various colors, as well as text. You can tell that you are in a text mode, because 
-- the ##VC_XPIXELS## and ##VC_YPIXELS## fields will be 0. Library routines such as 
-- [[:polygon]], [[:draw_line]], and [[:ellipse]] only work in a pixel-graphics mode.
--
-- Example:
-- <eucode>
-- -- vc = video_config()  -- in mode 3 with 25-lines of text:
-- -- vc is {1, 3, 25, 80, 0, 0, 32, 8}
-- </eucode>
-- See Also:
-- 		[[:graphics_mode]]
export function video_config()
	return machine_func(M_VIDEO_CONFIG, 0)
end function

