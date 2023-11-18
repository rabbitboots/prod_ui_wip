-- To load: local lib = context:getLua("shared/lib")


--[[

Bindable wrapper functions for common LineEditor actions.

Function arguments:
1) self: The client widget.
2) line_ed: The LineEditor instance (self.line_ed). (Redundant but convenient.)

Return values: -- XXX update
1) true: the display object's scrolling information should be updated.
2) true: the caret should be kept in view.
3) true: an explicit history entry should be written after the bound action completes. Note that some
bound actions may handle history directly and return false.

--]]


--local context = select(1, ...)


local editAct = {}


-- LÖVE Supplemental
local utf8 = require("utf8")


-- Step left, right
function editAct.caretLeft(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeLeft(true)

	else
		self:caretStepLeft(true)
	end

	return true, true, false
end


function editAct.caretRight(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeRight(true)

	else
		self:caretStepRight(true)
	end

	return true, true, false
end


-- Step left, right while highlighting
function editAct.caretLeftHighlight(self, line_ed)
	self:caretStepLeft(not line_ed.allow_highlight)

	return true, true, false
end


function editAct.caretRightHighlight(self, line_ed)
	self:caretStepRight(not line_ed.allow_highlight)

	return true, true, false
end


-- Jump left, right
function editAct.caretJumpLeft(self, line_ed)
	-- Don't leak details about the masked string.
	if line_ed.disp.masked then
		self:caretFirst(true)
	else
		self:caretJumpLeft(true)
	end

	return true, true, false
end


function editAct.caretJumpRight(self, line_ed)
	-- Don't leak details about the masked string.
	if line_ed.disp.masked then
		self:caretLast(true)
	else
		self:caretJumpRight(true)
	end

	return true, true, false
end


-- Jump left, right with highlight
function editAct.caretJumpLeftHighlight(self, line_ed)
	-- Don't leak details about the masked string.
	if line_ed.disp.masked then
		self:caretFirst(not line_ed.allow_highlight)
	else
		self:caretJumpLeft(not line_ed.allow_highlight)
	end

	return true, true, false
end


function editAct.caretJumpRightHighlight(self, line_ed)
	-- Don't leak details about the masked string.
	if line_ed.disp.masked then
		self:caretLast(not line_ed.allow_highlight)
	else
		self:caretJumpRight(not line_ed.allow_highlight)
	end

	return true, true, false
end


-- Move to first, end of line
function editAct.caretLineFirst(self, line_ed)
	-- [WARN] If multi-line is enabled, this can leak information about masked line feeds.
	self:caretLineFirst(true)

	return true, true, false
end


function editAct.caretLineLast(self, line_ed)
	-- [WARN] If multi-line is enabled, this can leak information about masked line feeds.
	self:caretLineLast(true)

	return true, true, false
end


-- Jump to start, end of document
function editAct.caretFirst(self, line_ed)
	self:caretFirst(true)

	return true, true, false
end


function editAct.caretLast(self, line_ed)
	self:caretLast(true)

	return true, true, false
end


-- Highlight to start, end of document
function editAct.caretFirstHighlight(self, line_ed)
	self:caretFirst(not line_ed.allow_highlight)

	return true, true, false
end


function editAct.caretLastHighlight(self, line_ed)
	self:caretLast(not line_ed.allow_highlight)

	return true, true, false
end


-- Highlight to first, end of line
function editAct.caretLineFirstHighlight(self, line_ed)
	-- [WARN] Can leak masked line feeds (or would, if line feeds were masked)
	self:caretLineFirst(not line_ed.allow_highlight)

	return true, true, false
end


function editAct.caretLineLastHighlight(self, line_ed)
	-- [WARN] Can leak masked line feeds (or would, if line feeds were masked)
	self:caretLineLast(not line_ed.allow_highlight)

	return true, true, false
end


-- Step up, down
function editAct.caretStepUp(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeLeft(not line_ed.allow_highlight)
	end
	self:caretStepUp(true, 1)

	return true, true, false
end


function editAct.caretStepDown(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeRight(not line_ed.allow_highlight)
	end
	self:caretStepDown(true, 1)

	return true, true, false
end


-- Highlight up, down
function editAct.caretStepUpHighlight(self, line_ed)
	self:caretStepUp(not line_ed.allow_highlight, 1)

	return true, true, false
end


function editAct.caretStepDownHighlight(self, line_ed)
	self:caretStepDown(not line_ed.allow_highlight, 1)

	return true, true, false
end


function editAct.caretStepUpCoreLine(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeLeft(not line_ed.allow_highlight)
	end
	self:caretStepUpCoreLine(true)

	return true, true, false
end


function editAct.caretStepDownCoreLine(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeRight(not line_ed.allow_highlight)
	end
	self:caretStepDownCoreLine(true)

	return true, true, false
end


function editAct.caretStepUpCoreLineHighlight(self, line_ed)
	self:caretStepUpCoreLine(not line_ed.allow_highlight)

	return true, true, false
end


function editAct.caretStepDownCoreLineHighlight(self, line_ed)
	self:caretStepDownCoreLine(not line_ed.allow_highlight)

	return true, true, false
end


-- Page-up, page-down
function editAct.caretPageUp(self, line_ed)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeLeft(not line_ed.allow_highlight)
	end
	self:caretStepUp(true, line_ed.page_jump_steps)

	return true, true, false
end


function editAct.caretPageDown(self, line_ed)
	--print("line_ed.page_jump_steps", line_ed.page_jump_steps)
	if line_ed:isHighlighted() then
		self:caretHighlightEdgeRight(not line_ed.allow_highlight)
	end
	self:caretStepDown(true, line_ed.page_jump_steps)

	return true, true, false
end


function editAct.caretPageUpHighlight(self, line_ed)
	self:caretStepUp(not line_ed.allow_highlight, line_ed.page_jump_steps)

	return true, true, false
end


function editAct.caretPageDownHighlight(self, line_ed)
	self:caretStepDown(not line_ed.allow_highlight, line_ed.page_jump_steps)

	return true, true, false
end


-- Backspace, delete (or delete highlight)
function editAct.backspace(self, line_ed)

	--[[
	Both backspace and delete support partial amendments to history, so they need some special handling here.
	This logic is essentially a copy-and-paste of the code that handles amended text input.
	--]]

	if line_ed.allow_input then
		-- Need to handle history here.
		local old_line, old_byte, old_h_line, old_h_byte = line_ed:getCaretOffsets()
		local deleted

		if line_ed:isHighlighted() then
			deleted = self:deleteHighlightedText()
		else
			deleted = self:backspaceUChar(1)
		end

		if deleted then
			local hist = line_ed.hist

			local no_ws = string.find(deleted, "%S")
			local entry = hist:getCurrentEntry()
			local do_advance = true

			if utf8.len(deleted) == 1 and deleted ~= "\n"
			and (entry and entry.car_line == old_line and entry.car_byte == old_byte)
			and ((line_ed.input_category == "backspacing" and no_ws) or (line_ed.input_category == "backspacing-ws"))
			then
				do_advance = false
			end

			if do_advance then
				hist:doctorCurrentCaretOffsets(old_line, old_byte, old_h_line, old_h_byte)
			end
			hist:writeEntry(do_advance, line_ed.lines, line_ed.car_line, line_ed.car_byte, line_ed.h_line, line_ed.h_byte)
			line_ed.input_category = no_ws and "backspacing" or "backspacing-ws"
		end

		return true, true, false
	end
end


function editAct.delete(self, line_ed)

	if line_ed.allow_input then
		-- Need to handle history here.
		local old_line, old_byte, old_h_line, old_h_byte = line_ed:getCaretOffsets()
		local deleted

		if line_ed:isHighlighted() then
			deleted = self:deleteHighlightedText()
		else
			deleted = self:deleteUChar(1)
		end

		if deleted then
			local hist = line_ed.hist

			local no_ws = string.find(deleted, "%S")
			local entry = hist:getCurrentEntry()
			local do_advance = true

			if utf8.len(deleted) == 1 and deleted ~= "\n"
			and (entry and entry.car_line == old_line and entry.car_byte == old_byte)
			and ((line_ed.input_category == "deleting" and no_ws) or (line_ed.input_category == "deleting-ws"))
			then
				do_advance = false
			end

			if do_advance then
				hist:doctorCurrentCaretOffsets(old_line, old_byte, old_h_line, old_h_byte)
			end
			hist:writeEntry(do_advance, line_ed.lines, line_ed.car_line, line_ed.car_byte, line_ed.h_line, line_ed.h_byte)
			line_ed.input_category = no_ws and "deleting" or "deleting-ws"
		end

		return true, true, false
	end
end


-- Delete highlighted text (for the pop-up menu)
function editAct.deleteHighlighted(self, line_ed)

	if line_ed.allow_input then
		if line_ed:isHighlighted() then
			self:deleteHighlightedText()

			-- Always write history if anything was deleted.
			return true, true, true
		end
	end
end


-- Backspace, delete by group (unhighlights first)
function editAct.deleteGroup(self, line_ed)

	if line_ed.allow_input then
		local write_hist = false

		-- Don't leak masked info.
		if line_ed.disp.masked then
			write_hist = not not self:deleteUChar(1)
		else
			line_ed.input_category = false
			write_hist = not not self:deleteGroup()
		end

		return true, true, write_hist
	end
end


function editAct.deleteLine(self, line_ed)

	if line_ed.allow_input then
		local write_hist = false

		-- [WARN] Can leak masked line feeds.
		line_ed.input_category = false
		write_hist = not not self:deleteLine()

		return true, true, write_hist
	end
end


function editAct.backspaceGroup(self, line_ed)

	if line_ed.allow_input then
		local write_hist = false

		-- Don't leak masked info.
		if line_ed.disp.masked then
			write_hist = not not self:backspaceUChar(1)

		else
			write_hist = not not self:backspaceGroup()
			line_ed.input_category = false
		end

		return true, true, write_hist
	end
end


-- Backspace, delete from caret to start/end of line, respectively (unhighlights first)
function editAct.deleteCaretToLineEnd(self, line_ed)
	if line_ed.allow_input then
		-- [WARN] Can leak masked line feeds (or would, if line feeds were masked)
		self:deleteCaretToLineEnd()
		line_ed.input_category = false

		return true, true, true
	end
end


function editAct.backspaceCaretToLineStart(self, line_ed)
	if line_ed.allow_input then
		-- [WARN] Will leak masked line feeds (or would, if line feeds were masked)
		self:deleteCaretToLineStart()
		line_ed.input_category = false

		return true, true, true
	end
end


-- Add line feed (unhighlights first)
function editAct.typeLineFeed(self, line_ed)
	if line_ed.allow_input and line_ed.allow_enter then
		line_ed.input_category = false
		self:writeText("\n", true)

		return true, true, true
	end
end


-- Add tab (unhighlights first)
function editAct.typeTab(self, line_ed)
	if line_ed.allow_input and line_ed.allow_tab then
		self:writeText("\t", true)

		return true, true, true
	end
end


-- (XXX Unfinished) Delete one tab (or an equivalent # of spaces) at the start of a line.
function editAct.typeUntab(self, line_ed)
	if line_ed.allow_input and line_ed.allow_untab then
		-- XXX TODO

		-- return true, true, true
	end
end


-- Select all
function editAct.selectAll(self, line_ed)
	if line_ed.allow_highlight then
		self:highlightAll()

	else
		self:clearHighlight()
	end

	return true, false, false
end


function editAct.selectCurrentWord(self, line_ed)
	--print("editAct.selectCurrentWord")

	if line_ed.allow_highlight then
		self:highlightCurrentWord()

	else
		self:clearHighlight()
	end

	return true, false, false
end


function editAct.selectCurrentLine(self, line_ed)
	--print("editAct.selectLine")

	if line_ed.allow_highlight then
		self:highlightCurrentWrappedLine()
		--self:highlightCurrentLine()

	else
		self:clearHighlight()
	end

	return true, false, false
end


-- Copy, cut, paste
function editAct.copy(self, line_ed)
	if line_ed.allow_copy and line_ed.allow_highlight and line_ed:isHighlighted() then
		self:copyHighlightedToClipboard() -- handles masking

		return true, false, false
	end
end


function editAct.cut(self, line_ed)
	if line_ed.allow_input and line_ed.allow_cut and line_ed.allow_highlight and line_ed:isHighlighted() then
		self:cutHighlightedToClipboard() -- handles masking, history, and blanking the input category.

		return true, true, false
	end
end


function editAct.paste(self, line_ed)
	if line_ed.allow_input and line_ed.allow_paste then
		self:pasteClipboardText() -- handles history, and blanking the input category.

		return true, true, false
	end
end


-- Toggle Insert / Replace mode
function editAct.toggleReplaceMode(self, line_ed)
	self:setReplaceMode(not self:getReplaceMode())

	return true, false, false
end


-- Undo / Redo
function editAct.undo(self, line_ed)
	self:stepHistory(-1)
	line_ed.input_category = false

	return true, true, false
end


function editAct.redo(self, line_ed)
	self:stepHistory(1)
	line_ed.input_category = false

	return true, true, false
end


return editAct

