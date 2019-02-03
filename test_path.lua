local zmod = require('z')
local windows = os.path.sep == '\\'


-----------------------------------------------------------------------
-- test normpath
-----------------------------------------------------------------------
function assert_posix(path, result)
	local x = os.path.normpath(path)
	print('[test] normpath: ('..path..') -> (' .. result .. ')')
	if x:gsub('\\', '/') ~= result then
		print('failed: "' .. x .. '" != "'..result.. '"')
		os.exit()
	else
		print('passed')
		print()
	end
end

function test_normpath_posix()
	assert_posix("", ".")
	assert_posix("/", "/")
	assert_posix("///", "/")
	assert_posix("///foo/.//bar//", "/foo/bar")
	assert_posix("///foo/.//bar//.//..//.//baz", "/foo/baz")
	assert_posix("///..//./foo/.//bar", "/foo/bar")
end

function assert_windows(path, result)
	local x = os.path.normpath(path)
	print('[test] normpath: ('..path..') -> (' .. result .. ')')
	if x ~= result then
		print('failed: "' .. x .. '" != "'..result.. '"')
		os.exit()
	else
		print('passed')
		print()
	end
end

function test_normpath_windows()
	assert_windows('A//////././//.//B',  'A\\B')
	assert_windows('A/./B',  'A\\B')
	assert_windows('A/foo/../B',  'A\\B')
	assert_windows('C:A//B',  'C:A\\B')
	assert_windows('D:A/./B',  'D:A\\B')
	assert_windows('e:A/foo/../B',  'e:A\\B')
	assert_windows('C:///A//B',  'C:\\A\\B')
	assert_windows('D:///A/./B',  'D:\\A\\B')
	assert_windows('e:///A/foo/../B',  'e:\\A\\B')
	assert_windows('..',  '..')
	assert_windows('.',  '.')
	assert_windows('',  '.')
	assert_windows('/',  '\\')
	assert_windows('c:/',  'c:\\')
	assert_windows('/../.././..',  '\\')
	assert_windows('c:/../../..',  'c:\\')
	assert_windows('../.././..',  '..\\..\\..')
	assert_windows('K:../.././..',  'K:..\\..\\..')
	assert_windows('C:////a/b',  'C:\\a\\b')
end

test_normpath_posix()

if windows then
	test_normpath_windows()
end


-----------------------------------------------------------------------
-- test path join
-----------------------------------------------------------------------
function assert_join_posix(segments, result, isnt)
	print('[test] join: '..zmod.dump(segments)..' -> (' .. result .. ')')
	local path = ''
	for _, item in ipairs(segments) do
		path = os.path.join(path, item)
	end
	if windows and (not isnt) then
		path = path:gsub('\\', '/')
	end
	if path ~= result then
		print('failed: "' .. path .. '"')
		os.exit()
	else
		print('passed')
	end
end

function assert_join_windows(segments, result)
	assert_join_posix(segments, result, 1)
end

function test_join_posix()
	assert_join_posix({"/foo", "bar", "/bar", "baz"}, "/bar/baz")
	assert_join_posix({"/foo", "bar", "baz"}, "/foo/bar/baz")
	assert_join_posix({"/foo/", "bar/", "baz/"}, "/foo/bar/baz/")
end

function test_join_windows()
	assert_join_windows({""}, '')
	assert_join_windows({"", "", ""}, '')
	assert_join_windows({"a"}, 'a')
	assert_join_windows({"/a"}, '/a')
	assert_join_windows({"\\a"}, '\\a')
	assert_join_windows({"a:"}, 'a:')
	assert_join_windows({"a:", "\\b"}, 'a:\\b')
	assert_join_windows({"a", "\\b"}, '\\b')
	assert_join_windows({"a", "b", "c"}, 'a\\b\\c')
	assert_join_windows({"a\\", "b", "c"}, 'a\\b\\c')
	assert_join_windows({"a", "b\\", "c"}, 'a\\b\\c')
	assert_join_windows({"a", "b", "\\c"}, '\\c')
	assert_join_windows({"d:\\", "\\pleep"}, 'd:\\pleep')
	assert_join_windows({"d:\\", "a", "b"}, 'd:\\a\\b')

	assert_join_windows({'', 'a'}, 'a')
	assert_join_windows({'', '', '', '', 'a'}, 'a')
	assert_join_windows({'a', ''}, 'a\\')
	assert_join_windows({'a', '', '', '', ''}, 'a\\')
	assert_join_windows({'a\\', ''}, 'a\\')
	assert_join_windows({'a\\', '', '', '', ''}, 'a\\')
	assert_join_windows({'a/', ''}, 'a/')

	assert_join_windows({'a/b', 'x/y'}, 'a/b\\x/y')
	assert_join_windows({'/a/b', 'x/y'}, '/a/b\\x/y')
	assert_join_windows({'/a/b/', 'x/y'}, '/a/b/x/y')
	assert_join_windows({'c:', 'x/y'}, 'c:x/y')
	assert_join_windows({'c:a/b', 'x/y'}, 'c:a/b\\x/y')
	assert_join_windows({'c:a/b/', 'x/y'}, 'c:a/b/x/y')
	assert_join_windows({'c:/', 'x/y'}, 'c:/x/y')
	assert_join_windows({'c:/a/b', 'x/y'}, 'c:/a/b\\x/y')
	assert_join_windows({'c:/a/b/', 'x/y'}, 'c:/a/b/x/y')

	assert_join_windows({'a/b', '/x/y'}, '/x/y')
	assert_join_windows({'/a/b', '/x/y'}, '/x/y')
	assert_join_windows({'c:', '/x/y'}, 'c:/x/y')
	assert_join_windows({'c:a/b', '/x/y'}, 'c:/x/y')
	assert_join_windows({'c:/', '/x/y'}, 'c:/x/y')
	assert_join_windows({'c:/a/b', '/x/y'}, 'c:/x/y')

	assert_join_windows({'c:', 'C:x/y'}, 'C:x/y')
	assert_join_windows({'c:a/b', 'C:x/y'}, 'C:a/b\\x/y')
	assert_join_windows({'c:/', 'C:x/y'}, 'C:/x/y')
	assert_join_windows({'c:/a/b', 'C:x/y'}, 'C:/a/b\\x/y')

	for _, x in ipairs({'', 'a/b', '/a/b', 'c:', 'c:a/b', 'c:/', 'c:/a/b'}) do
		for _, y in ipairs({'d:', 'd:x/y', 'd:/', 'd:/x/y'}) do
			assert_join_windows({x, y}, y)
		end
	end
end

test_join_posix()

if windows then
	test_join_windows()
end

