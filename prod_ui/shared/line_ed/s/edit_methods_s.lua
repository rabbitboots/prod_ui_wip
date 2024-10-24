-- To load: local lib = context:getLua("shared/lib")


--[[
	LineEditor (single) plug-in methods for client widgets.
--]]


local context = select(1, ...)


local editMethodsS = {}
local client = editMethodsS


-- LÖVE Supplemental
local utf8 = require("utf8")


-- ProdUI
local code_groups = context:getLua("shared/line_ed/code_groups")
local commonEd = context:getLua("shared/line_ed/common_ed")
local edComBase = context:getLua("shared/line_ed/ed_com_base")
local edComS = context:getLua("shared/line_ed/s/ed_com_s")
local editHistS = context:getLua("shared/line_ed/s/edit_hist_s")
local textUtil = require(context.conf.prod_ui_req .. "lib.text_util")


client.getReplaceMode = commonEd.client_getReplaceMode
client.setReplaceMode = commonEd.client_setReplaceMode


--- Delete highlighted text from the field.
-- @return Substring of the deleted text.
function client:deleteHighlightedText()
	local line_ed = self.line_ed

	if not self:isHighlighted() then
		return -- nil
	end

	-- Clean up display highlight beforehand. Much harder to determine the offsets after deleting things.
	local byte_1, byte_2 = line_ed:getHighlightOffsets()
	line_ed:highlightCleanup()

	return line_ed:deleteText(true, byte_1, byte_2 - 1)
end


--- Delete characters by stepping backwards from the caret position.
-- @param n_u_chars The number of code points to delete.
-- @return The deleted characters in string form, or nil if nothing was deleted.
function client:backspaceUChar(n_u_chars)
	local line_ed = self.line_ed
	line_ed:highlightCleanup()

	local line = line_ed.line
	local byte_1, u_count = edComS.countUChars(line, -1, line_ed.car_byte, n_u_chars)

	if u_count > 0 then
		return line_ed:deleteText(true, byte_1, line_ed.car_byte - 1)
	end

	return nil
end


--- Write text to the field, checking for bad input and trimming to fit into the uChar limit.
-- @param text The input text. It will be sanitized and possibly trimmed to fit into the uChar limit.
-- @param suppress_replace When true, the "replace mode" codepath is not selected. Use when pasting,
-- entering line feeds, typing at the end of a line (so as not to overwrite line feeds), etc.
-- @return The sanitized and trimmed text which was inserted into the field.
function client:writeText(text, suppress_replace)
	local line_ed = self.line_ed
	local line = line_ed.line

	-- Sanitize input
	text = edComBase.cleanString(text, line_ed.bad_input_rule, line_ed.tabs_to_spaces, line_ed.allow_line_feed)

	if not line_ed.allow_highlight then
		line_ed:clearHighlight()
	end

	-- If there is a highlight selection, get rid of it and insert the new text. This overrides replace_mode.
	if line_ed:isHighlighted() then
		self:deleteHighlightedText()

	elseif line_ed.replace_mode and not suppress_replace then
		-- Delete up to the number of uChars in 'text', then insert text in the same spot.
		self:deleteUChar(utf8.len(text))
	end

	-- Trim text to fit the allowed uChars limit.
	line_ed.u_chars = utf8.len(line_ed.line)
	text = textUtil.trimString(text, line_ed.u_chars_max - line_ed.u_chars)

	line_ed:insertText(text)

	return text
end


function client:stepHistory(dir)
	-- -1 == undo
	-- 1 == redo

	local line_ed = self.line_ed
	local hist = line_ed.hist

	local changed, entry = hist:moveToEntry(hist.pos + dir)

	if changed then
		editHistS.applyEntry(self, entry)
		line_ed:updateDisplayText()
	end
end


function client:getText()
	return self.line_ed.line
end


function client:getHighlightedText()
	local line_ed = self.line_ed

	if line_ed:isHighlighted() then
		local b1, b2 = self.line_ed:getHighlightOffsets()
		return string.sub(line_ed.line, b1, b2 - 1)
	end

	return nil
end


function client:isHighlighted()
	return self.line_ed:isHighlighted()
end


function client:clearHighlight()
	self.line_ed:clearHighlight()
end


function client:highlightAll()
	local line_ed = self.line_ed

	line_ed.car_byte = #line_ed.line + 1
	line_ed.h_byte = 1

	line_ed:displaySyncCaretOffsets()
	line_ed:updateHighlightRect()
end


--- Moves caret to the left highlight edge
function client:caretHighlightEdgeLeft()
	local line_ed = self.line_ed

	local byte_1, byte_2 = line_ed:getHighlightOffsets()

	line_ed.car_byte = byte_1
	line_ed.h_byte = byte_1

	line_ed:displaySyncCaretOffsets()
	line_ed:updateHighlightRect()
