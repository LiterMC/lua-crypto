
package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local sha1 = require('hash.sha1')

local MAX_RUNTIME = 10 * 1000
local MIN_OP_COUNT = 100
local YIELD_INTERVAL = 1000

local function bench(hint, oper)
	sleep(1)
	term.setTextColor(colors.yellow)
	write('RUNNING')
	term.setTextColor(colors.white)
	print('', hint)

	local startTime, endTime = os.epoch('utc'), nil
	local count = 0

	local lastYield, yieldSpent = startTime, 0
	while true do
		local now = os.epoch('utc')
		if now >= startTime + MAX_RUNTIME and count >= MIN_OP_COUNT then
			endTime = now
			break
		end
		if now >= lastYield + YIELD_INTERVAL then
			os.queueEvent('')
			os.pullEvent('')
			local now2 = os.epoch('utc')
			lastYield = now2
			yieldSpent = yieldSpent + (now2 - now)
		end
		oper()
		count = count + 1
	end

	local runtime = endTime - startTime - yieldSpent
	local msPerOp = runtime / count

	print(' runtime', runtime, 'ms', count)
	print(' us/op', msPerOp * 1000)
	return msPerOp
end

local function benchStream(hint, bytesPerOp, oper)
	local msPerOp = bench(hint, oper)
	print(' KB/s', bytesPerOp / msPerOp * 1000 / 1024)
	return msPerOp
end

bench('empty', function()
	local digest = sha1.newDigest()
	_ = digest.sum()
end)

local KLIO_00 = string.rep('\x00', 1024)

benchStream('1 * 0x00', 1, function()
	local digest = sha1.newDigest()
	digest.write(0x00)
	_ = digest.sum()
end)

benchStream('1 * "\\x00"', 1, function()
	local digest = sha1.newDigest()
	digest.write('\x00')
	_ = digest.sum()
end)

benchStream('1k * 0x00', 1024, function()
	local digest = sha1.newDigest()
	for _ = 1, 1024 do
		digest.write(0x00)
	end
	_ = digest.sum()
end)

benchStream('1k 0x00', 1024, function()
	local digest = sha1.newDigest()
	digest.write(KLIO_00)
	_ = digest.sum()
end)

local KLIO_85 = string.rep('\x85', 1024)

local KLIO8_85 = string.rep('\x85', 8192)

benchStream('1k 0x85', #KLIO_85, function()
	local digest = sha1.newDigest()
	digest.write(KLIO_85)
	_ = digest.sum()
end)

benchStream('8k 0x85', #KLIO8_85, function()
	local digest = sha1.newDigest()
	digest.write(KLIO8_85)
	_ = digest.sum()
end)

local RAND_STR = 'advanced peripherals'
local KILO8_RAND = string.rep(RAND_STR, math.ceil(8192 / #RAND_STR)):sub(1, 8192)

benchStream('8k repeat short str', #KILO8_RAND, function()
	local digest = sha1.newDigest()
	digest.write(KILO8_RAND)
	_ = digest.sum()
end)
