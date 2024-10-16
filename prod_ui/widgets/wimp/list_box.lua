
--[[

A basic WIMP ListBox.

 ┌──────────────────────────┬─┐
 │[B] First item            │^│ ═╗
 │[B] Second item           ├─┤  ║
 │[B] Third                 │ │  ╠═ List items
 │[B] Fourth                │ │  ║
 │[B] And so on             ├─┤ ═╝
 │                          │v│
 ├─┬──────────────────────┬─┼─┤
 │<│                      │>│ │
 └─┴──────────────────────┴─┴─┘

   ^                         ^
   |                         |
Optional           Optional scroll bars
 icons
(bijoux)

--]]


local context = select(1, ...)


local commonMenu = require(context.conf.prod_ui_req .. "logic.common_menu")
local commonScroll = require(context.conf.prod_ui_req .. "logic.common_scroll")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widDebug = require(context.conf.prod_ui_req .. "logic.wid_debug")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


local def = {
	skin_id = "list_box1",
	click_repeat_oob = true, -- Helps with integrated scroll bar buttons
}


widShared.scrollSetMethods(def)
def.setScrollBars = commonScroll.setScrollBars
def.impl_scroll_bar = context:getLua("shared/impl_scroll_bar1")

def.arrange = commonMenu.arrangeListVerticalTB


-- * Scroll helpers *


def.getInBounds = commonMenu.getItemInBoundsY
def.selectionInView = commonMenu.selectionInView


-- * Spatial selection *


def.getItemAtPoint = commonMenu.widgetGetItemAtPointV -- (self, px, py, first, last)
def.trySelectItemAtPoint = commonMenu.widgetTrySelectItemAtPoint -- (self, x, y, first, last)


-- * Selection movement *


def.movePrev = commonMenu.widgetMovePrev
def.moveNext = commonMenu.widgetMoveNext
def.moveFirst = commonMenu.widgetMoveFirst
def.moveLast = commonMenu.widgetMoveLast


--- Called when user double-clicks on the widget or presses "return" or "kpenter".
-- @param item The current selected item, or nil if no item is selected.
-- @param item_i Index of the current selected item, or zero if no item is selected.
function def:wid_action(item, item_i)

end


--- Called when the user right-clicks on the widget or presses "application" or shift+F10.
-- @param item The current selected item, or nil if no item is selected.
-- @param item_i Index of the current selected item, or zero if no item is selected.
function def:wid_action2(item, item_i)

end


--- Called when the user middle-clicks on the widget.
-- @param item The current selected item, or nil if no item is selected.
-- @param item_i Index of the current selected item, or zero if no item is selected.
function def:wid_action3(item, item_i)

end


-- Called when there is a change in the selected item.
-- @param item The current selected item, or nil if no item is selected.
-- @param item_i Index of the current selected item, or zero if no item is selected.
function def:wid_select(item, item_i)
	-- XXX This may not be firing when going from a selected item to nothing selected.
end


--- Called in uiCall_keyPressed() before the default keyboard navigation checks.
-- @param key The key code.
-- @param scancode The scancode.
-- @param isrepeat Whether this is a key-repeat event.
-- @return true to halt keynav and further bubbling of the keyPressed event.
function def:wid_keyPressed(key, scancode, isrepeat)

end


--- Called when the mouse drags and drops something onto this widget.
-- @param drop_state A DropState table that describes the nature of the drag-and-drop action.
-- @return true to clear the DropState and to stop event bubbling.
function def:wid_dropped(drop_state)

end


--- Called in uiCall_keyPressed(). Implements basic keyboard navigation.
-- @param key The key code.
-- @param scancode The scancode.
-- @param isrepeat Whether this is a key-repeat event.
-- @return true to halt keynav and further bubbling of the keyPressed event.
function def:wid_defaultKeyNav(key, scancode, isrepeat)
	if scancode == "up" then
		self:movePrev(1, true)
		return true

	elseif scancode == "down" then
		self:moveNext(1, true)
		return true

	elseif scancode == "home" then
		self:moveFirst(true)
		return true

	elseif scancode == "end" then
		self:moveLast(true)
		return true

	elseif scancode == "pageup" then
		self:movePrev(self.page_jump_size, true)
		return true

	elseif scancode == "pagedown" then
		self:moveNext(self.page_jump_size, true)
		return true

	elseif scancode == "left" then
		self:DeltaH(-32) -- XXX config
		return true

	elseif scancode == "right" then
		self:scrollDeltaH(32) -- XXX config
		return true
	end
