--[[
Shared widget logic for single-line text input.

Widgets using this system are not compatible with the following callbacks:

* uiCall_thimbleAction: interferes with typing space bar and enter.
Instead, check for enter (or space) in the widget's 'uiCall_keyPressed' callback.

Example:
----
if scancode == "return" or scancode == "kpenter" then
	self:wid_action()
	return true
else
	return lgcInputS.keyPressLogic(self, key, scancode, isrepeat)
end
----

* uiCall_thimbleAction2: interferes with the pop-up menu (undo, etc.)
--]]


local context = select(1, ...)


local lgcInputS = {}


local commonMenu = require(context.conf.prod_ui_req .. "logic.common_menu")
local commonWimp = require(context.conf.prod_ui_req .. "logic.common_wimp")
local editActS = context:getLua("shared/line_ed/s/edit_act_s")
local editBindS = context:getLua("shared/line_ed/s/edit_bind_s")
local editHistS = context:getLua("shared/line_ed/s/edit_hist_s")
local editMethodsS = context:getLua("shared/line_ed/s/edit_methods_s")
local itemOps = require(context.conf.prod_ui_req .. "logic.item_ops")
local keyCombo = require(context.conf.prod_ui_req .. "lib.key_combo")
local keyMgr = require(context.conf.prod_ui_req .. "lib.key_mgr")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


-- LÖVE 12 compatibility.
local love_major, love_minor = love.getVersion()


-- Widget def configuration.
function lgcInputS.setupDef(def)
	-- Attach editing methods to def.
	for k, v in pairs(editMethodsS) do
		def[k] = v
	end
end


function lgcInputS.setupInstance(self)
	-- When true, typing overwrites the current position instead of inserting.
	self.replace_mode = false

	-- What to do when there's a UTF-8 encoding problem.
	-- Applies to input text, and also to clipboard get/set.
	-- See 'textUtil.sanitize()' for options.
	self.bad_input_rule = false

	-- Enable/disable specific editing actions.
	self.allow_input = true -- affects nearly all operations, except navigation, highlighting and copying
	self.allow_cut = true
	self.allow_copy = true
	self.allow_paste = true
	self.allow_highlight = true

	-- Allows '\n' as text input (including pasting from the clipboard).
	-- Single-line input treats line feeds like any other character. For example, 'home' and 'end' will not
	-- stop at line feeds.
	-- In the external display string, line feed code points (0xa) are substituted for U+23CE (⏎).
	self.allow_line_feed = false

	-- Allows typing a line feed by pressing enter/return. `self.allow_line_feed` must be true.
	-- Note that this may override other uses of enter/return in the owning widget.
	self.allow_enter_line_feed = false

	self.allow_tab = false -- affects single presses of the tab key
	self.allow_untab = false -- affects shift+tab (unindenting)
	self.tabs_to_spaces = false -- affects '\t' in writeText()

	-- Max number of Unicode characters (not bytes) permitted in the field.
	self.u_chars_max = math.huge

	-- Helps with amending vs making new history entries.
	self.input_category = false

	-- Caret position and dimensions. Based on 'line_ed.caret_box_*'.
	self.caret_x = 0
	self.caret_y = 0
	self.caret_w = 0
	self.caret_h = 0

	self.caret_fill = "line"

	-- Extends the caret dimensions when keeping the caret within the bounds of the viewport.
	self.caret_extend_x = 0
	self.caret_extend_y = 0

	-- Used to update viewport scrolling as a result of dragging the mouse in update().
	self.mouse_drag_x = 0

	-- Position offset when clicking the mouse.
	-- This is only valid when a mouse action is in progress.
	self.click_byte = 1

	-- How far to offset the line X position depending on the alignment.
	self.align_offset = 0

	-- string: display this text when the input box is empty.
	-- false: disabled.
	self.ghost_text = false

	-- false: use content text alignment.
	-- "left", "center", "right", "justify"
	self.ghost_text_align = false

	self.caret_is_showing = true
	self.caret_blink_time = 0

	-- XXX: skin or some other config system
	self.caret_blink_reset = -0.5
	self.caret_blink_on = 0.5
	self.caret_blink_off = 0.5

	-- Caller should create a single line editor object at `self.line_ed`.
