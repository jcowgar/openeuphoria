include std/unittest.e

sequence base_demos = {
	"allsorts.ex",
	"animal.ex",
	"ascii.ex",
	"buzz.ex",
	"callmach.ex",
	"color.ex",
	"csort.ex",
	"eused.ex",
	"guru.ex",
	"hash.ex",
	"loaddb.ex",
	"mydata.ex",
	"news.ex",
	"pipes.ex",
	"pipe_sub.ex",
	"queens.ex",
	"regexps.ex",
	"sanity.ex",
	"search.ex",
	"tree.ex",
	"where.ex",
	"bench/sieve8k.ex",
	"langwar/lw.ex",
	"net/chat_client.ex",
	"net/chat_server.ex",
	"net/google_tts.ex",
	"net/httpd.ex",
	"net/irc_chat.ex",
	"net/pastey.ex",
	"net/sock_client.ex",
	"net/sock_server.ex",
	"net/udp_client.ex",
	"net/udp_server.ex",
	"net/wget.ex",
	"preproc/datesub.ex",
	"preproc/etml.ex",
	"preproc/etmltest.ex",
	"preproc/literate.ex",
	"preproc/make40.ex",
	$
}

sequence additional_demos = {}
ifdef WINDOWS then
	additional_demos = {
		"win32/dsearch.exw",
		"win32/email.exw",
		"win32/taskwire.exw",
		"win32/window.exw",
		"win32/winwire.exw",
		$
	}
elsifdef UNIX then
	additional_demos = {
		"unix/callc.ex",
		"unix/mylib.ex",
		"unix/qsort.ex",
		$
	}
end ifdef

constant demos = base_demos & additional_demos

constant base_bins = {
	"analyze.ex",
	"bench.ex",
	"bugreport.ex",
	"buildcpdb.ex",
	"ed.ex",
	"eprint.ex",
	"eucoverage.ex",
	"key.ex",
	"lines.ex",
	$
}

sequence additional_bins = {}
ifdef WINDOWS then
	additional_bins = {}
elsifdef UNIX then
	additional_bins = {}
end ifdef

constant bins = base_bins & additional_bins

constant cline = command_line()

for i = 1 to length(demos) do
	integer r = system_exec(sprintf("%s -test ../demo/%s", { cline[1], demos[i] }))
	test_false(sprintf("demo -test %s", { demos[i] }), r)
end for

for i = 1 to length(bins) do
	integer r = system_exec(sprintf("%s -test ../bin/%s", { cline[1], bins[i] }))
	test_false(sprintf("bin -test %s", { bins[i] }), r)
end for

test_report()
