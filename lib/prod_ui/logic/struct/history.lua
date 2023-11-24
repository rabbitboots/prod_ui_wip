-- A generic history container.


local history = {}


local _mt_hist = {}
_mt_hist.__index = _mt_hist


local function _assertEntryPosition(self)

	if self.pos < 0 or self.pos > #self.ledger then
		error("history position is out of bounds.")
	end
end


function history.new()

	local self = setmetatable({}, _mt_hist)

	self.enabled = true

	self.pos = 0
	self.max = 500

	self.ledger = {}

	return self
end


function _mt_hist:_debugGetState()

	local tbl = {}

	table.insert(tbl, "enabled: " .. self.enabled .. "\n")
	table.insert(tbl, "pos/max: " .. self.pos .. "/" .. self.max .. "\n")

	for i, entry in ipairs(self.ledger) do
		table.insert(tbl, "\t" .. i .. tostring(entry) .. "\n")
	end

	local str = table.concat(tbl)

	return str
end


--- Enable or disable history.
-- @param enabled True to enable, false/nil/empty to disable.
function _mt_hist:setEnabled(enabled)

	self.enabled = not not enabled

	if not self.enabled then
		self:clearAll()
	end
end


--- Set the max history entries for the ledger. Note that this will wipe all existing ledger entries.
-- @param max The max ledger values. Must be an integer >= 0.
function _mt_hist:setMaxEntries(max)

	-- Allow setting max entries, even if not enabled.

	-- Assertions
	-- [[
	if type(max) ~= "number" or max ~= max or max ~= math.floor(max) or max < 0 then
		error("'max' must be an integer >= 0.")
	end
	--]]

	self.max = math.floor(max)
	self:clearAll()
end


function _mt_hist:clearAll()

	-- Allow clearing, even if not enabled.

	local ledger = self.ledger

	for i = #ledger, 1, -1 do
		table.remove(ledger, i)
	end

	self.pos = 0
end


function _mt_hist:moveToEntry(index)

	index = math.floor(index)

	if not self.enabled then
		return
	end

	if index == self.pos then
		return
	end

	local ledger = self.ledger

	local old_pos = self.pos
	self.pos = math.max(1, math.min(index, #ledger))

	if ledger[self.pos] then
		return old_pos ~= self.pos, ledger[self.pos]
	end

	-- return nil
end


function _mt_hist:getCurrentEntry()
	return self.ledger[self.pos] -- can be nil
end


--- Writes a history entry to the ledger.
-- @param do_advance True, advance to the next ledger entry. False: overwrite the current entry, if one exists, or create entry #1.
-- @return The current ledger entry (new or previously written, with old data), or nothing if the History object is disabled.
function _mt_hist:writeEntry(do_advance)

	--print("writeEntry", "do_advance", do_advance)

	-- Assertions
	-- [[
	_assertEntryPosition(self)
	--]]

	if not self.enabled then
		return
	end

	local ledger = self.ledger

	-- If advancing and ledger is full, remove oldest entry
	if do_advance then
		self.pos = self.pos + 1

		if self.pos >= #ledger and #ledger >= self.max then
			self.pos = self.pos - 1

			table.remove(ledger, 1)
		end
	end

	self.pos = math.max(self.pos, 1)

	ledger[self.pos] = ledger[self.pos] or {}

	-- Remove stale future entries
	for i = #ledger, self.pos + 1, -1 do
		table.remove(ledger, i)
	end

	return ledger[self.pos]
end


return history