end


function lgcInputS.resetCaretBlink(self)
	self.caret_blink_time = self.caret_blink_reset
end


function lgcInputS.updateCaretBlink(self, dt)
	self.caret_blink_time = self.caret_blink_time + dt
	if self.caret_blink_time > self.caret_blink_on + self.caret_blink_off then
		self.caret_blink_time = math.max(-(self.caret_blink_on + self.caret_blink_off), self.caret_blink_time - (self.caret_blink_on + self.caret_blink_off))
	end

	self.caret_is_showing = self.caret_blink_time < self.caret_blink_off
end


--- Helper that takes care of history changes following an action.
-- @param self The client widget
-- @param bound_func The wrapper function to call. It should take 'self' as its first argument, the LineEditor core as the second, and return values that control if and how the lineEditor object is updated. For more info, see the bound_func(self) call here, and also in EditAct.
-- @return The results of bound_func(), in case they are helpful to the calling widget logic.
function lgcInputS.executeBoundAction(self, bound_func)
	local line_ed = self.line_ed

	local old_byte, old_h_byte = line_ed:getCaretOffsets()
	local ok, update_widget, caret_in_view, write_history = bound_func(self, line_ed)

	--print("executeBoundAction()", "ok", ok, "update_widget", update_widget, "caret_in_view", caret_in_view, "write_history", write_history)

	if ok then
		lgcInputS.updateCaretShape(self)
		if update_widget then
			self:updateDocumentDimensions(self)
			self:scrollClampViewport()
		end

		if caret_in_view then
			self:scrollGetCaretInBounds(true)
		end

		if write_history then
			self.input_category = false

			editHistS.doctorCurrentCaretOffsets(line_ed.hist, old_byte, old_h_byte)
			editHistS.writeEntry(line_ed, true)
		end

		return true, update_widget, caret_in_view, write_history
	end
end


function lgcInputS.cb_boundAction(self, item_t)
	local ok, update_widget, update_caret, write_history = lgcInputS.executeBoundAction(self, item_t.bound_func)
end


-- @return true if event propagation should halt.
function lgcInputS.keyPressLogic(self, key, scancode, isrepeat)
	local line_ed = self.line_ed
	local hist = line_ed.hist

	local ctrl_down, shift_down, alt_down, gui_down = self.context.key_mgr:getModState()

	lgcInputS.resetCaretBlink(self)

	-- pop-up menu (undo, etc.)
	if scancode == "application" or (shift_down and scancode == "f10") then
		-- Locate caret in UI space
		local ax, ay = self:getAbsolutePosition()
		local caret_x = ax + self.vp_x - self.scr_x + line_ed.caret_box_x
		local caret_y = ay + self.vp_y - self.scr_y + line_ed.caret_box_y + line_ed.caret_box_h

		commonMenu.widgetConfigureMenuItems(self, self.pop_up_def)

		local root = self:getTopWidgetInstance()
		local pop_up = commonWimp.makePopUpMenu(self, self.pop_up_def, caret_x, caret_y)
		self:bubbleStatement("rootCall_bankThimble", self)
		pop_up:tryTakeThimble()

		-- Halt propagation
		return true
	end

	-- (LÖVE 12) if this key should behave differently when NumLock is disabled, swap out the scancode and key constant.
	if love_major >= 12 and keyMgr.scan_numlock[scancode] and not love.keyboard.isModifierActive("numlock") then
		scancode = keyMgr.scan_numlock[scancode]
		key = love.keyboard.getKeyFromScancode(scancode)
	end

	local key_string = keyCombo.getKeyString(true, ctrl_down, shift_down, alt_down, gui_down, scancode)
	local bound_func = editBindS[key_string]

	if bound_func then
		local ok, update_widget, caret_in_view, write_history = lgcInputS.executeBoundAction(self, bound_func)
		if ok then
			-- Stop event propagation
			return true
		end
	end


	-- XXX: This is old debug functionality that should be moved elsewhere.
	--[[
	elseif scancode == "f6" then
		-- XXX: debug: left align

	elseif scancode == "f7" then
		-- XXX: debug: center align

	elseif scancode == "f8" then
		-- XXX: debug: right align

	elseif scancode == "f9" then
		-- XXX: masking (for passwords)

	elseif scancode == "f10" then
		-- XXX: debug: colorization test
	--]]
