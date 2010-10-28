include std/unittest.e
include std/net/http.e
include std/search.e
include std/math.e
include std/os.e

ifdef not NOINET_TESTS then
	sequence content

	content = http_get("http://example.com")
	test_true("get_url 1", length(content) = 2)
	test_true("get_url 2", match("<TITLE>Example Web Page</TITLE>", "" & content[2]))

	content = http_get("http://example.com:80/")
	test_true("get_url 3", length(content) = 2)
	test_true("get_url 4", match("<TITLE>Example Web Page</TITLE>", "" & content[2]))

    sequence num = sprintf("%d", { rand_range(1000,10000) })
	sequence data = {
		{ "data", num }
	}
    content = http_post("http://test.openeuphoria.org/post_test.ex", data)
	test_true("get_url post 1", length(content))
	test_equal("get_url post 2", "success", content[2])

	sequence headers = {
		{ "Cache-Control", "no-cache" }
	}
    content = http_get("http://test.openeuphoria.org/post_test.txt", headers)
	test_true("get_url post 3", length(content))
	test_equal("get_url post 4", "data=" & num, content[2])
elsedef
    puts(2, " WARNING: URL tests were not run\n")
end ifdef

test_report()
