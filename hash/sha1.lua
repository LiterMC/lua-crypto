-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- sha1 hash API

local expect = require('cc.expect')

local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local blrotate, blshift, brshift = bit32.lrotate, bit32.lshift, bit32.rshift
local strbyte, strsub = string.byte, string.sub

local function bePutUint64(arr, n, offset)
	offset = offset or 0
	arr[offset + 1] = brshift(n, 56) % 0x100
	arr[offset + 2] = brshift(n, 48) % 0x100
	arr[offset + 3] = brshift(n, 40) % 0x100
	arr[offset + 4] = brshift(n, 32) % 0x100
	arr[offset + 5] = brshift(n, 24) % 0x100
	arr[offset + 6] = brshift(n, 16) % 0x100
	arr[offset + 7] = brshift(n, 8) % 0x100
	arr[offset + 8] = n % 0x100
end

local SIZE = 20
local BLOCK_SIZE = 64

local chunk = 64
local chunkMaskInv = bnot(chunk - 1)

local init1 = 0x67452301
local init2 = 0xEFCDAB89
local init3 = 0x98BADCFE
local init4 = 0x10325476
local init5 = 0xC3D2E1F0

local _K0 = 0x5A827999
local _K1 = 0x6ED9EBA1
local _K2 = 0x8F1BBCDC
local _K3 = 0xCA62C1D6

local function block(digH, p, pStart, pEnd, w)
	local h1, h2, h3, h4, h5 = digH[1], digH[2], digH[3], digH[4], digH[5]

	while pEnd - pStart + 1 >= chunk do
		for i = 1, 16 do
			local j = pStart + (i - 1) * 4
			local p1, p2, p3, p4 = strbyte(p, j, j + 3)
			w[i] = p1 * 0x1000000 + p2 * 0x10000 + p3 * 0x100 + p4
		end

		local a, b, c, d, e = h1, h2, h3, h4, h5

		-- Each of the four 20-iteration rounds
		-- differs only in the computation of f and
		-- the choice of K (_K0, _K1, etc).
		for i = 1, 16 do
			local f = bor(band(b, c), band(bnot(b), d))
			local t = (blrotate(a, 5) + f + e + w[i] + _K0) % 0x100000000
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 16, 19 do
			local tmp = bxor(w[1 + (i-3)%0x10], w[1 + (i-8)%0x10], w[1 + (i-14)%0x10], w[1 + (i)%0x10])
			w[1 + (i)%0x10] = blrotate(tmp, 1)

			local f = bor(band(b, c), band(bnot(b), d))
			local t = (blrotate(a, 5) + f + e + w[1 + (i)%0x10] + _K0) % 0x100000000
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 20, 39 do
			local tmp = bxor(w[1 + (i-3)%0x10], w[1 + (i-8)%0x10], w[1 + (i-14)%0x10], w[1 + (i)%0x10])
			w[1 + (i)%0x10] = blrotate(tmp, 1)
			local f = bxor(b, c, d)
			local t = (blrotate(a, 5) + f + e + w[1 + (i)%0x10] + _K1) % 0x100000000
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 40, 59 do
			local tmp = bxor(w[1 + (i-3)%0x10], w[1 + (i-8)%0x10], w[1 + (i-14)%0x10], w[1 + (i)%0x10])
			w[1 + (i)%0x10] = blrotate(tmp, 1)
			local f = bor(band(bor(b, c), d), band(b, c))
			local t = (blrotate(a, 5) + f + e + w[1 + (i)%0x10] + _K2) % 0x100000000
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 60, 79 do
			local tmp = bxor(w[1 + (i-3)%0x10], w[1 + (i-8)%0x10], w[1 + (i-14)%0x10], w[1 + (i)%0x10])
			w[1 + (i)%0x10] = blrotate(tmp, 1)
			local f = bxor(b, c, d)
			local t = (blrotate(a, 5) + f + e + w[1 + (i)%0x10] + _K3) % 0x100000000
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end

		h1 = (h1 + a) % 0x100000000
		h2 = (h2 + b) % 0x100000000
		h3 = (h3 + c) % 0x100000000
		h4 = (h4 + d) % 0x100000000
		h5 = (h5 + e) % 0x100000000

		pStart = pStart + chunk
	end

	digH[1], digH[2], digH[3], digH[4], digH[5] = h1, h2, h3, h4, h5
end

local function newDigest()
	local digest = {}

	digest.size = SIZE
	digest.blockSize = BLOCK_SIZE

	digest._h = {} -- [8]uint32
	digest._x = ''
	digest._len = 0
	local w = {}

	function digest.reset()
		local h = digest._h
		h[1] = init1
		h[2] = init2
		h[3] = init3
		h[4] = init4
		h[5] = init5
		digest._x = ''
		digest._len = 0
	end

	digest.reset()

	function digest.copy()
		local o = newDigest()
		o._h = {table.unpack(digest._h)}
		o._x = digest._x
		o._len = digest._len
		return o
	end

	function digest.write(data)
		expect(1, data, 'string', 'number')
		if type(data) == 'number' then
			data = string.char(data)
		end

		local di = 0
		local dlen = #data
		digest._len = digest._len + dlen
		local x = digest._x
		local nx = #x
		if nx > 0 then
			local n = chunk - nx
			if dlen < n then
				digest._x = x .. data
				return digest
			end
			di = di + n
			x = x .. strsub(data, 1, n)
			block(digest._h, x, 1, chunk + 1, w)
			digest._x = ''
		end
		local n = dlen - di
		if n >= chunk then
			local nn = n
			n = n % chunk
			local m = nn - n
			block(digest._h, data, di + 1, di + m, w)
			di = di + m
		end
		if n > 0 then
			digest._x = strsub(data, di + 1, di + n)
		end

		return digest
	end

	function digest.sum()
		return digest.copy()._sum()
	end

	function digest._sum()
		local len = digest._len
		-- Padding. Add a 1 bit and 0 bits until 56 bytes mod 64.
		local t = 56 - len % 64
		if t <= 0 then
			t = t + 64
		end

		-- Length in bits.
		len = len * 8
		local padlen = {0x80}
		for i = 2, t do
			padlen[i] = 0x00
		end
		bePutUint64(padlen, len, t)
		digest.write(string.char(table.unpack(padlen)))

		local h = digest._h
		return string.pack('>IIIII', h[1], h[2], h[3], h[4], h[5])
	end

	return digest
end

local function sum(data)
	return newDigest().write(data)._sum()
end

return setmetatable({
	SIZE = SIZE,
	BLOCK_SIZE = BLOCK_SIZE,
	newDigest = newDigest,
	sum = sum,
}, {
	__call = function(_, ...)
		return sum(...)
	end
})
