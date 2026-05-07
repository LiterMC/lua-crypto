
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local adler32 = require('hash.adler32')

local function hex(n)
	return string.format('%08x', n)
end

local tests = {
	{'', '00000001'},
	{'abc', '024d0127'},
	{'12345678', '074001a5'},
	{'advancedperipherals', '4d9c07d6'},
	{'\x00', '00010001'},
	{
		'a very very very very very very very very very very very very very very very very long text',
		'29332277',
	},
	{
		'super looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong text',
		'c73541bb',
	},
}

local passed = 0

for _, data in ipairs(tests) do
	local input, expect = data[1], data[2]
	local o = hex(adler32(input))
	if o ~= expect then
		printError(string.format('adler32 for %q is %s, expect %s', input, o, expect))
	else
		passed = passed + 1
	end
	os.queueEvent('')
	os.pullEvent('')
end

print(string.format('Passed tests %d / %d', passed, #tests))
