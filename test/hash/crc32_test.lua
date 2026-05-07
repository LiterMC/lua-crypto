
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local crc32 = require('hash.crc32')

local function hex(n)
	return string.format('%08x', n)
end

local tests = {
	{'', '00000000'},
	{'abc', '352441c2'},
	{'12345678', '9ae0daaf'},
	{'advancedperipherals', 'b0b2c566'},
	{'\x00', 'd202ef8d'},
	{
		'a very very very very very very very very very very very very very very very very long text',
		'971f2601',
	},
	{
		'super looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong text',
		'2f25050c',
	},
}

local passed = 0

for _, data in ipairs(tests) do
	local input, expect = data[1], data[2]
	local o = hex(crc32(input))
	if o ~= expect then
		printError(string.format('crc32 for %q is %s, expect %s', input, o, expect))
	else
		passed = passed + 1
	end
	os.queueEvent('')
	os.pullEvent('')
end

print(string.format('Passed tests %d / %d', passed, #tests))
