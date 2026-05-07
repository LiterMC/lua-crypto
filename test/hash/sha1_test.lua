
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local sha1 = require('hash.sha1')

local byte2hex = {}
for i = 0, 255 do
	local b = string.char(i)
	local h = string.format('%02x', i)
	byte2hex[b] = h
end

local function bytesToHex(s)
	local res = s:gsub('.', byte2hex)
	return res
end

local tests = {
	{'', 'da39a3ee5e6b4b0d3255bfef95601890afd80709'},
	{'abc', 'a9993e364706816aba3e25717850c26c9cd0d89d'},
	{'advancedperipherals', 'd39662afd96a61bf6ef170dd1628eb3041076038'},
	{'\x00', '5ba93c9db0cff93f52b521d7420e43f6eda2784f'},
	{
		'a very very very very very very very very very very very very very very very very long text',
		'eb7fc66067fe4bcc4ed481d96ce8c6d054cf94df',
	},
	{
		't h i s   t e x t   i s   e x a c t l y   56   bytes....',
		'7d9c153786fb36860be178b82866c0af41c37109',
	},
	{
		'super looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong text',
		'80a69c320683697ea371eaefb0c030915771995b',
	},
}

local passed = 0

for i, data in ipairs(tests) do
	local input, expect = data[1], data[2]
	local o = bytesToHex(sha1(input))
	if o ~= expect then
		printError(string.format('[%d] sha1 for %q is %s, expect %s', i, input, o, expect))
	else
		passed = passed + 1
	end
	os.queueEvent('')
	os.pullEvent('')
end

print(string.format('Passed tests %d / %d', passed, #tests))
