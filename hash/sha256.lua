-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- sha256 hash API

local expect = require('cc.expect')

local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local brrotate, blshift, brshift = bit32.rrotate, bit32.lshift, bit32.rshift
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

local SIZE = 32
local BLOCK_SIZE = 64

local chunk = 64

local init1 = 0x6A09E667
local init2 = 0xBB67AE85
local init3 = 0x3C6EF372
local init4 = 0xA54FF53A
local init5 = 0x510E527F
local init6 = 0x9B05688C
local init7 = 0x1F83D9AB
local init8 = 0x5BE0CD19

local _K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}

local function block(digH, p, pStart, pEnd, w)
	local h1, h2, h3, h4, h5, h6, h7, h8 = digH[1], digH[2], digH[3], digH[4], digH[5], digH[6], digH[7], digH[8]

	while pEnd - pStart + 1 >= chunk do
		for i = 1, 16 do
			local j = pStart + (i - 1) * 4
			local p1, p2, p3, p4 = strbyte(p, j, j + 3)
			w[i] = p1 * 0x1000000 + p2 * 0x10000 + p3 * 0x100 + p4
		end
		for i = 17, 64 do
			local v1 = w[i-2]
			local t1 = bxor(brrotate(v1, 17), brrotate(v1, 19), brshift(v1, 10))
			local v2 = w[i-15]
			local t2 = bxor(brrotate(v2, 7), brrotate(v2, 18), brshift(v2, 3))
			w[i] = (t1 + w[i-7] + t2 + w[i-16]) % 0x100000000
		end

		local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8

		for i = 1, 64 do
			local t1 = (
				h +
				bxor(brrotate(e, 6), brrotate(e, 11), brrotate(e, 25)) +
				bxor(band(e, f), band(bnot(e), g)) +
				_K[i] +
				w[i]
			) % 0x100000000

			local t2 = (
				bxor(brrotate(a, 2), brrotate(a, 13), brrotate(a, 22)) +
				bxor(band(a, b), band(a, c), band(b, c))
			) % 0x100000000

			h = g
			g = f
			f = e
			e = (d + t1) % 0x100000000
			d = c
			c = b
			b = a
			a = (t1 + t2) % 0x100000000
		end

		h1 = (h1 + a) % 0x100000000
		h2 = (h2 + b) % 0x100000000
		h3 = (h3 + c) % 0x100000000
		h4 = (h4 + d) % 0x100000000
		h5 = (h5 + e) % 0x100000000
		h6 = (h6 + f) % 0x100000000
		h7 = (h7 + g) % 0x100000000
		h8 = (h8 + h) % 0x100000000

		pStart = pStart + chunk
	end

	digH[1], digH[2], digH[3], digH[4], digH[5], digH[6], digH[7], digH[8] = h1, h2, h3, h4, h5, h6, h7, h8
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
		h[6] = init6
		h[7] = init7
		h[8] = init8
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
		return string.pack('>IIIIIIII', h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8])
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
