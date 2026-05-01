
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local aes = require('crypto.aes')

local byte2hex = {}
for i = 0, 255 do
	local b = string.char(i)
	local h = string.format('%02x', i)
	byte2hex[b] = h
end

local function bytesToHex(s)
	local res = s:gsub('(.)', byte2hex)
	return res
end

local zeroKey = string.rep('\x00', 32)
local rainbowKey = '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'

local tests = {
	{zeroKey, aes.ECBStream, '', ''},
	{zeroKey, aes.ECBStream, 'abcdefghijklmnop', 'ac9c9eb761551ffb7d78d88b5e233014'},
	{rainbowKey, aes.ECBStream, 'abcdefghijklmnop', '0b0bfa882c3df2f57aff3fd9601ef4ce'},
	{zeroKey, aes.ECBStream, 'advancedperipherals-------------', 'd152776a67709d57c0d3d2ea2bd2f726b39d78f973c92cfbe7ed97d0c8055feb'},
	{zeroKey, aes.CBCStream, 'advancedperipherals-------------', 'd152776a67709d57c0d3d2ea2bd2f726795ad2649eacc08b705e8eb7e4153e73'},
	{zeroKey, aes.CTRStream, 'advancedperipherals-------------', 'bdf1b619cc23eceddd2dd07de2ec45f53263f9d6ea681b94844e99dce9e65ea6'},
	{zeroKey, aes.CFBStream, 'advancedperipherals-------------', 'bdf1b619cc23eceddd2dd07de2ec45f545bb482b8dac05658e96d631375ff094'},
	{zeroKey, aes.OFBStream, 'advancedperipherals-------------', 'bdf1b619cc23eceddd2dd07de2ec45f569af07a9a10faf1eef9e621e06ffc4fe'},
	{rainbowKey, aes.ECBStream, 'advancedperipherals-------------', '46488025f08e40fd8b8a8e0f8b006289ce90ab617441d212f2597f1ef61cdb82'},
	{rainbowKey, aes.CBCStream, 'advancedperipherals-------------', '46488025f08e40fd8b8a8e0f8b0062896afcac2df0cf2a02ecd05d3a6129a056'},
	{rainbowKey, aes.CTRStream, 'advancedperipherals-------------', '93f476d7442afab4d996e803ad4612f2913105836794b2c88bdbb61c65ef1b10'},
	{rainbowKey, aes.CFBStream, 'advancedperipherals-------------', '93f476d7442afab4d996e803ad4612f24cedf801b06ae482f2ec09eb646fe208'},
	{rainbowKey, aes.OFBStream, 'advancedperipherals-------------', '93f476d7442afab4d996e803ad4612f2b5851a08ed92e2d67fd58caac35a6786'},
	{zeroKey, aes.ECBStream, '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00', 'dc95c078a2408989ad48a21492842087'},
}

local passed = 0

for i, data in ipairs(tests) do
	local key, stream, input, expect = data[1], data[2], data[3], data[4]
	local o = bytesToHex(stream:new(nil, aes.Cipher:new(nil, key)):encrypt(input))
	if o ~= expect then
		printError(string.format('[%d] aes is %s, expect %s', i, o, expect))
	else
		passed = passed + 1
	end
end

print(string.format('Passed tests %d / %d', passed, #tests))