end


--- Moves caret to the right highlight edge
function client:caretHighlightEdgeRight()
	local line_ed = self.line_ed

	local byte_1, byte_2 = line_ed:getHighlightOffsets()

	line_ed.car_byte = byte_2
	line_ed.h_byte = byte_2

	line_ed:displaySyncCaretOffsets()
	line_ed:updateHighlightRect()
end


function client:highlightCurrentWord()
	local line_ed = self.line_ed

	line_ed.car_byte, line_ed.h_byte = line_ed:getWordRange(line_ed.car_byte)

	line_ed:displaySyncCaretOffsets()
	line_ed:updateHighlightRect()
end


--- Helper that takes care of history changes following an action.
-- @param self The client widget
-- @param bound_func The wrapper function to call. It should take 'self' as its first argument, the LineEditor core as the second, and return values that control if and how the lineEditor object is updated. For more info, see the bound_func(self) call here, and also in EditAct.
-- @return The results of bound_func(), in case they are helpful to the calling widget logic.
function client:executeBoundAction(bound_func)
	local line_ed = self.line_ed

	local old_byte, old_h_byte = line_ed:getCaretOffsets()
	local ok, update_viewport, caret_in_view, write_history = bound_func(self, line_ed)

	--print("executeBoundAction()", "ok", ok, "update_viewport", update_viewport, "caret_in_view", caret_in_view, "write_history", write_history)

	if ok then
		if update_viewport then
			-- XXX refresh: update scroll bounds
		end

		if caret_in_view then
			-- XXX refresh: tell client widget to get the caret in view
		end

		if write_history then
			line_ed.input_category = false

			editHistS.doctorCurrentCaretOffsets(line_ed.hist, old_byte, old_h_byte)
			editHistS.writeEntry(line_ed, true)
		end

		return true, update_viewport, caret_in_view, write_history
	end
end


function client:caretStepLeft(clear_highlight)
	local line_ed = self.line_ed

	local new_byte = edComS.offsetStepLeft(line_ed.line, line_ed.car_byte)
	line_ed.car_byte = new_byte or 1

	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end
end


function client:caretStepRight(clear_highlight)
	local line_ed = self.line_ed

	local new_byte = edComS.offsetStepRight(line_ed.line, line_ed.car_byte)
	line_ed.car_byte = new_byte or #line_ed.line + 1

 	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end
end


function client:caretJumpLeft(clear_highlight)
	local line_ed = self.line_ed

	line_ed.car_byte = edComS.huntWordBoundary(code_groups, line_ed.line, line_ed.car_byte, -1, false, -1)

	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end
end


function client:caretJumpRight(clear_highlight)
	local line_ed = self.line_ed

	local hit_non_ws = false

	local first_group
	if line_ed.car_byte <= #line_ed.line then
		first_group = code_groups[utf8.codepoint(line_ed.line, line_ed.car_byte)]
	end

	if first_group ~= "whitespace" then
		hit_non_ws = true
	end

	--print("hit_non_ws", hit_non_ws, "first_group", first_group)

	--(lines, line_n, byte_n, dir, hit_non_ws, first_group, stop_on_line_feed)
	line_ed.car_byte = edComS.huntWordBoundary(code_groups, line_ed.line, line_ed.car_byte, 1, hit_non_ws, first_group)

	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end

	-- One more step to land on the right position. -- XXX okay to delete?
	--self:caretStepRight(clear_highlight)
end


--- Delete characters on and to the right of the caret.
-- @param n_u_chars The number of code points to delete.
-- @return The deleted characters in string form, or nil if nothing was deleted.
function client:deleteUChar(n_u_chars)
	local line_ed = self.line_ed
	local line = line_ed.line

	line_ed:highlightCleanup()

	-- Nothing to delete at the last caret position.
	if line_ed.car_byte > #line then
		return -- nil
	end

	local byte_2, u_count = edComS.countUChars(line, 1, line_ed.car_byte, n_u_chars)
	if u_count == 0 then
		byte_2 = #line + 1
	end

	-- Delete offsets are inclusive, so get the rightmost byte that is part of the final code point.
	return line_ed:deleteText(true, line_ed.car_byte, byte_2 - 1)
end