end


-- @return true if the input was accepted, false if it was rejected or input is not allowed
function lgcInputS.textInputLogic(self, text, fn_check)
	local line_ed = self.line_ed

	if self.allow_input then
		local hist = line_ed.hist

		lgcInputS.resetCaretBlink(self)

		local old_line, old_disp_text, old_byte, old_h_byte = line_ed:copyState()
		local old_input_category = self.input_category

		local written = self:writeText(text, false)

		-- Allow the caller to discard the changed text.
		if fn_check and fn_check(self) == false then
			line_ed:setState(old_line, old_disp_text, old_byte, old_h_byte)
			self.input_category = old_input_category
			return
		end

		if self.replace_mode then
			-- Replace mode should force a new history entry, unless the caret is adding to the very end of the line.
			if line_ed.car_byte < #line_ed.line + 1 then
				self.input_category = false
			end
		end

		local no_ws = string.find(written, "%S")
		local entry = hist:getCurrentEntry()
		local do_advance = true

		if (entry and entry.car_byte == old_byte)
		and ((self.input_category == "typing" and no_ws) or (self.input_category == "typing-ws"))
		then
			do_advance = false
		end

		if do_advance then
			editHistS.doctorCurrentCaretOffsets(hist, old_byte, old_h_byte)
		end
		editHistS.writeEntry(line_ed, do_advance)
		self.input_category = no_ws and "typing" or "typing-ws"

		lgcInputS.updateCaretShape(self)
		self:updateDocumentDimensions()
		self:scrollGetCaretInBounds(true)

		return true
	end
end


-- @param mouse_x, mouse_y Mouse position relative to widget top-left.
-- @return true if event propagation should be halted.
function lgcInputS.mousePressLogic(self, button, mouse_x, mouse_y)
	local line_ed = self.line_ed
	local context = self.context

	lgcInputS.resetCaretBlink(self)

	if button == 1 then
		self.press_busy = "text-drag"

		-- Apply scroll + margin offsets
		local mouse_sx = mouse_x + self.scr_x - self.vp_x - self.align_offset

		local core_byte = line_ed:getCharacterDetailsAtPosition(mouse_sx, true)

		if context.cseq_button == 1 then
			-- Not the same byte position as last click: force single-click mode.
			if context.cseq_presses > 1  and core_byte ~= self.click_byte then
				context:forceClickSequence(self, button, 1)
				-- XXX Causes 'cseq_presses' to go from 3 to 1. Not a huge deal but worth checking over.
			end

			if context.cseq_presses == 1 then
				self:caretToX(true, mouse_sx, true)

				self.click_byte = line_ed.car_byte
				lgcInputS.updateCaretShape(self)

			elseif context.cseq_presses == 2 then
				self.click_byte = line_ed.car_byte

				-- Highlight group from highlight position to mouse position.
				self:highlightCurrentWord()
				lgcInputS.updateCaretShape(self)

			elseif context.cseq_presses == 3 then
				self.click_byte = line_ed.car_byte

				--- Highlight everything.
				self:highlightAll()
				lgcInputS.updateCaretShape(self)
			end
		end

	elseif button == 2 then
		commonMenu.widgetConfigureMenuItems(self, self.pop_up_def)

		local root = self:getTopWidgetInstance()

		--print("text_box, current thimble", self.context.current_thimble, root.banked_thimble)

		local ax, ay = self:getAbsolutePosition()
		local pop_up = commonWimp.makePopUpMenu(self, self.pop_up_def, ax + mouse_x, ay + mouse_y)
		root:runStatement("rootCall_doctorCurrentPressed", self, pop_up, "menu-drag")

		pop_up:tryTakeThimble()

		root:runStatement("rootCall_bankThimble", self)

		-- Halt propagation
		return true
	end
