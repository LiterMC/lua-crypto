-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- sha1 hash API

local expect = require('cc.expect')

local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local blrotate, blshift, brshift = bit32.lrotate, bit32.lshift, bit32.rshift

local function low4bits(n)
	return band(n, 0xf)
end

local function uint32(n)
	return band(n, 0xffffffff)
end

local function bePutUint64(arr, n, offset)
	offset = offset or 0
	arr[offset + 1] = band(brshift(n, 56), 0xff)
	arr[offset + 2] = band(brshift(n, 48), 0xff)
	arr[offset + 3] = band(brshift(n, 40), 0xff)
	arr[offset + 4] = band(brshift(n, 32), 0xff)
	arr[offset + 5] = band(brshift(n, 24), 0xff)
	arr[offset + 6] = band(brshift(n, 16), 0xff)
	arr[offset + 7] = band(brshift(n, 8), 0xff)
	arr[offset + 8] = band(n, 0xff)
end

local zeroArrMt = {
	__index = function(arr, i)
		if i <= arr.n then
			return 0
		end
		return nil
	end,
	__len = function(arr)
		return arr.n
	end,
}

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

local function block(digH, p, pStart, pEnd)
	local w = {} -- [16]uint32
	local h1, h2, h3, h4, h5 = digH[1], digH[2], digH[3], digH[4], digH[5]

	while pEnd - pStart + 1 >= chunk do
		for i = 1, 16 do
			local j = pStart + (i - 1) * 4
			w[i] = bor(blshift(p[j + 0], 24), blshift(p[j + 1], 16), blshift(p[j + 2], 8), p[j + 3])
		end

		local a, b, c, d, e = h1, h2, h3, h4, h5

		-- Each of the four 20-iteration rounds
		-- differs only in the computation of f and
		-- the choice of K (_K0, _K1, etc).
		for i = 1, 16 do
			local f = bor(band(b, c), band(bnot(b), d))
			local t = uint32(blrotate(a, 5) + f + e + w[i] + _K0)
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 16, 19 do
			local tmp = bxor(w[1 + low4bits(i-3)], w[1 + low4bits(i-8)], w[1 + low4bits(i-14)], w[1 + low4bits(i)])
			w[1 + low4bits(i)] = blrotate(tmp, 1)

			local f = bor(band(b, c), band(bnot(b), d))
			local t = uint32(blrotate(a, 5) + f + e + w[1 + low4bits(i)] + _K0)
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 20, 39 do
			local tmp = bxor(w[1 + low4bits(i-3)], w[1 + low4bits(i-8)], w[1 + low4bits(i-14)], w[1 + low4bits(i)])
			w[1 + low4bits(i)] = blrotate(tmp, 1)
			local f = bxor(b, c, d)
			local t = uint32(blrotate(a, 5) + f + e + w[1 + low4bits(i)] + _K1)
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 40, 59 do
			local tmp = bxor(w[1 + low4bits(i-3)], w[1 + low4bits(i-8)], w[1 + low4bits(i-14)], w[1 + low4bits(i)])
			w[1 + low4bits(i)] = blrotate(tmp, 1)
			local f = bor(band(bor(b, c), d), band(b, c))
			local t = uint32(blrotate(a, 5) + f + e + w[1 + low4bits(i)] + _K2)
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end
		for i = 60, 79 do
			local tmp = bxor(w[1 + low4bits(i-3)], w[1 + low4bits(i-8)], w[1 + low4bits(i-14)], w[1 + low4bits(i)])
			w[1 + low4bits(i)] = blrotate(tmp, 1)
			local f = bxor(b, c, d)
			local t = uint32(blrotate(a, 5) + f + e + w[1 + low4bits(i)] + _K3)
			a, b, c, d, e = t, a, blrotate(b, 30), c, d
		end

		h1 = uint32(h1 + a)
		h2 = uint32(h2 + b)
		h3 = uint32(h3 + c)
		h4 = uint32(h4 + d)
		h5 = uint32(h5 + e)

		pStart = pStart + chunk
	end

	digH[1], digH[2], digH[3], digH[4], digH[5] = h1, h2, h3, h4, h5
end

local function newDigest()
	local digest = {}

	digest.size = SIZE
	digest.blockSize = BLOCK_SIZE

	digest._h = {} -- [8]uint32
	digest._x = {} -- [chunk]byte
	digest._nx = 0
	digest._len = 0

	function digest.reset()
		local h = digest._h
		h[1] = init1
		h[2] = init2
		h[3] = init3
		h[4] = init4
		h[5] = init5
		digest._nx = 0
		digest._len = 0
	end

	digest.reset()

	function digest.copy()
		local o = newDigest()
		o._h = {table.unpack(digest._h)}
		o._x = {table.unpack(digest._x)}
		o._nx = digest._nx
		o._len = digest._len
		return o
	end

	function digest.write(data)
		expect(1, data, 'string', 'number', 'table')
		if type(data) == 'string' then
			data = {data:byte(1, -1)}
		elseif type(data) == 'number' then
			data = {data}
		end

		local di = 0
		local dlen = #data
		digest._len = digest._len + dlen
		if digest._nx > 0 then
			local n = math.min(chunk - digest._nx, dlen)
			table.move(data, 1, n, digest._nx + 1, digest._x)
			digest._nx = digest._nx + n
			if digest._nx == chunk then
				block(digest._h, digest._x, 1, chunk + 1)
				digest._nx = 0
			end
			di = di + n
		end
		if dlen - di >= chunk then
			local n = band(dlen - di, chunkMaskInv)
			block(digest._h, data, di + 1, di + n)
			di = di + n
		end
		if dlen - di > 0 then
			local n = math.min(chunk, dlen - di)
			digest._nx = n
			table.move(data, di + 1, di + n, 1, digest._x)
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
		local padlen = setmetatable({ n = t + 8, 0x80 }, zeroArrMt)
		bePutUint64(padlen, len, t)
		digest.write(padlen)

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
