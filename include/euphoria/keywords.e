--****
-- == Keyword Data
--
-- Keywords and routines built in to Euphoria.
--
-- <<LEVELTOC level=2 depth=4>>
--

namespace keywords

--****
-- === Constants
--

--**
-- Sequence of Euphoria keywords

public constant keywords = {
	"and",
	"as",
	"break",
	"by",
	"case",
	"constant",
	"continue",
	"do",
	"else",
	"elsedef",
	"elsif",
	"elsifdef",
	"end",
	"entry",
	"enum",
	"exit",
	"export",
	"fallthru",
	"for",
	"function",
	"global",
	"goto",
	"if",
	"ifdef",
	"include",
	"label",
	"loop",
	"namespace",
	"not",
	"or",
	"override",
	"procedure",
	"public",
	"retry",
	"return",
	"routine",
	"switch",
	"then",
	"to",
	"type",
	"until",
	"while",
	"with",
	"without",
	"xor"
}

--**
-- Sequence of Euphoria's built-in function names

public constant builtins = {
	"?",
	"abort",
	"and_bits",
	"append",
	"arctan",
	"atom",
	"c_func",
	"c_proc",
	"call",
	"call_func",
	"call_proc",
	"clear_screen",
	"close",
	"command_line",
	"compare",
	"cos",
	"date",
	"delete",
	"delete_routine",
	"equal",
	"find",
	"floor",
	"get_key",
	"getc",
	"getenv",
	"gets",
	"hash",
	"head",
	"include_paths",
	"insert",
	"integer",
	"length",
	"log",
	"machine_func",
	"machine_proc",
	"match",
	"mem_copy",
	"mem_set",
	"not_bits",
	"object",
	"open",
	"option_switches",
	"or_bits",
	"peek",
	"peek2s",
	"peek2u",
	"peek4s",
	"peek4u",
	"peek_string",
	"peeks",
	"pixel",
	"platform",
	"poke",
	"poke2",
	"poke4",
	"position",
	"power",
	"prepend",
	"print",
	"printf",
	"puts",
	"rand",
	"remainder",
	"remove",
	"repeat",
	"replace",
	"routine_id",
	"sequence",
	"sin",
	"splice",
	"sprintf",
	"sqrt",
	"system",
	"system_exec",
	"tail",
	"tan",
	"task_clock_start",
	"task_clock_stop",
	"task_create",
	"task_list",
	"task_schedule",
	"task_self",
	"task_status",
	"task_suspend",
	"task_yield",
	"time",
	"trace",
	"xor_bits"
}