end


-- Used in uiCall_update(). Before calling, check that text-drag state is active.
function lgcInputS.mouseDragLogic(self)
	local context = self.context
	local line_ed = self.line_ed

	lgcInputS.resetCaretBlink(self)

	-- Mouse position relative to viewport #1.
	local ax, ay = self:getAbsolutePosition()
	local mx, my = self.context.mouse_x - ax - self.vp_x, self.context.mouse_y - ay - self.vp_y

	-- ...And with scroll offsets applied.
	local s_mx = mx + self.scr_x - self.align_offset
	local s_my = my + self.scr_y

	--print("s_mx", s_mx, "s_my", s_my, "scr_x", self.scr_x, "scr_y", self.scr_y)

	-- Handle drag highlight actions.
	if context.cseq_presses == 1 then
		self:caretToX(false, s_mx, true)
		lgcInputS.updateCaretShape(self)

	elseif context.cseq_presses == 2 then
		self:clickDragByWord(s_mx, self.click_byte)
		lgcInputS.updateCaretShape(self)
	end
	-- cseq_presses == 3: selecting whole line (nothing to do at drag-time).

	-- Amount to drag for the update() callback (to be scaled down and multiplied by dt).
	return (mx < 0) and mx or (mx >= self.vp_w) and mx - self.vp_w or 0
end


function lgcInputS.method_scrollGetCaretInBounds(self, immediate)
	local line_ed = self.line_ed

	-- get the extended caret rectangle
	local car_x1 = self.align_offset + line_ed.caret_box_x - self.caret_extend_x
	local car_y1 = line_ed.caret_box_y - self.caret_extend_y
	local car_x2 = self.align_offset + line_ed.caret_box_x + math.max(line_ed.caret_box_w, line_ed.caret_box_w_edge) + self.caret_extend_x
	local car_y2 = line_ed.caret_box_y + line_ed.caret_box_h + self.caret_extend_y

	--print("self.scr_tx", self.scr_tx, "car_x1", car_x1, "car_x2", car_x2)
	--print("self.scr_ty", self.scr_ty, "car_y1", car_y1, "car_y2", car_y2)

	widShared.scrollRectInBounds(self, car_x1, car_y1, car_x2, car_y2, immediate)
end


function lgcInputS.method_updateDocumentDimensions(self)
	local line_ed = self.line_ed
	local font = line_ed.font

	self.doc_w = line_ed.disp_text_w + line_ed.caret_box_w_empty
	self.doc_h = math.floor(font:getHeight() * font:getLineHeight())

	self:updateAlignOffset()
end


--- Call after changing alignment.
function lgcInputS.method_updateAlignOffset(self)
	local align = self.line_ed.align

	if align == "left" then
		self.align_offset = 0

	elseif align == "center" then
		self.align_offset = (self.doc_w < self.vp_w) and math.floor(0.5 + self.vp_w/2) or math.floor(0.5 + self.doc_w/2)

	else -- align == "right"
		self.align_offset = (self.doc_w < self.vp_w) and self.vp_w or self.doc_w
	end
end


-- Update the widget's caret shape and appearance.
function lgcInputS.updateCaretShape(self)
	local line_ed = self.line_ed

	self.caret_x = line_ed.caret_box_x
	self.caret_y = line_ed.caret_box_y
	self.caret_w = line_ed.caret_box_w
	self.caret_h = line_ed.caret_box_h

	if self.replace_mode then
		self.caret_fill = "line"
	else
		self.caret_fill = "fill"
		self.caret_w = line_ed.caret_line_width
	end
