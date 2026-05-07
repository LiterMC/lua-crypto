
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local sha256 = require('hash.sha256')

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
	{'', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'},
	{'abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'},
	{'advancedperipherals', '4d25c4a9a2f226e6063e42a394d4a63b1c4f9cfd6073634dfa827692a083841d'},
	{'\x00', '6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d'},
	{
		'a very very very very very very very very very very very very very very very very long text',
		'b2faf12c2e4dd5ab8d147912cd271e5a3a9fdb99880ba1c33cdc8d2c510dd491',
	},
	{
		't h i s   t e x t   i s   e x a c t l y   56   bytes....',
		'f427ad51d400d1f8d3b03c598d25f806ef108a7c13ba3a18261df5e388fa18dc',
	},
	{
		'super looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong text',
		'0725e15a01d4e60a15c995e2250b92fe6e466fe6b30d7f25ad29327105e66dab',
	},
}

local passed = 0

for i, data in ipairs(tests) do
	local input, expect = data[1], data[2]
	local o = bytesToHex(sha256(input))
	if o ~= expect then
		printError(string.format('[%d] sha256 for %q is %s, expect %s', i, input, o, expect))
	else
		passed = passed + 1
	end
	os.queueEvent('')
	os.pullEvent('')
end

print(string.format('Passed tests %d / %d', passed, #tests))
