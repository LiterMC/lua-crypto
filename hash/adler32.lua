-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
--
-- adler32 hash API

local expect = require('cc.expect')

local band, bor = bit32.band, bit32.bor
local blshift, brshift = bit32.lshift, bit32.rshift
local strbyte = string.byte

local mod = 65521
local nmax = 8404782 -- 53 bits for double

local function update(lastSum, data)
	local s1, s2 = lastSum % 0x10000, brshift(lastSum, 16)

	if type(data) == 'number' then
		s1 = (s1 + data) % mod
		s2 = (s2 + s1) % mod
	else
		local length = #data
		local index = 1
		while index <= length do
			local maxIndex = length
			local maxChunk = index + nmax - 1
			if maxChunk < maxIndex then
				maxIndex = maxChunk
			end
			for i = index, maxIndex do
				s1 = s1 + strbyte(data, i)
				s2 = s2 + s1
			end
			s1 = s1 % mod
			s2 = s2 % mod
			index = maxIndex + 1
		end
	end
	return s1 + s2 * 0x10000
end

local function newDigest()
	local digest = {}
	digest._sum = 1

	function digest.reset()
		digest._sum = 1
	end

	function digest.copy()
		local o = newDigest()
		o._sum = digest._sum
		return o
	end

	function digest.write(data)
		expect(1, data, 'string', 'number')
		digest._sum = update(digest._sum, data)
		return digest
	end

	function digest.sum()
		return digest._sum
	end

	return digest
end

local function sum(data)
	expect(1, data, 'string', 'number')
	return update(1, data)
end

return setmetatable({
	newDigest = newDigest,
	sum = sum,
}, {
	__call = function(_, ...)
		return sum(...)
	end
})
