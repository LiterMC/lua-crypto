-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- sha256 hash API

local expect = require('cc.expect')

local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local brrotate, blshift, brshift = bit32.rrotate, bit32.lshift, bit32.rshift

local function uint32(n)
	return band(n, 0xffffffff)
end

local function bePutUint32(arr, n, offset)
	offset = offset or 0
	assert(n >= 0)
	arr[offset + 1] = band(brshift(n, 24), 0xff)
	arr[offset + 2] = band(brshift(n, 16), 0xff)
	arr[offset + 3] = band(brshift(n, 8), 0xff)
	arr[offset + 4] = band(n, 0xff)
end

local function bePutUint64(arr, n, offset)
	offset = offset or 0
	assert(n >= 0)
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

local Size = 32
local BlockSize = 64

local chunk = 64
local chunkMaskInv = bnot(chunk - 1)

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

local function block(digH, p, pStart, pEnd)
	local w = {} -- [64]uint32
	local h1, h2, h3, h4, h5, h6, h7, h8 = digH[1], digH[2], digH[3], digH[4], digH[5], digH[6], digH[7], digH[8]

	while pEnd - pStart + 1 >= chunk do
		for i = 1, 16 do
			local j = pStart + (i - 1) * 4
			w[i] = bor(blshift(p[j + 0], 24), blshift(p[j + 1], 16), blshift(p[j + 2], 8), p[j + 3])
			assert(w[i] >= 0)
		end
		for i = 17, 64 do
			local v1 = w[i-2]
			local t1 = bxor(brrotate(v1, 17), brrotate(v1, 19), brshift(v1, 10))
			local v2 = w[i-15]
			local t2 = bxor(brrotate(v2, 7), brrotate(v2, 18), brshift(v2, 3))
			w[i] = uint32(t1 + w[i-7] + t2 + w[i-16])
			assert(w[i] >= 0)
		end

		local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8

		for i = 1, 64 do
			local t1 = uint32(
				h +
				bxor(brrotate(e, 6), brrotate(e, 11), brrotate(e, 25)) +
				bxor(band(e, f), band(bnot(e), g)) +
				_K[i] +
				w[i]
			)
			assert(t1 >= 0)

			local t2 = uint32(
				bxor(brrotate(a, 2), brrotate(a, 13), brrotate(a, 22)) +
				bxor(band(a, b), band(a, c), band(b, c))
			)
			assert(t2 >= 0)

			h = g
			g = f
			f = e
			e = uint32(d + t1)
			d = c
			c = b
			b = a
			a = uint32(t1 + t2)
		end

		h1 = uint32(h1 + a)
		h2 = uint32(h2 + b)
		h3 = uint32(h3 + c)
		h4 = uint32(h4 + d)
		h5 = uint32(h5 + e)
		h6 = uint32(h6 + f)
		h7 = uint32(h7 + g)
		h8 = uint32(h8 + h)

		pStart = pStart + chunk
	end

	digH[1], digH[2], digH[3], digH[4], digH[5], digH[6], digH[7], digH[8] = h1, h2, h3, h4, h5, h6, h7, h8
end

local Digest = {}
Digest.mt = { __index = Digest }

function Digest:new(o)
	o = setmetatable(o or {}, self.mt)
	o.h = {} -- [8]uint32
	o.x = {} -- [chunk]byte
	o.nx = 0
	o.len = 0
	o:reset()
	return o
end

function Digest:reset()
	self.h[1] = init1
	self.h[2] = init2
	self.h[3] = init3
	self.h[4] = init4
	self.h[5] = init5
	self.h[6] = init6
	self.h[7] = init7
	self.h[8] = init8
	self.nx = 0
	self.len = 0
end

function Digest:size()
	return Size
end

function Digest:blockSize()
	return BlockSize
end

function Digest:copy(o)
	o = setmetatable(o or {}, getmetatable(self))
	o.h = {table.unpack(self.h)}
	o.x = {table.unpack(self.x)}
	o.nx = self.nx
	o.len = self.len
	return o
end

function Digest:update(data)
	expect(1, data, 'string', 'table')
	if type(data) == 'string' then
		data = {data:byte(1, -1)}
	end
	local di = 0
	local dlen = #data
	self.len = self.len + dlen
	if self.nx > 0 then
		local n = math.min(chunk - self.nx, dlen)
		table.move(data, 1, n, self.nx + 1, self.x)
		self.nx = self.nx + n
		if self.nx == chunk then
			block(self.h, self.x, 1, chunk + 1)
			self.nx = 0
		end
		di = di + n
	end
	if dlen - di >= chunk then
		local n = band(dlen - di, chunkMaskInv)
		block(self.h, data, di + 1, di + n)
		di = di + n
	end
	if dlen - di > 0 then
		local n = math.min(chunk, dlen - di)
		self.nx = n
		table.move(data, di + 1, di + n, 1, self.x)
	end
	return self
end

function Digest:sum()
	return self:copy():_sum()
end

function Digest:_sum()
	local len = self.len
	-- Padding. Add a 1 bit and 0 bits until 56 bytes mod 64.
	local t = 56 - len % 64
	if t <= 0 then
		t = t + 64
	end

	-- Length in bits.
	len = len * 8
	local padlen = setmetatable({ n = t + 8, 0x80 }, zeroArrMt)
	bePutUint64(padlen, len, t)
	self:update(padlen)

	assert(self.nx == 0)

	local h = self.h

	local digest = {}
	bePutUint32(digest, h[1], 0)
	bePutUint32(digest, h[2], 4)
	bePutUint32(digest, h[3], 8)
	bePutUint32(digest, h[4], 12)
	bePutUint32(digest, h[5], 16)
	bePutUint32(digest, h[6], 20)
	bePutUint32(digest, h[7], 24)
	bePutUint32(digest, h[8], 28)
	return digest
end

local function sum(data)
	return Digest:new():update(data):_sum()
end

return setmetatable({
	Digest = Digest,
	sum = sum,
}, {
	__call = function(_, ...)
		return sum(...)
	end
})