end


-- Draw the text component.
-- @param color_caret Table of colors for the text caret, or nil/false to not draw the caret.
-- @param font_ghost Font to use for optional "Ghost Text", or nil/false to not draw it.
-- @param color_text Table of colors to use for the body text, or nil/false to not draw it.
-- @param font Font to use when printing the main text (required, even if printing is disabled by color_text being false).
-- @param color_highlight Table of colors for the text highlight, or nil/false to not draw the highlight.
function lgcInputS.draw(self, color_highlight, font_ghost, color_text, font, color_caret)
	-- Call after setting up the text area scissor box, within `love.graphics.push("all")` and `pop()`.

	local line_ed = self.line_ed

	love.graphics.translate(
		self.vp_x + self.align_offset - self.scr_x,
		self.vp_y - self.scr_y
	)

	-- Highlighted selection.
	if color_highlight and line_ed.disp_highlighted then
		love.graphics.setColor(color_highlight)
		love.graphics.rectangle(
			"fill",
			line_ed.highlight_x,
			line_ed.highlight_y,
			line_ed.highlight_w,
			line_ed.highlight_h
		)
	end

	-- Ghost text. XXX: alignment
	if font_ghost and self.ghost_text and #line_ed.line == 0 then
		love.graphics.setFont(font_ghost)
		love.graphics.print(self.ghost_text, 0, 0)
	end

	-- Display Text.
	if color_text then
		love.graphics.setColor(color_text)
		love.graphics.setFont(font)
		love.graphics.print(line_ed.disp_text)
	end

	-- Caret.
	if color_caret and self == self.context.current_thimble and self.caret_is_showing then
		love.graphics.setColor(color_caret)
		love.graphics.rectangle(
			self.caret_fill,
			self.caret_x,
			self.caret_y,
			self.caret_w,
			self.caret_h
		)
	end
end


-- Configuration functions for pop-up menu items.


function lgcInputS.configItem_undo(item, client)
	item.selectable = true
	item.actionable = (client.line_ed.hist.pos > 1)
end


function lgcInputS.configItem_redo(item, client)
	item.selectable = true
	item.actionable = (client.line_ed.hist.pos < #client.line_ed.hist.ledger)
end


function lgcInputS.configItem_cutCopyDelete(item, client)
	item.selectable = true
	item.actionable = client.line_ed:isHighlighted()
end


function lgcInputS.configItem_paste(item, client)
	item.selectable = true
	item.actionable = true
end


function lgcInputS.configItem_selectAll(item, client)
	item.selectable = true
	item.actionable = (#client.line_ed.line > 0)
end


-- The default pop-up menu definition.
-- [XXX 17] Add key mnemonics and shortcuts for text box pop-up menu
lgcInputS.pop_up_def = {
	{
		type = "command",
		text = "Undo",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.undo,
		config = lgcInputS.configItem_undo,
	}, {
		type = "command",
		text = "Redo",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.redo,
		config = lgcInputS.configItem_redo,
	},
	itemOps.def_separator,
	{
		type = "command",
		text = "Cut",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.cut,
		config = lgcInputS.configItem_cutCopyDelete,
	}, {
		type = "command",
		text = "Copy",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.copy,
		config = lgcInputS.configItem_cutCopyDelete,
	}, {
		type = "command",
		text = "Paste",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.paste,
		config = lgcInputS.configItem_paste,
	}, {
		type = "command",
		text = "Delete",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.deleteHighlighted,
		config = lgcInputS.configItem_cutCopyDelete,
	},
	itemOps.def_separator,
	{
		type = "command",
		text = "Select All",
		callback = lgcInputS.cb_boundAction,
		bound_func = editActS.selectAll,
		config = lgcInputS.configItem_selectAll,
	},
}


return lgcInputS
