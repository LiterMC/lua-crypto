-- Copyright 2009 The Go Authors. All rights reserved.
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file.
-- Translate by zyxkad@gmail.com
--
-- Deflate implemention
-- See [RFC1951](https://www.rfc-editor.org/rfc/rfc1951.html)

local expect = require('cc.expect')

local band, bor, bnot =
	bit32.band, bit32.bor, bit32.bnot
local blshift, brshift = bit32.lshift, bit32.rshift
local strbyte, strchar, strsub = string.byte, string.char, string.sub

local POWER2 = {}
do
	local n = 1
	for i = 1, 32 do
		n = n * 2
		POWER2[i] = n
	end
end

local function bytes2uint16LE(a, b)
	return a + b * 0x100
end

local rev8tab = {
	strbyte(
		'\x00\x80\x40\xc0\x20\xa0\x60\xe0\x10\x90\x50\xd0\x30\xb0\x70\xf0' ..
		'\x08\x88\x48\xc8\x28\xa8\x68\xe8\x18\x98\x58\xd8\x38\xb8\x78\xf8' ..
		'\x04\x84\x44\xc4\x24\xa4\x64\xe4\x14\x94\x54\xd4\x34\xb4\x74\xf4' ..
		'\x0c\x8c\x4c\xcc\x2c\xac\x6c\xec\x1c\x9c\x5c\xdc\x3c\xbc\x7c\xfc' ..
		'\x02\x82\x42\xc2\x22\xa2\x62\xe2\x12\x92\x52\xd2\x32\xb2\x72\xf2' ..
		'\x0a\x8a\x4a\xca\x2a\xaa\x6a\xea\x1a\x9a\x5a\xda\x3a\xba\x7a\xfa' ..
		'\x06\x86\x46\xc6\x26\xa6\x66\xe6\x16\x96\x56\xd6\x36\xb6\x76\xf6' ..
		'\x0e\x8e\x4e\xce\x2e\xae\x6e\xee\x1e\x9e\x5e\xde\x3e\xbe\x7e\xfe' ..
		'\x01\x81\x41\xc1\x21\xa1\x61\xe1\x11\x91\x51\xd1\x31\xb1\x71\xf1' ..
		'\x09\x89\x49\xc9\x29\xa9\x69\xe9\x19\x99\x59\xd9\x39\xb9\x79\xf9' ..
		'\x05\x85\x45\xc5\x25\xa5\x65\xe5\x15\x95\x55\xd5\x35\xb5\x75\xf5' ..
		'\x0d\x8d\x4d\xcd\x2d\xad\x6d\xed\x1d\x9d\x5d\xdd\x3d\xbd\x7d\xfd' ..
		'\x03\x83\x43\xc3\x23\xa3\x63\xe3\x13\x93\x53\xd3\x33\xb3\x73\xf3' ..
		'\x0b\x8b\x4b\xcb\x2b\xab\x6b\xeb\x1b\x9b\x5b\xdb\x3b\xbb\x7b\xfb' ..
		'\x07\x87\x47\xc7\x27\xa7\x67\xe7\x17\x97\x57\xd7\x37\xb7\x77\xf7' ..
		'\x0f\x8f\x4f\xcf\x2f\xaf\x6f\xef\x1f\x9f\x5f\xdf\x3f\xbf\x7f\xff',
		1, -1
	)
}

local function reverse8(n)
	return rev8tab[1 + n]
end

local function reverse16(n)
	return rev8tab[1 + brshift(n, 8)] + rev8tab[1 + n % 0x100] * 0x100
end

local function mustRead(reader, count, errMessage)
	local data = reader.read(count)
	if not data or count and #data < count then
		error(errMessage or 'EOF', 2)
	end
	return data
end

local function newBitsReader(rawReader)
	if not rawReader.read then
		expect(4, rawReader, 'reader')
	end

	local bitsReader = {}

	local bits = 0
	local bitN = 0

	function bitsReader.readBits(count)
		while bitN < count do
			local d = rawReader.read()
			if not d then
				return nil
			end
			bits = bor(bits, blshift(d, bitN))
			bitN = bitN + 8
		end
		local b = band(bits, blshift(1, count) - 1)
		bits = brshift(bits, count)
		bitN = bitN - count
		return b
	end

	function bitsReader.discard()
		bits = 0
		bitN = 0
	end

	return bitsReader
end

local function newDictDecoder(maxBits, symTable)
	expect(1, maxBits, 'number')
	expect(2, symTable, 'table')

	local dictDecoder = {}

	function dictDecoder.readFrom(bitsReader)
		local code = 0
		for bits = 1, maxBits do
			local bitval = bitsReader.readBits(1)
			if not bitval then
				error('EOF', 2)
			end
			code = bor(code, blshift(bitval, bits - 1))
			local symbol = symTable[1 + code]
			if symbol and band(symbol, 0xf) == bits then
				return brshift(symbol, 4)
			end
		end
		error('flate: invalid huffman code')
	end

	return dictDecoder
end

local MAX_NUM_DIST = 30
local MAX_MATCH_OFFSET = 32768

local CODE_ORDER = {17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16}

local function buildHuffmanTable(lengths, startIndex, endIndex)
	startIndex = startIndex or 1
	endIndex = endIndex or #lengths
	local count = {}
	local min, max = nil, 0
	for i = startIndex, endIndex do
		local len = lengths[i]
		if len ~= 0 then
			if min == nil or min > len then
				min = len
			end
			if max < len then
				max = len
			end
			count[len] = (count[len] or 0) + 1
		end
	end

	if max == 0 then
		return 0, {}
	end

	local code = 0
	local nextcode = {}	
	for i = min, max do
		code = code * 2
		nextcode[i] = code
		code = code + (count[i] or 0)
	end

	if code ~= POWER2[max] and not (code == 1 and max == 1) then
		error('flate: incorrect huffman lengths ' .. code .. ' ' .. max)
	end

	local symTable = {}
	for i = startIndex, endIndex do
		local sym = i - startIndex
		local len = lengths[i]
		if len > 0 then
			local code = nextcode[len] or 0
			nextcode[len] = code + 1
			local chunk = sym * 0x10 + len
			local reverse = brshift(reverse16(code), 16 - len)

			-- Fill all entries that match this prefix
			local lenp = POWER2[len]
			local fill = bor(1, max - len)
			for j = 0, fill - 1 do
				symTable[1 + bor(reverse, j * lenp)] = chunk
			end
		end
	end

	return max, symTable
end

local function createFixedHuffmanDecoder()
	-- These come from the RFC section 3.2.6.
	local bits = {}
	for i = 1, 144 do
		bits[i] = 8
	end
	for i = 145, 256 do
		bits[i] = 9
	end
	for i = 257, 280 do
		bits[i] = 7
	end
	for i = 281, 288 do
		bits[i] = 8
	end
	return newDictDecoder(buildHuffmanTable(bits))
end

local FIXED_HUFFMAN_DECODER = createFixedHuffmanDecoder()
local MAX_NUM_LIT = 286
local MAX_OUTPUT_BUFFER = 1024

local function newReader(rawReader, dict, windowSize)
	if not rawReader.read then
		expect(1, rawReader, 'reader')
	end
	expect(2, dict, 'string', 'nil')
	expect(3, windowSize, 'number')
	windowSize = windowSize or MAX_MATCH_OFFSET

	local reader = {}

	local bitsReader = newBitsReader(rawReader)
	local isFinal = false

	local YIELD_DATA_SYM = {}

	local history = ''
	local historyLen = 0
	local outputBuf = ''
	local outputBufLen = 0

	local function output(d)
		local dl = #d
		local i = dl - windowSize
		if i >= 0 then
			history = strsub(d, i + 1)
			historyLen = dl
		else
			i = i + historyLen
			if i <= 0 then
				history = history .. d
				historyLen = historyLen + dl
			else
				history = strsub(history, i + 1) .. d
			end
		end
		if outputBufLen + dl >= MAX_OUTPUT_BUFFER then
			if outputBufLen > 0 then
				coroutine.yield(YIELD_DATA_SYM, outputBuf)
				outputBuf = ''
				outputBufLen = 0
			end
			outputBuf = d
			outputBufLen = dl
		else
			outputBuf = outputBuf .. d
			outputBufLen = outputBufLen + dl
		end
	end

	local function blockReader()
		isFinal = bitsReader.readBits(1) ~= 0
		local typ = bitsReader.readBits(2)
		if typ == 0 then
			-- no compression
			bitsReader.discard()
			local len = bytes2uint16LE(strbyte(mustRead(rawReader, 2), 1, 2))
			local lenR = bytes2uint16LE(strbyte(mustRead(rawReader, 2), 1, 2))
			if lenR ~= band(bnot(len), 0xffff) then
				error('flate: corrupt input at uncompressed block')
			end
			if len == 0 then
				return
			end
			output(rawReader.read(len))
			return
		elseif typ == 3 then
			-- 3 is reserved
			error('flate: unexpected data block type 0x3')
		end
		local decoder
		local distDecoder = nil
		if typ == 1 then
			-- compressed, fixed Huffman tables
			decoder = FIXED_HUFFMAN_DECODER
		else
			-- compressed, dynamic Huffman tables
			local nlit = bitsReader.readBits(5) + 257
			if nlit > MAX_NUM_LIT then
				error('flate: unexpected huffman nlit ' .. nlit)
			end
			local ndist = bitsReader.readBits(5) + 1
			if ndist > 30 then
				error('flate: unexpected huffman ndist ' .. ndist)
			end
			local nclen = bitsReader.readBits(4) + 4

			local codebits = {}
			-- (HCLEN+4)*3 bits: code lengths in the magic codeOrder order.
			for i = 1, nclen do
				codebits[CODE_ORDER[i]] = bitsReader.readBits(3)
			end
			for i = nclen + 1, #CODE_ORDER do
				codebits[CODE_ORDER[i]] = 0
			end

			local hclen = newDictDecoder(buildHuffmanTable(codebits))

			local bits = {}
			-- HLIT + 257 code lengths, HDIST + 1 code lengths,
			-- using the code length Huffman code.
			local i, n = 1, nlit + ndist
			while i <= n do
				local x = hclen.readFrom(bitsReader)
				if x < 16 then
					-- Actual length.
					bits[i] = x
					i = i + 1
				else
					-- Repeat previous length or zero.
					local rep, nb, b
					if x == 16 then
						if i == 1 then
							error('flate: corrupt huffman header')
						end
						rep = 3
						nb = 2
						b = bits[i - 1]
					elseif x == 17 then
						rep = 3
						nb = 3
						b = 0
					elseif x == 18 then
						rep = 11
						nb = 7
						b = 0
					else
						error('flate: corrupt huffman header: unexpected length code ' .. x)
					end
					rep = rep + bitsReader.readBits(nb)
					if i + rep > n + 1 then
						error('flate: corrupt huffman header')
					end
					for _ = 1, rep do
						bits[i] = b
						i = i + 1
					end
				end
			end

			decoder = newDictDecoder(buildHuffmanTable(bits, 1, nlit))
			distDecoder = newDictDecoder(buildHuffmanTable(bits, nlit + 1, n))
		end

		while true do
			local sym = decoder.readFrom(bitsReader)
			if sym == 256 then
				break
			end
			if sym < 256 then
				output(strchar(sym))
			else
				local length, n
				if sym < 265 then
					length = sym - (257 - 3)
					n = 0
				elseif sym < 269 then
					length = sym*2 - (265*2 - 11)
					n = 1
				elseif sym < 273 then
					length = sym*4 - (269*4 - 19)
					n = 2
				elseif sym < 277 then
					length = sym*8 - (273*8 - 35)
					n = 3
				elseif sym < 281 then
					length = sym*16 - (277*16 - 67)
					n = 4
				elseif sym < 285 then
					length = sym*32 - (281*32 - 131)
					n = 5
				elseif sym < MAX_NUM_LIT then
					length = 258
					n = 0
				else
					error('flate: unexpected symbol ' .. sym)
				end
				length = length + bitsReader.readBits(n)
				local dist
				if typ == 1 then
					dist = reverse8(blshift(bitsReader.readBits(5), 3))
				else
					dist = distDecoder.readFrom(bitsReader)
				end

				if dist < 4 then
					dist = dist + 1
				elseif dist < MAX_NUM_DIST then
					local nb = brshift(dist - 2, 1)
					-- have 1 bit in bottom of dist, need nb more.
					local extra = blshift(band(dist, 1), nb)
					extra = bor(extra, bitsReader.readBits(nb))
					dist = blshift(1, nb + 1) + 1 + extra
				else
					error('flate: unexpected distance value ' .. dist)
				end
				if dist > historyLen then
					error(string.format('flate: distance ' .. dist .. ' overflowed ' .. historyLen))
				end
				while length > dist do
					local out = strsub(history, -dist)
					length = length - #out
					output(out)
				end
				output(strsub(history, -dist, -dist + length - 1))
			end
		end
	end

	local readingBlock = nil
	local function readMore()
		local data = {}
		while true do
			if not readingBlock then
				if isFinal then
					break
				end
				readingBlock = coroutine.create(blockReader)
			end
			while true do
				local res = table.pack(coroutine.resume(readingBlock, table.unpack(data, 1, data.n)))
				if not res[1] then
					error(res[2], 0)
				end
				if res[2] == YIELD_DATA_SYM then
					return res[3]
				end
				if coroutine.status(readingBlock) == 'dead' then
					readingBlock = nil
					break
				end
				data = table.pack(coroutine.yield(table.unpack(res, 2, res.n)))
			end
		end
		if outputBufLen > 0 then
			local r = outputBuf
			outputBuf = ''
			outputBufLen = 0
			return r
		end
		return nil
	end

	local buffer = ''

	function reader.read(count)
		if not buffer then
			return nil
		end

		if count == 0 then
			return ''
		end

		if not count then
			while #buffer == 0 do
				buffer = readMore()
				if not buffer then
					return nil
				end
			end
			local d = strbyte(buffer, 1)
			buffer = strsub(buffer, 1)
			return d
		end

		while #buffer < count do
			local b = readMore()
			if not b then
				local d = buffer
				buffer = nil
				return d
			end
			buffer = buffer .. b
		end
		local d = strsub(buffer, 1, count)
		buffer = strsub(buffer, count + 1)
		return d
	end

	function reader.readAll()
		if not buffer then
			return ''
		end
		while true do
			local b = readMore()
			if not b then
				local d = buffer
				buffer = nil
				return d
			end
			buffer = buffer .. b
		end
	end

	return reader
end

return {
	newReader = newReader,
}
