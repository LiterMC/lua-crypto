-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
--
-- adler32 hash API

local expect = require('cc.expect')

local band, bor = bit32.band, bit32.bor
local blshift, brshift = bit32.lshift, bit32.rshift

local function uint16(v)
	return band(v, 0xffff)
end

local function uint32(v)
	return band(v, 0xffffffff)
end

local mod = 65521
local nmax = 5552

local function update(lastSum, data)
	local s1, s2 = uint16(lastSum), brshift(lastSum, 16)

	if type(data) == 'number' then
		s1 = uint32(s1 + data) % mod
		s2 = uint32(s2 + s1) % mod
	else
		local p = data
		while #p > 0 do
			local q = ''
			if #p > nmax then
				p, q = p:sub(1, nmax), p:sub(nmax + 1)
			end
			while #p >= 4 do
				s1 = uint32(s1 + p:byte(1))
				s2 = uint32(s2 + s1)
				s1 = uint32(s1 + p:byte(2))
				s2 = uint32(s2 + s1)
				s1 = uint32(s1 + p:byte(3))
				s2 = uint32(s2 + s1)
				s1 = uint32(s1 + p:byte(4))
				s2 = uint32(s2 + s1)
				p = p:sub(5)
			end
			for i = 1, #p do
				s1 = uint32(s1 + p:byte(i))
				s2 = uint32(s2 + s1)
			end
			s1 = s1 % mod
			s2 = s2 % mod
			p = q
		end
	end
	return bor(blshift(s2, 16), s1)
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
