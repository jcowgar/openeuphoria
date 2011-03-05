include std/unittest.e
include std/net/http.e
include std/search.e
include std/math.e
include std/os.e

ifdef not NOINET_TESTS then
	object content

	content = http_get("http://www.iana.org/domains/example/")
	if atom(content) then
		test_fail("get_url 1")
	else
		test_true("get_url 1", length(content) = 2)
		test_true("get_url 2", match("<title>", "" & content[2]))
	end if

	content = http_get("http://www.iana.org:80/domains/example/")
	if atom(content) then
		test_fail("get_url 2")
		test_fail("get_url 3")
	else
		test_true("get_url 3", length(content) = 2)
		test_true("get_url 4", match("<title>", "" & content[2]))
	end if

	-- Test nested sequence post data
    sequence num = sprintf("%d", { rand_range(1000,10000) })
	sequence data = {
		{ "data", num }
	}
    content = http_post("http://test.openeuphoria.org/post_test.ex", data)
	if atom(content) then
		test_fail("get_url post 1")
		test_fail("get_url post 2")
	else
		test_true("get_url post 1", length(content))
		test_equal("get_url post 2", "success", content[2])
	end if

	sequence headers = {
		{ "Cache-Control", "no-cache" }
	}
    content = http_get("http://test.openeuphoria.org/post_test.txt", headers)
	if atom(content) then
		test_fail("get_url post 3")
		test_fail("get_url post 4")
		test_fail("get_url post 5")
		test_fail("get_url post 6")
		test_fail("get_url post 7")
		test_fail("get_url post 8")
	else
		test_true("get_url post 3", length(content))
		test_equal("get_url post 4", "data=" & num, content[2])

		-- Test already encoded string
		num = sprintf("%d", { rand_range(1000,10000) })
		data = sprintf("data=%s", { num })
		content = http_post("http://test.openeuphoria.org/post_test.ex", data)
		test_true("get_url post 5", length(content))
		test_equal("get_url post 6", "success", content[2])

		content = http_get("http://test.openeuphoria.org/post_test.txt", headers)
		test_true("get_url post 7", length(content))
		test_equal("get_url post 8", "data=" & num, content[2])
	end if

	-- multipart form data
	sequence file_content = "Hello, World. This is an icon. I hope that this really works. I am not really sure but we will see"
	data = {
		{ "size", sprintf("%d", length(file_content)) },
		{ "file",  file_content, "example.txt", "text/plain", ENCODE_BASE64 }
	}

	-- post file script gets size and file parameters, calls decode_base64, and sends
	-- back SIZE\nDECODED_FILE_CONTENTS. The test script is written in Perl to test against
	-- modules we did not code, i.e. CGI and Base64 in this case.
	content = http_post("http://test.openeuphoria.org/post_file.cgi", { MULTIPART_FORM_DATA, data })
	if atom(content) then
		test_fail("multipart form file upload")
	else
		test_equal("multipart form file upload", data[1][2] & "\n" & file_content, content[2])
	end if
elsedef
    puts(2, " WARNING: URL tests were not run\n")
end ifdef

test_report()
