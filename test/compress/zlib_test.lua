
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local zlib = require('compress.zlib')

local YIELD_INTERVAL = 1000

local CWD = fs.getDir(arg[0])

local function readFile(name)
	local fd = fs.open(fs.combine(CWD, name), 'rb')
	if not fd then
		error('cannot open ' .. name, 0)
	end
	local zr = zlib.newReader(fd)
	local count = 0

	local startTime = os.epoch('utc')
	local lastYield, yieldSpent = startTime, 0
	while true do
		local now = os.epoch('utc')
		if now >= lastYield + YIELD_INTERVAL then
			os.queueEvent('')
			os.pullEvent('')
			local now2 = os.epoch('utc')
			lastYield = now2
			yieldSpent = yieldSpent + (now2 - now)
		end

		local d = zr.read(8192)
		if not d then
			break
		end
		count = count + #d
	end
	local endTime = os.epoch('utc')

	fd.close()

	local runtime = endTime - startTime - yieldSpent

	return count, runtime
end

local function testFile(name, expectBytes)
	sleep(1)
	term.setTextColor(colors.yellow)
	write('RUNNING')
	term.setTextColor(colors.white)
	print('', name)

	local bytes, runtime = readFile(name)

	if bytes ~= expectBytes then
		error('expect ' .. expectBytes .. ' got ' .. bytes)
	end

	local KBpS = bytes / runtime * 1000 / 1024
	print(' runtime', runtime, 'ms', bytes)
	print(' KB/s', KBpS)
end

testFile('data/1mb_0.zlib', 1024 * 1024)
testFile('data/1mb_1.zlib', 1024 * 1024)
testFile('data/1mb_2.zlib', 1024 * 1024)
