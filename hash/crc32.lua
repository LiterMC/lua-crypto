-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- crc32 hash API

local expect = require('cc.expect')

local band, bor, bxor, bnot =
	bit.band, bit.bor, bit.bxor, bit.bnot
local blshift, brshift = bit.blshift, bit.blogic_rshift

local function uint8(v)
	return band(v, 0xff)
end

local function simplePopulateTable(poly, t)
	for i = 0, 255 do
		local crc = i
		for j = 0, 7 do
			if crc % 2 == 1 then
				crc = bxor(brshift(crc, 1), poly)
			else
				crc = brshift(crc, 1)
			end
		end
		t[1 + i] = crc
	end
end

local function simpleUpdate(crc, tab, p)
	crc = bnot(crc)
	for i = 1, #p do
		crc = bxor(tab[1 + bxor(uint8(crc), p:byte(i))], brshift(crc, 8))
	end
	return bnot(crc)
end

local function makeTable(poly)
	local t = {}
	simplePopulateTable(poly, t)
	return t
end

local function slicingMakeTable(poly)
	local t = {}
	t[1] = makeTable(poly)
	for i = 2, 8 do t[i] = {} end
	for j = 1, 256 do
		local crc = t[1][j]
		for i = 2, 8 do
			crc = bxor(t[1][1 + uint8(crc)], brshift(crc, 8))
			t[i][j] = crc
		end
	end
	return t
end

local slicing8Cutoff = 16

local function slicingUpdate(crc, tab, p)
	if #p >= slicing8Cutoff then
		crc = bnot(crc)
		while #p > 8 do
			crc = bxor(crc, bor(p:byte(1), bor(blshift(p:byte(2), 8), bor(blshift(p:byte(3), 16), blshift(p:byte(4), 24)))))
			crc = bxor(tab[1][1 + p:byte(8)], bxor(tab[2][1 + p:byte(7)], bxor(tab[3][1 + p:byte(6)], bxor(tab[4][1 + p:byte(5)],
			bxor(tab[5][1 + brshift(crc, 24)], bxor(tab[6][1 + uint8(brshift(crc, 16))],
			bxor(tab[7][1 + uint8(brshift(crc, 8))], bxor(tab[8][1 + uint8(crc)]))))))))
			p = p:sub(9)
		end
		crc = bnot(crc)
	end
	if #p == 0 then
		return crc
	end
	return simpleUpdate(crc, tab[1], p)
end

local IEEE = 0xedb88320
local ieeeTable8 = slicingMakeTable(IEEE)
local IEEETable = ieeeTable8[1]

local Digest = {}
Digest.mt = { __index = Digest }

function Digest:new(o, tab)
	o = setmetatable(o or {}, self.mt)
	o.crc = 0
	o.tab = tab or IEEETable
	return o
end

function Digest:reset()
	self.crc = 0
end

function Digest:update(data)
	expect(1, data, 'string')
	if self.tab == IEEETable then
		self.crc = slicingUpdate(self.crc, ieeeTable8, data)
		return self
	end
	self.crc = simpleUpdate(self.crc, self.tab, data)
	return self
end

function Digest:sum()
	return self.crc
end

local function sumIEEE(data)
	expect(1, data, 'string')
	return slicingUpdate(0, ieeeTable8, data)
end

return {
	IEEE = IEEE,
	IEEETable = IEEETable,
	Digest = Digest,
	sumIEEE = sumIEEE,
}
