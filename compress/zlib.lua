-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- Zilb implemention
-- See [RFC1950](https://www.rfc-editor.org/rfc/rfc1950.html)

local expect = require('cc.expect')

local flate = require('compress.flate')
local adler32 = require('hash.adler32')

local band, bor =
	bit32.band, bit32.bor
local blshift, brshift = bit32.lshift, bit32.rshift

local function bytes2uint32(a, b, c, d)
	return bor(blshift(a, 24), blshift(b, 16), blshift(c, 8), d)
end

-- ERR_CHECKSUM is returned when reading ZLIB data that has an invalid checksum.
local ERR_CHECKSUM = 'zlib: invalid checksum'
-- ERR_DICTIONARY is returned when reading ZLIB data that has an invalid dictionary.
local ERR_DICTIONARY = 'zlib: invalid dictionary'
-- ERR_HEADER is returned when reading ZLIB data that has an invalid header.
local ERR_HEADER = 'zlib: invalid header'

local zlibDeflate = 0x8
local zlibMaxWindow = 7

local function newReader(rawReader, dict)
	if not rawReader.read then
		expect(1, rawReader, 'reader')
	end
	expect(2, dict, 'string', 'nil')

	local reader = {}

	local windowSize = zlibMaxWindow
	do
		local cmf = rawReader.read()
		local flg = rawReader.read()

		local cm = band(cmf, 0x0f)
		local cinfo = brshift(cmf, 4)
		if cm ~= zlibDeflate or cinfo > zlibMaxWindow or bor(blshift(cmf, 8), flg) % 31 ~= 0 then
			error(ERR_HEADER, 2)
		end
		windowSize = cinfo

		local haveDict = band(flg, 0x20) ~= 0
		if haveDict then
			local checksum = bytes2uint32(rawReader.read(4):byte(1, 4))
			if checksum ~= adler32(dict) then
				error(ERR_DICTIONARY, 2)
			end
		end
	end

	local decompresser = flate.newReader(rawReader, dict, blshift(1, windowSize + 8))

	local digest = adler32.Digest:new()
	local checked = nil

	local function finishRead()
		if checked == nil then
			local checksum = bytes2uint32(rawReader.read(4):byte(1, 4))
			checked = checksum == digest:sum()
		end
		if not checked then
			error(ERR_CHECKSUM, 2)
		end
	end

	function reader.read(count)
		local d = decompresser.read(count)
		if not d then
			finishRead()
			return nil
		end
		if count then
			digest:update(d)
		else
			digest:update(string.char(d))
		end
		return d
	end

	function reader.readAll()
		local d = decompresser.readAll()
		digest:update(d)
		finishRead()
		return d
	end

	return reader
end

return {
	ERR_CHECKSUM = ERR_CHECKSUM,
	ERR_DICTIONARY = ERR_DICTIONARY,
	ERR_HEADER = ERR_HEADER,
	newReader = newReader,
}
