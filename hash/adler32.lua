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

local Digest = {}
Digest.mt = { __index = Digest }

function Digest:new(o, tab)
	o = setmetatable(o or {}, self.mt)
	o._sum = 1
	return o
end

function Digest:reset()
	self._sum = 1
end

local function update(lastSum, data)
	expect(1, data, 'string')
	local s1, s2 = uint16(lastSum), brshift(lastSum, 16)
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
	return bor(blshift(s2, 16), s1)
end

function Digest:update(data)
	expect(1, data, 'string')
	self._sum = update(self._sum, data)
	return self
end

function Digest:sum()
	return self._sum
end

local function sum(data)
	expect(1, data, 'string')
	return update(1, data)
end

return setmetatable({
	Digest = Digest,
	sum = sum,
}, {
	__call = function(_, ...)
		return sum(...)
	end
})
