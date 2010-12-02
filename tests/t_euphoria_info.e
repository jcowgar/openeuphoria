atom my_start_time = time()

include std/unittest.e
include euphoria/info.e

test_true("version #1", version() >= 400)
test_true("version_major #1", version_major() >= 4)
test_true("version_minor #1", version_minor() >= 0)
test_true("version_patch #1", version_patch() >= 0)
test_true("version_type #1", sequence(version_type()))
test_true("version_type #2", length(version_type()) > 0)
test_true("version_string #1", sequence(version_string()))
test_true("version_string #2", length(version_string()) > 0)
test_true("version_string_short #1", sequence(version_string_short()))
test_true("version_string_short #2", length(version_string_short()) > 0)
test_true("version_string_long #1", sequence(version_string_long()))
test_true("version_string_long #2", length(version_string_long()) > 0)
test_true("platform_name #1", sequence(platform_name()))
test_true("platform_name #2", length(platform_name()) > 0)
test_true("start_time", my_start_time >= start_time())
test_true("euphoria_copyright #1", sequence(euphoria_copyright()))
test_true("euphoria_copyright #2", length(euphoria_copyright()) = 2)
test_true("pcre_copyright #1", sequence(pcre_copyright()))
test_true("pcre_copyright #2", length(pcre_copyright()) = 2)

object copyrights = all_copyrights()
test_true("all_copyrights #1", sequence(copyrights))
test_true("all_copyrights #2", length(copyrights) >= 1)
test_true("all_copyrights #3", length(copyrights[1]) = 2)