function client:deleteGroup()
	local line_ed = self.line_ed

	line_ed:highlightCleanup()

	local byte_right

	if line_ed.car_byte == #line_ed.line + 1 then
		return -- nil
	else
		local hit_non_ws = false
		local first_group = code_groups[utf8.codepoint(line_ed.line, line_ed.car_byte)]
		if first_group ~= "whitespace" then
			hit_non_ws = true
		end
		--print("HIT_NON_WS", hit_non_ws, "FIRST_GROUP", first_group)

		byte_right = edComS.huntWordBoundary(code_groups, line_ed.line, line_ed.car_byte, 1, hit_non_ws, first_group)
		byte_right = byte_right - 1
		--print("deleteGroup: byte_right", byte_right)
	end

	--print("ranges:", line_ed.car_byte, byte_right)
	local del = line_ed:deleteText(true, line_ed.car_byte, byte_right)
	--print("DEL", "|"..(del or "<nil>").."|")
	if del ~= "" then
		return del
	else
		return -- nil
	end
end


function client:backspaceGroup()
	local line_ed = self.line_ed

	line_ed:highlightCleanup()

	local byte_left

	if line_ed.car_byte == 1 then
		return -- nil
	else
		byte_left = edComS.huntWordBoundary(code_groups, line_ed.line, line_ed.car_byte, -1, false, -1)
	end

	if byte_left and byte_left ~= line_ed.car_byte then
		return line_ed:deleteText(true, byte_left, line_ed.car_byte - 1)
	end

	return nil
end


function client:deleteCaretToEnd()
	local line_ed = self.line_ed

	line_ed:highlightCleanup()

	return line_ed:deleteText(true, line_ed.car_byte, #line_ed.line)
end


function client:deleteCaretToStart()
	local line_ed = self.line_ed

	line_ed:highlightCleanup()

	return line_ed:deleteText(true, 1, line_ed.car_byte - 1)
end


function client:caretFirst(clear_highlight)
	local line_ed = self.line_ed

	line_ed.car_byte = 1

	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end
end


function client:caretLast(clear_highlight)
	local line_ed = self.line_ed

	line_ed.car_byte = #line_ed.line + 1

	line_ed:displaySyncCaretOffsets()

	if clear_highlight then
		line_ed:clearHighlight()
	else
		line_ed:updateHighlightRect()
	end
end


function client:copyHighlightedToClipboard()
	local line_ed = self.line_ed

	local copied = self:getHighlightedText()

	-- Don't leak masked string info.
	if line_ed.masked then
		copied = string.rep(line_ed.mask_glyph, utf8.len(copied))
	end

	copied = textUtil.sanitize(copied, line_ed.bad_input_rule)

	love.system.setClipboardText(copied)
end


function client:cutHighlightedToClipboard()
	local line_ed = self.line_ed

	local old_byte, old_h_byte = line_ed:getCaretOffsets()

	local cut = self:deleteHighlightedText()

	if cut then
		cut = textUtil.sanitize(cut, self.bad_input_rule)

		-- Don't leak masked string info.
		if line_ed.masked then
			cut = table.concat(cut, "\n")
			cut = string.rep(line_ed.mask_glyph, utf8.len(cut))
		end

		love.system.setClipboardText(cut)

		self.input_category = false

		editHistS.doctorCurrentCaretOffsets(line_ed.hist, old_byte, old_h_byte)
		editHistS.writeEntry(line_ed, true)
	end
end


function client:pasteClipboardText()
	local line_ed = self.line_ed

	local old_byte, old_h_byte = line_ed:getCaretOffsets()

	if line_ed:isHighlighted() then
		self:deleteHighlightedText()
	end

	local text = love.system.getClipboardText()

	-- love.system.getClipboardText() may return an empty string if there is nothing in the clipboard,
	-- or if the current clipboard payload is not text. I'm not sure if it can return nil as well.
	-- Check both cases here to be sure.
	if text and text ~= "" then
		line_ed.input_category = false
		self:writeText(text, true)

		editHistS.doctorCurrentCaretOffsets(line_ed.hist, old_byte, old_h_byte)
		editHistS.writeEntry(line_ed, true)
	end
end


function client:caretToX(clear_highlight, x, split_x)
	local line_ed = self.line_ed
	local byte = line_ed:getCharacterDetailsAtPosition(x, split_x)

	line_ed:caretToByte(clear_highlight, byte)
end


function client:clickDragByWord(x, origin_byte)
	local line_ed = self.line_ed

	local drag_byte = line_ed:getCharacterDetailsAtPosition(x, true)

	-- Expand ranges to cover full words
	local db1, db2 = line_ed:getWordRange(drag_byte)
	local cb1, cb2 = line_ed:getWordRange(origin_byte)

	-- Merge the two ranges.
	local mb1, mb2 = math.min(cb1, db1), math.max(cb2, db2)

	if drag_byte < origin_byte then
		line_ed:caretAndHighlightToByte(mb1, mb2)
	else
		line_ed:caretAndHighlightToByte(mb2, mb1)
	end
end


return editMethodsS