end


function def:addItem(text, pos, bijou_id)
	-- XXX: Assertions.

	local skin = self.skin
	local font = skin.font

	local items = self.menu.items

	local item = {}

	item.selectable = true
	item.marked = false -- multi-select

	item.x, item.y = 0, 0
	item.w = font:getWidth(text)
	item.h = math.floor((font:getHeight() * font:getLineHeight()) + skin.item_pad_v)

	item.text = text
	item.bijou_id = bijou_id
	item.tq_bijou = self.context.resources.tex_quads[bijou_id]

	pos = pos or #items + 1

	if pos < 1 or pos > #items + 1 then
		error("addItem: insert position is out of range.")
	end

	table.insert(items, pos, item)

	self:arrange(pos, #items)

	print("addItem text:", item.text, "y: ", item.y)

	return item
end


function def:removeItem(item_t)
	-- Assertions
	-- [[
	if type(item_t) ~= "table" then uiShared.errBadType(1, item_t, "table") end
	--]]

	local item_i = self.menu:getItemIndex(item_t)

	local removed_item = self:removeItemByIndex(item_i)
	return removed_item
end


function def:removeItemByIndex(item_i)
	-- Assertions
	-- [[
	uiShared.assertNumber(1, item_i)
	--]]

	local items = self.menu.items
	local removed_item = items[item_i]
	if not removed_item then
		error("no item to remove at index: " .. tostring(item_i))
	end

	table.remove(items, item_i)

	-- Removed item was the last in the list, and was selected:
	if self.menu.index > #self.menu.items then
		local landing_i = self.menu:findSelectableLanding(#self.menu.items, -1)
		if landing_i then
			self:setSelectionByIndex(landing_i)
		else
			self:setSelectionByIndex(0)
		end

	-- Removed item was not selected, and the selected item appears after the removed item in the list:
	elseif self.menu.index > item_i then
		self.menu.index = self.menu.index - 1
	end

	self:arrange(item_i, #items)

	return removed_item
end


function def:setSelection(item_t)
	-- Assertions
	-- [[
	if type(item_t) ~= "table" then uiShared.errBadType(1, item_t, "table") end
	--]]

	local item_i = self.menu:getItemIndex(item_t)
	self:setSelectionByIndex(item_i)
end


function def:setSelectionByIndex(item_i)
	-- Assertions
	-- [[
	uiShared.assertNumber(1, item_i)
	--]]

	self.menu:setSelectedIndex(item_i)
end


function def:setMarkedItem(item_t, marked)
	-- Assertions
	-- [[
	uiShared.assertTable(1, item_t)
	--]]

	item_t.marked = not not marked
end


function def:toggleMarkedItem(item_t)
	-- Assertions
	-- [[
	uiShared.assertTable(1, item_t)
	--]]

	item_t.marked = not item_t.marked
end


function def:setMarkedItemByIndex(item_i, marked)
	-- Assertions
	-- [[
	uiShared.assertNumber(1, item_i)
	--]]

	local item_t = self.menu.items[item_i]

	self:setMarkedItem(item_t, marked)
end


function def:getMarkedItem(item_t)
	-- Assertions
	-- [[
	uiShared.assertTable(1, item_t)
	--]]

	return item_t.marked
end


--- Produces a table that contains all items that are currently marked (multi-selected).
function def:getAllMarkedItems()
	local tbl = {}

	for i, item in ipairs(self.menu.items) do
		if item.marked then
			table.insert(tbl, item)
		end
	end

	return tbl
end


function def:clearAllMarkedItems()
	for i, item in ipairs(self.menu.items) do
		item.marked = false
	end
end


function def:setMarkedItemRange(marked, first, last)
	local menu = self.menu
	local items = menu.items

	marked = not not marked

	-- Assertions
	-- [[
	uiShared.assertIntRange(2, first, 1, #items)
	uiShared.assertIntRange(3, last, 1, #items)
	--]]

	for i = first, last do
		items[i].marked = marked
	end
end


function def:countMarkedItems()
	local count = 0

	for i, item in ipairs(self.menu.items) do
		if item.marked then
			count = count + 1
		end
	end

	return count
end


local function markItemsCursorMode(self, old_index)
	if not self.mark_index then
		self.mark_index = old_index
	end

	local menu = self.menu
	local items = menu.items

	local first, last = math.min(self.mark_index, menu.index), math.max(self.mark_index, menu.index)
	first, last = math.max(1, math.min(first, #items)), math.max(1, math.min(last, #items))

	self:setMarkedItemRange(true, first, last)
end


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		widShared.setupDoc(self)
		widShared.setupScroll(self)
		widShared.setupViewport(self, 1)
		widShared.setupViewport(self, 2)

		self.press_busy = false

		commonMenu.instanceSetup(self)

		self.menu = commonMenu.new()

		self.wrap_selection = false

		-- Column X positions and widths.
		self.col_icon_x = 0
		self.col_icon_w = 0

		self.col_text_x = 0
		self.col_text_w = 0

		-- State flags.
		self.enabled = true

		-- Shows a column of icons when true.
		self.show_icons = false

		-- Mouse drag behavior.
		-- NOTE: Some of these settings are mutually incompatible. Use the widget methods (TODO) to
		-- configure dragging.

		-- Scroll the view while dragging.
		self.drag_scroll = false

		-- Select new items while dragging.
		self.drag_select = false

		-- Reorder the current selected item while dragging.
		self.drag_reorder = false

		-- Support drag-and-drop transactions.
		-- false: disabled.
		-- true: when dragging the mouse outside of `context.mouse_pressed_range`.
		-- "edge": when dragging the mouse outside of the widget bounding box.
		self.drag_drop_mode = false

		--[[
		Multi-Selection modes.

		false: No built-in handling of multi-selection.
		"toggle": Behaves like a set of checkboxes.
		"cursor": Behaves (somewhat) like selections in a file browser GUI.

		`item.marked` is used to denote an item that is selected independent of the current
		menu index.
		--]]
		self.mark_mode = false

		-- When mark_mode is "toggle": Which marking state is being applied to items as the
		-- mouse sweeps over them.
		self.mark_state = false

		-- When mark_mode is "cursor": The old selection index when Shift+Click dragging started.
		-- false when Shift+Click dragging is not active.
		self.mark_index = false

		self:skinSetRefs()
		self:skinInstall()
	end
end


function def:uiCall_reshape()
	-- Viewport #1 is the main content viewport.
	-- Viewport #2 separates embedded controls (scroll bars) from the content.

	local skin = self.skin

	widShared.resetViewport(self, 1)

	-- Border and scroll bars.
	widShared.carveViewport(self, 1, "border")
	commonScroll.arrangeScrollBars(self)

	-- 'Okay-to-click' rectangle.
	widShared.copyViewport(self, 1, 2)

	-- Margin.
	widShared.carveViewport(self, 1, "margin")

	self:scrollClampViewport()
	commonScroll.updateScrollState(self)

	self:cacheUpdate(true)
end


--- Updates cached display state.
-- @param refresh_dimensions When true, update doc_w and doc_h based on the combined dimensions of all items.
-- @return Nothing.
function def:cacheUpdate(refresh_dimensions)
	local menu = self.menu
	local skin = self.skin

	if refresh_dimensions then
		self.doc_w, self.doc_h = 0, 0

		-- Document height is based on the last item in the menu.
		local last_item = menu.items[#menu.items]
		if last_item then
			self.doc_h = last_item.y + last_item.h
		end

		-- Calculate column widths.
		if self.show_icons then
			self.col_icon_w = skin.icon_spacing

		else
			self.col_icon_w = 0
		end

		self.col_text_w = 0
		local font = skin.font
		for i, item in ipairs(menu.items) do
			self.col_text_w = math.max(self.col_text_w, item.x + item.w)
		end

		-- Additional text padding.
		self.col_text_w = self.col_text_w + skin.pad_text_x

		self.col_text_w = math.max(self.col_text_w, self.vp_w - self.col_icon_w)

		-- Get column left positions.
		if skin.icon_side == "left" then
			self.col_icon_x = 0
			self.col_text_x = self.col_icon_w

		else
			self.col_icon_x = self.col_text_w
			self.col_text_x = 0
		end

		self.doc_w = math.max(self.vp_w, self.col_icon_w + self.col_text_w)
	end

	-- Set the draw ranges for items.
	commonMenu.widgetAutoRangeV(self)
end


function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	if self == inst then
		local items = self.menu.items
		local old_index = self.menu.index
		local old_item = items[old_index]

		-- wid_action() is handled in the 'thimbleAction()' callback.

		if self.mark_mode == "toggle" and key == "space" then
			if old_index > 0 and self.menu:canSelect(old_index) then
				self:toggleMarkedItem(self.menu.items[old_index])
				return true
			end

		elseif self:wid_keyPressed(key, scancode, isrepeat)
		or self:wid_defaultKeyNav(key, scancode, isrepeat)
		then
			if old_item ~= items[self.menu.index] then
				if self.mark_mode == "cursor" then
					local mods = self.context.key_mgr.mod
					if mods["shift"] then
						self:clearAllMarkedItems()
						markItemsCursorMode(self, old_index)

					else
						self.mark_index = false
						self:clearAllMarkedItems()
						self:setMarkedItemByIndex(self.menu.index, true)
					end
				end
				self:wid_select(items[self.menu.index], self.menu.index)
			end
			return true
		end
	end
end


function def:uiCall_pointerHoverMove(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		local mx, my = self:getRelativePosition(mouse_x, mouse_y)

		commonScroll.widgetProcessHover(self, mx, my)

		local hover_ok = false

		if not self.press_busy
		and widShared.pointInViewport(self, 2, mx, my)
		then
			mx = mx + self.scr_x
			my = my + self.scr_y

			local menu = self.menu

			-- Update item hover
			local i, item = self:getItemAtPoint(mx, my, math.max(1, self.items_first), math.min(#menu.items, self.items_last))

			if item and item.selectable then
				-- Un-hover any existing hovered item
				if self.item_hover ~= item then
					self.item_hover = item
				end

				hover_ok = true
			end
		end

		if self.item_hover and not hover_ok then
			self.item_hover = false
		end
	end
end


function def:uiCall_pointerHoverOff(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		commonScroll.widgetClearHover(self)
		self.item_hover = false
	end
end


function def:uiCall_pointerPress(inst, x, y, button, istouch, presses)
	if self == inst
	and self.enabled
	and button == self.context.mouse_pressed_button
	then
		if button <= 3 then
			self:tryTakeThimble()
		end

		local handled_scroll_bars = false

		-- Check for pressing on scroll bar components.
		if button == 1 then
			local fixed_step = 24 -- XXX style/config
			handled_scroll_bars = commonScroll.widgetScrollPress(self, x, y, fixed_step)
		end

		-- Successful mouse interaction with scroll bars should break any existing click-sequence.
		if handled_scroll_bars then
			self.context:clearClickSequence()
		else
			local mx, my = self:getRelativePosition(x, y)

			if widShared.pointInViewport(self, 2, mx, my) then
				mx = mx + self.scr_x
				my = my + self.scr_y

				-- Check for the cursor intersecting with a clickable item.
				local item_i, item_t = self:getItemAtPoint(mx, my, math.max(1, self.items_first), math.min(#self.menu.items, self.items_last))

				-- Reset click-sequence if clicking on a different item.
				if self.mouse_clicked_item ~= item_t then
					self.context:forceClickSequence(self, button, 1)
				end

				if item_t and item_t.selectable then
					local old_index = self.menu.index
					local old_item = self.menu.items[old_index]

					-- Buttons 1, 2 and 3 all select an item.
					-- Only button 1 updates the item mark state.
					if button <= 3 then
						commonMenu.widgetSelectItemByIndex(self, item_i)
						self.mouse_clicked_item = item_t

						if button == 1 then
							if self.mark_mode == "toggle" then
								item_t.marked = not item_t.marked
								self.mark_state = item_t.marked

							elseif self.mark_mode == "cursor" then
								local mods = self.context.key_mgr.mod

								if mods["shift"] then
									-- Unmark all items, then mark the range between the previous and current selections.
									self:clearAllMarkedItems()
									markItemsCursorMode(self, old_index)

								elseif mods["ctrl"] then
									item_t.marked = not item_t.marked
									self.mark_index = false

								else
									self:clearAllMarkedItems()
									item_t.marked = not item_t.marked
									self.mark_index = false
								end
							end
						end

						if old_item ~= item_t then
							self:wid_select(item_t, item_i)
						end
					end

					-- All Button 1 clicks initiate click-drag.
					if button == 1 then

						self.press_busy = "menu-drag"

						-- Double-clicking Button 1 invokes action 1.
						if self.context.cseq_button == 1
						and self.context.cseq_widget == self
						and self.context.cseq_presses % 2 == 0
						then
							self:wid_action(item_t, item_i)
						end

					-- Button 2 clicks invoke action 2.
					elseif button == 2 then
						self:wid_action2(item_t, item_i)

					-- Button 3 -> action 3...
					elseif button == 3 then
						self:wid_action3(item_t, item_i)
					end
				end
			end
		end
	end
end


function def:uiCall_pointerPressRepeat(inst, x, y, button, istouch, reps)
	if self == inst then
		-- Repeat-press events for scroll bar buttons
		if commonScroll.press_busy_codes[self.press_busy]
		and button == 1
		and button == self.context.mouse_pressed_button
		then
			local fixed_step = 24 -- XXX style/config
			commonScroll.widgetScrollPressRepeat(self, x, y, fixed_step)
		end
	end
end


function def:uiCall_pointerDrag(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	-- drag_reorder is incompatible with drag_drop_mode, drag_select, and the "toggle" and "cursor"
	-- mark modes.
	-- "toggle" mark mode is incompatible with all built-in drag-and-drop features.
	-- "cursor" mark mode overrides drag_drop_mode when active (hold shift while clicking and dragging).

	if self == inst
	and self.press_busy == "menu-drag"
	then
		if self.drag_drop_mode and self.mark_mode ~= "toggle" and not self.mark_index then
			local context = self.context
			local mpx, mpy, mpr = context.mouse_pressed_x, context.mouse_pressed_y, context.mouse_pressed_range
			if mouse_x > mpx + mpr or mouse_x < mpx - mpr or mouse_y > mpy + mpr or mouse_y < mpy - mpr then
				self.press_busy = "drag-drop"
				--print("Drag it!")

				local drop_state = {}

				drop_state.from = self
				drop_state.id = "menu"
				drop_state.item = self.menu.items[self.menu.index]
				-- menu index could be outdated by the time the drag-and-drop action is completed.

				if self:countMarkedItems() > 0 then
					drop_state.marked_items = self:getAllMarkedItems()
				end

				-- XXX: cursor, icon or render callback...?

				self:bubbleStatement("rootCall_setDragAndDropState", self, drop_state)
			end
		else
			-- Need to test the full range of items because the mouse can drag outside the bounds of the viewport.

			-- Mouse position with scroll offsets.
			local mx, my = self:getRelativePosition(mouse_x, mouse_y)
			mx = mx + self.scr_x
			my = my + self.scr_y

			local item_i, item_t = self:getItemAtPoint(mx, my, 1, #self.menu.items)
			if item_i and item_t.selectable then
				local items = self.menu.items
				local old_index = self.menu.index
				local old_item = items[old_index]

				if old_item ~= item_t then
					if self.drag_select then
						self.menu:setSelectedIndex(item_i)

						local mods = self.context.key_mgr.mod
						if self.mark_mode == "cursor" and self.mark_index then
							self:clearAllMarkedItems()
							markItemsCursorMode(self, old_index)

						elseif self.mark_mode == "toggle" then
							local first, last = math.min(old_index, item_i), math.max(old_index, item_i)
							first, last = math.max(1, first), math.max(1, last)
							self:setMarkedItemRange(self.mark_state, first, last)
							print("old", old_index, "item_i", item_i, "first", first, "last", last)
						end

						self:wid_select(item_t, item_i)

					elseif self.drag_reorder then
						items[old_index], items[item_i] = item_t, old_item
						self.menu.index = item_i
						self:arrange()
					end
				end

				-- Turn off item_hover so that other items don't glow.
				self.item_hover = false
			end
		end
	end
end


function def:uiCall_pointerUnpress(inst, x, y, button, istouch, presses)
	if self == inst
	and self.enabled
	and button == self.context.mouse_pressed_button
	then
		commonScroll.widgetClearPress(self)
		self.press_busy = false
	end
end


function def:uiCall_pointerWheel(inst, x, y)
	if self == inst then
		if widShared.checkScrollWheelScroll(self, x, y) then
			self:cacheUpdate(false)

			return true -- Stop bubbling.
		end
	end
end


function def:uiCall_pointerDragDestRelease(inst, x, y, button, istouch, presses)
	if self == inst then
		local root = self:getTopWidgetInstance()
		local drop_state = root.drop_state

		if type(drop_state) == "table" then
			local halt = self:wid_dropped(drop_state)
			if halt then
				root.drop_state = false
				return true
			end
		end
	end
end


function def:uiCall_thimbleAction(inst, key, scancode, isrepeat)
	if self == inst
	and self.enabled
	then
		local index = self.menu.index
		local item = self.menu.items[index]

		self:wid_action(item, index)

		return true -- Stop bubbling.
	end
end


function def:uiCall_thimbleAction2(inst, key, scancode, isrepeat)
	if self == inst
	and self.enabled
	then
		local index = self.menu.index
		local item = self.menu.items[index]

		self:wid_action2(item, index)

		return true -- Stop bubbling.
	end
end


function def:uiCall_update(dt)
	dt = math.min(dt, 1.0)

	local scr_x_old, scr_y_old = self.scr_x, self.scr_y
	local needs_update = false

	-- Clear click-sequence item.
	if self.mouse_clicked_item and self.context.cseq_widget ~= self then
		self.mouse_clicked_item = false
	end

	-- Handle update-time drag-scroll.
	if self.drag_scroll
	and self.press_busy == "menu-drag"
	and widShared.dragToScroll(self, dt)
	then
		needs_update = true

	elseif commonScroll.press_busy_codes[self.press_busy] then
		if self.context.mouse_pressed_ticks > 1 then
			local mx, my = self:getRelativePosition(self.context.mouse_x, self.context.mouse_y)
			local button_step = 350 -- XXX style/config
			commonScroll.widgetDragLogic(self, mx, my, button_step*dt)
		end
	end

	self:scrollUpdate(dt)

	-- Force a cache update if the external scroll position is different.
	if scr_x_old ~= self.scr_x or scr_y_old ~= self.scr_y then
		needs_update = true
	end

	-- Update scroll bar registers and thumb position.
	commonScroll.updateScrollBarShapes(self)
	commonScroll.updateScrollState(self)

	if needs_update then
		self:cacheUpdate(false)
	end
end


def.skinners = {
	default = {

		install = function(self, skinner, skin)
			uiTheme.skinnerCopyMethods(self, skinner)
		end,


		remove = function(self, skinner, skin)
			uiTheme.skinnerClearData(self)
		end,


		--refresh = function(self, skinner, skin)
		--update = function(self, skinner, skin, dt)


		render = function(self, ox, oy)
			local skin = self.skin
			local data_icon = skin.data_icon

			local tq_px = skin.tq_px
			local sl_body = skin.sl_body

			local menu = self.menu
			local items = menu.items

			-- XXX: pick resources for enabled or disabled state, etc.
			--local res = (self.active) and skin.res_active or skin.res_inactive

			-- ListBox body.
			love.graphics.setColor(1, 1, 1, 1)
			uiGraphics.drawSlice(sl_body, 0, 0, self.w, self.h)

			-- Embedded scroll bars, if present and active.
			local data_scroll = skin.data_scroll

			local scr_h = self.scr_h
			local scr_v = self.scr_v

			if scr_h and scr_h.active then
				self.impl_scroll_bar.draw(data_scroll, self.scr_h, 0, 0)
			end
			if scr_v and scr_v.active then
				self.impl_scroll_bar.draw(data_scroll, self.scr_v, 0, 0)
			end

			love.graphics.push("all")

			-- Scissor, scroll offsets for content.
			uiGraphics.intersectScissor(ox + self.x + self.vp2_x, oy + self.y + self.vp2_y, self.vp2_w, self.vp2_h)
			love.graphics.translate(-self.scr_x, -self.scr_y)

			-- Hover glow.
			local item_hover = self.item_hover
			if item_hover then
				love.graphics.setColor(skin.color_hover_glow)
				uiGraphics.quadXYWH(tq_px, 0, item_hover.y, self.doc_w, item_hover.h)
			end

			-- Selection glow.
			local sel_item = items[menu.index]
			if sel_item then
				love.graphics.setColor(skin.color_select_glow)
				uiGraphics.quadXYWH(tq_px, 0, sel_item.y, self.doc_w, sel_item.h)
			end

			-- Menu items.
			love.graphics.setColor(skin.color_item_text)
			local font = skin.font
			love.graphics.setFont(font)
			local font_h = font:getHeight()

			local first = math.max(self.items_first, 1)
			local last = math.min(self.items_last, #items)

			-- 1: Item markings
			local rr, gg, bb, aa = love.graphics.getColor()
			love.graphics.setColor(skin.color_item_marked)
			for i = first, last do
				local item = items[i]
				if item.marked then
					uiGraphics.quadXYWH(tq_px, 0, item.y, self.doc_w, item.h)
				end
			end

			-- 2: Bijou icons, if enabled
			love.graphics.setColor(rr, gg, bb, aa)
			if self.show_icons then
				for i = first, last do
					local item = items[i]
					local tq_bijou = item.tq_bijou
					if tq_bijou then
						uiGraphics.quadShrinkOrCenterXYWH(tq_bijou, self.col_icon_x, item.y, self.col_icon_w, item.h)
					end
				end
			end

			-- 3: Text labels
			for i = first, last do
				local item = items[i]
				-- ugh
				--[[
				love.graphics.push("all")
				love.graphics.setColor(1, 0, 0, 1)
				love.graphics.setLineWidth(1)
				love.graphics.setLineStyle("rough")
				love.graphics.setLineJoin("miter")
				love.graphics.rectangle("line", item.x + 0.5, item.y + 0.5, item.w - 1, item.h - 1)
				love.graphics.pop()
				--]]

				if item.text then
					-- Need to align manually to prevent long lines from wrapping.
					local text_x
					if skin.text_align_h == "left" then
						text_x = self.col_text_x + skin.pad_text_x

					elseif skin.text_align_h == "center" then
						text_x = self.col_text_x + math.floor((self.col_text_w - item.w) * 0.5)

					elseif skin.text_align_h == "right" then
						text_x = self.col_text_x + math.floor(self.col_text_w - item.w - skin.pad_text_x)
					end

					love.graphics.print(
						item.text,
						text_x,
						item.y + math.floor((item.h - font_h) * 0.5)
					)
				end
			end

			love.graphics.pop()

			--widDebug.debugDrawViewport(self, 1)
			--widDebug.debugDrawViewport(self, 2)
		end,

		--renderLast = function(self, ox, oy) end,
		--renderThimble = function(self, ox, oy) end,
	},
}


return def
