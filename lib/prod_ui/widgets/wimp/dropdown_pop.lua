-- XXX: Unfinished. Copy of `wimp/menu_pop.lua`.

--[[
wimp/dropdown_pop: The pop-up component of a dropdown menu.

'self.chain_prev' points to the invoking dropdown base widget.


Two menu-items are supported:
* Command: executes a function
* Separator


These are not real OS widgets, so they are limited to the boundaries of the window.
They may act strangely if the window is too small for the menu contents.

--]]


local context = select(1, ...)


local commonMenu = require(context.conf.prod_ui_req .. "logic.common_menu")
local commonScroll = require(context.conf.prod_ui_req .. "logic.common_scroll")
local textUtil = require(context.conf.prod_ui_req .. "lib.text_util")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


local def = {
	skin_id = "dropdown_pop1",
}


widShared.scrollSetMethods(def)
def.arrange = commonMenu.arrangeListVerticalTB


-- * Internal: Item activation *


local function activateCommand(client, item)

	-- XXX: Dropdown menus will behave differently. The dropdown box itself should have the callback with the item passed as an argument.

	local wid_ref = client.wid_ref

	if item.callback and wid_ref then -- XXX deal with cases where wid_ref is a dangling reference
		item.callback(wid_ref, item)
	end

	local root = client:getTopWidgetInstance()
	root:runStatement("rootCall_destroyPopUp", client, "concluded")
	root:runStatement("rootCall_restoreThimble", client)
end


-- * / Internal: Item activation *


local function keyMnemonicSearch(items, key)

	for i, item in ipairs(items) do
		if key == item.key_mnemonic then
			return i, item
		end
	end

	return nil
end



local function selectItemColor(item, client, skin)

	if item.actionable then
		return skin.color_actionable

	elseif client.menu.items[client.menu.index] == item then
		return skin.color_selected

	else
		return skin.color_inactive
	end
end


-- * MenuItem Defs *


def._mt_command = {
	type = "command",

	reshape = function(item, client)

		local font = client.skin.font_item

		item.text_x = (
			client.pad_bijou_x1
			+ client.bijou_draw_w
			+ client.pad_bijou_x2
			+ client.pad_text_x1
		)

		item.text_y = client.pad_text_y1
	end,
}
def._mt_command.__index = def._mt_command


def._mt_separator = {
	type = "separator",

	reshape = function(item, client)

	end,
}
def._mt_separator.__index = def._mt_separator


--- Append an item based on one of a few hardcoded types. The base menu addItem() method is low-level and not terribly
--  useful, so this wrapper is provided for convenience.
-- @param self The client widget.
-- @param item_type Identifier (typically a string) for the kind of item to append.
-- @param item_info Table of default fields to assign to the fresh item.
-- @return The new item table for additional tweaks.
function def:appendItem(item_type, info)

	local item = {
		x = 0,
		y = 0,
		w = 1,
		h = 1,
	}

	if item_type == "command" then
		item.text = info.text or ""

		-- internal version of item.text
		-- XXX: this was used as part of an underlining system that was removed when adapting menu_pop.lua for this def.
		item.text_int = ""
		item.text_x = 0
		item.text_y = 0

		item.text_s_x = 0
		item.text_s_y = 0

		item.bijou = info.bijou or false
		item.bijou_x = 0
		item.bijou_y = 0
		item.bijou_w = 0
		item.bijou_h = 0

		item.callback = info.callback

		item.selectable = true
		item.actionable = not not item.callback

		setmetatable(item, self._mt_command)

	elseif item_type == "separator" then
		item.selectable = false
		item.actionable = false

		setmetatable(item, self._mt_separator)

	else
		error("unknown item type: " .. tostring(item_type))
	end

	for k, v in pairs(info) do
		item[k] = v
	end

	self:addItem(item)

	return item
end


-- * / MenuItem Defs *


--- Changes the widget dimensions based on its menu contents.
function def:updateDimensions()

	--[[
	We need to:

	* Handle vertical item layout
	* Calculate item width by finding the widest single item
	* Reshape the widget to correctly set viewport rectangles
	* Set the width of all items to the width of viewport #1, and then reshape all items
	--]]
	-- XXX: We will just be using the maximum of (dropdown_box.w, widest item).

	local skin = self.skin
	local menu = self.menu
	local items = menu.items

	local font = skin.font_item

	-- Update item heights.
	for i, item in ipairs(items) do

		if item.type == "separator" then
			item.h = self.pad_separator_y

		else
			local font = skin.font_item

			local text_h, bijou_h = 1, 1
			text_h = font:getHeight() + self.pad_text_y1 + self.pad_text_y2
			if self.bijou then
				bijou_h = self.pad_bijou_y1 + self.bijou_draw_h + self.pad_bijou_y2
			end

			item.h = math.max(text_h, bijou_h)
		end
	end

	-- Arrange the items vertically.
	self:arrange()

	-- The work-in-progress widget dimensions.
	local w = 1
	local h = items and (items[#items].y + items[#items].h) or 1

	print("#items", #items, "h", h, "items[#items].y", items[#items].y, "items[#items].h", items[#items].h)

	-- Find the widest item text.
	local w_text = 0
	for i, item in ipairs(items) do
		if item.text_int then
			w_text = math.max(w_text, font:getWidth(item.text_int))
		end
	end
	w = (
		self.pad_bijou_x1 +
		self.bijou_draw_w +
		self.pad_bijou_x2 +
		self.pad_text_x1 +
		w_text +
		self.pad_text_x2
	)

	-- (We assume that the top-level widget's dimensions match the display area.)
	local wid_top = self:getTopWidgetInstance()

	self.w = math.min(w + self.margin_x1 + self.margin_x2, wid_top.w)
	self.h = math.min(h + self.margin_y1 + self.margin_y2, wid_top.h)

	self:reshape()

	-- Update item widths and then reshape their internals.
	for i, item in ipairs(self.menu.items) do
		item.w = self.vp_w
		item:reshape(self)
	end

	-- Refresh document size.
	self.doc_w, self.doc_h = commonMenu.getCombinedItemDimensions(menu.items)

	print(
		"self.w", self.w,
		"self.h", self.h,
		"self.vp_w", self.vp_w,
		"self.vp_h", self.vp_h,
		"self.doc_w", self.doc_w,
		"self.doc_h", self.doc_h
	)
end


function def:keepInView()

	local parent = self.parent

	if parent then
		self.x = math.max(0, math.min(self.x, parent.w - self.w))
		self.y = math.max(0, math.min(self.y, parent.h - self.h))
	end
end


-- * Scroll helpers *


def.getInBounds = commonMenu.getItemInBoundsRect
def.selectionInView = commonMenu.selectionInView


-- * / Scroll helpers *


-- * Spatial selection *


def.getItemAtPoint = commonMenu.widgetGetItemAtPoint -- (<self>, px, py, first, last)
def.trySelectItemAtPoint = commonMenu.widgetTrySelectItemAtPoint -- (<self>, x, y, first, last)


-- * / Spatial selection *


-- * Selection movement *


def.movePrev = commonMenu.widgetMovePrev
def.moveNext = commonMenu.widgetMoveNext
def.moveFirst = commonMenu.widgetMoveFirst
def.moveLast = commonMenu.widgetMoveLast


-- * / Selection movement *


-- * Item management *


--[[
	These 'add' and 'remove' methods are pretty basic. You may have to wrap them in functions that
	are more aware of the kind of menu in use.

	You also need to call self:menuChangeCleanup() when you are done adding or removing. (When handling
	many items at once, it doesn't make sense to call it over and over.)
--]]


--- Adds an item instance to the menu.
-- @param item_instance The item instance (not the def!) to add.
-- @param index (default: #items + 1) Where to add the item in the list.
-- @return Nothing.
function def:addItem(item_instance, index)

	local items = self.menu.items
	index = index or #items + 1

	table.insert(items, index, item_instance)

	item_instance:reshape(self)

	-- Call self:menuChangeCleanup() when you are done.
end


--- Removes an item from the menu at the specified index.
-- @param index (default: #items) Index of the item to remove. Must point to a valid table.
-- @return The removed item instance.
function def:removeItem(index)

	local items = self.menu.items
	index = index or #items

	-- Catch attempts to remove invalid item indexes (Lua's table.remove() is okay with empty indexes 0 and 1)
	if not items[index] then
		error("Menu has no item at index: " .. tostring(index))
	end

	local removed = table.remove(self.menu.items, index)

	return removed

	-- Call self:menuChangeCleanup() when you are done.
	-- No cleanup callback is run on the removed item, so any manual resource freeing needs to be handled by the caller.
end


--- Removes an item from the menu, using the item table reference instead of the index.
-- @param item The item table in the menu.
-- @return The removed item. Raises an error if the item is not found in the menu.
function def:removeItemTable(item) -- XXX untested

	local index
	for i, check in ipairs(self.menu.items) do
		if check == item then
			index = i
			break
		end
	end

	if not index then
		error("couldn't find item table in menu.")

	else
		return self:removeItem(index)
	end

	-- Call self:menuChangeCleanup() when you are done.
end


function def:menuChangeCleanup()

	self.menu:stepSelected(0, false)
	self:arrange()
	self:cacheUpdate(true)
	self:scrollClampViewport()
	self:selectionInView()
end


-- * / Item management *


function def:uiCall_create(inst)

	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		self.clip_scissor = true

		self.sort_id = 6

		widShared.setupDoc(self)
		widShared.setupScroll(self)
		widShared.setupViewport(self, 1)
		widShared.setupViewport(self, 2)

		self.press_busy = false

		-- Do not block this widget while a modal frame is active.
		self.modal_level = math.huge

		-- Ref to currently-hovered item, or false if not hovering over any items.
		self.item_hover = false

		self.wheel_jump_size = 64 -- pixels

		-- Range of items that are visible and should be checked for press/hover state.
		self.items_first = 0 -- max(first, 1)
		self.items_last = 2^53 -- min(last, #items)

		-- Edge margin -- XXX style/config, scale
		self.margin_x1 = 4
		self.margin_x2 = 4
		self.margin_y1 = 4
		self.margin_y2 = 4

		-- Padding values. -- XXX style/config, scale
		self.pad_bijou_x1 = 2
		self.pad_bijou_x2 = 2
		self.pad_bijou_y1 = 2
		self.pad_bijou_y2 = 2

		-- Drawing offsets and size for bijou quads.
		self.bijou_draw_w = 24
		self.bijou_draw_h = 24

		-- Padding above and below text and bijoux in items.
		-- The tallest of the two components determines the item's height.
		self.pad_text_x1 = 4
		self.pad_text_x2 = 4
		self.pad_text_y1 = 4
		self.pad_text_y2 = 4

		-- Padding for separators.
		self.pad_separator_y = 4

		-- Extends the selected item dimensions when scrolling to keep it within the bounds of the viewport.
		self.selection_extend_x = 0
		self.selection_extend_y = 0

		-- References populated when this widget is part of a chain of menus.
		self.chain_next = false
		self.chain_prev = false

		-- Caller sets this to the widget table that this menu "belongs to" or extends.
		self.wid_ref = false

		-- When this is a sub-menu, include a reference to the item in parent that was used to spawn it.
		--self.origin_item =

		self.menu = self.menu or commonMenu.new()
		self.menu.default_deselect = true

		self:skinSetRefs()
		self:skinInstall()

		self:reshape()
		self:menuChangeCleanup()
	end
end


function def:uiCall_reshape()

	self.vp_x = 0
	self.vp_y = 0
	self.vp_w = self.w
	self.vp_h = self.h

	-- Apply edge padding
	self.vp_x = self.vp_x + self.margin_x1
	self.vp_y = self.vp_y + self.margin_y1
	self.vp_h = self.vp_h - (self.margin_y1 + self.margin_y2)
	self.vp_w = self.vp_w - (self.margin_x1 + self.margin_x2)

	self.vp2_x = self.vp_x
	self.vp2_y = self.vp_y
	self.vp2_w = self.vp_w
	self.vp2_h = self.vp_h

	self:cacheUpdate()
end


--- Updates cached display state.
-- @param refresh_dimensions When true, update doc_w and doc_h based on the combined dimensions of all items.
-- @return Nothing.
function def:cacheUpdate(refresh_dimensions)

	local menu = self.menu

	if refresh_dimensions then
		self.doc_w, self.doc_h = commonMenu.getCombinedItemDimensions(menu.items)
	end

	-- Set the draw ranges for items.
	commonMenu.widgetAutoRangeV(self)
end


--- The default navigational key input.
function def:wid_defaultKeyNav(key, scancode, isrepeat)

	local mod = self.context.key_mgr.mod

	if key == "up" or (key == "tab" and mod["shift"]) then
		self:movePrev(1, true)
		return true

	elseif scancode == "down" or (key == "tab" and not mod["shift"]) then
		self:moveNext(1, true)
		return true
	end
end



function def:uiCall_keyPressed(inst, key, scancode, isrepeat)

	if self == inst then

		local root = self:getTopWidgetInstance()

		if key == "escape" then

			destroySubMenus(self)

			--print("self.chain_prev", self.chain_prev)

			-- Need some special handling depending on whether this is the base pop-up, or
			-- if the previous chain entry is the widget that invoked the pop-up (or is
			-- yet another temporary pop-up menu).

			-- This is the base pop-up.
			if not self.chain_prev or (self.wid_ref and self.wid_ref == self.chain_prev) then
				local wid_ref = self.wid_ref

				root:runStatement("rootCall_destroyPopUp", self, "concluded")
				-- NOTE: self is now dead.

				root:runStatement("rootCall_restoreThimble", wid_ref)

				-- If there is a reference widget, try and pass the thimble to it and clear
				-- the thimble bank. We assume the reference widget, if it cannot hold the
				-- thimble, has already restored the banked thimble via its cleanup callback.
				-- This is a Plan B behavior in case that's not true.
				if wid_ref then
					wid_ref:tryTakeThimble()
				end
				root:runStatement("rootCall_clearThimbleBank", wid_ref)

				return true

			-- This pop-up is further down the menu chain.
			-- We do not want to destroy the entire chain, just this one (and any others to the
			-- right, which we took care of above) and move the thimble back.
			else
				local temp_chain_prev = self.chain_prev

				self:remove()

				temp_chain_prev.chain_next = false
				temp_chain_prev:tryTakeThimble()

				return true
			end

		elseif key == "left" then
			-- Similar to Esc, but we only want to act here if chain_prev is another pop-up.
			if self.chain_prev and self.chain_prev ~= self.wid_ref then
				destroySubMenus(self)
				local temp_chain_prev = self.chain_prev

				self:remove()

				temp_chain_prev.chain_next = false
				temp_chain_prev:tryTakeThimble()

				return true
			end
		end
		-- 'left' needs to fall down here if not handled.

		local sel_item = self.menu.items[self.menu.index]

		if sel_item and sel_item.selectable and sel_item.actionable then
			if sel_item.type == "command" then
				if key == "return" or key == "kpenter" or key == "space" then
					activateCommand(self, sel_item)
					return true
				end
			end
		end

		-- Run the default navigation checks.
		if self.wid_defaultKeyNav and self:wid_defaultKeyNav(key, scancode, isrepeat) then
			return true
		end

		-- prev/next movement for the menu bar, if it exists and nothing has already handled input.
		if self.wid_ref and self.wid_ref.widCall_keyPressedFallback then
			local result = self.wid_ref:widCall_keyPressedFallback(self, key, scancode, isrepeat)
			if result then
				return true
			end
		end

		local mod = self.context.key_mgr.mod
		if not mod["ctrl"] then
			-- Finally, check for key mnemonics.
			local item_i, item = keyMnemonicSearch(self.menu.items, key)
			if item and item.selectable then
				self.menu:setSelectedIndex(item_i)
				if item.actionable then
					if item.type == "command" then
						activateCommand(self, item)
						return true
					end
				end
			end
		end
	end

	-- XXX: Test blocking keyhooks while the menu is active and has thimble focus.
	-- Solves issues like pressing Alt+? multiple times causing a jump from a window-frame
	-- menu to the root menu.
	-- It might break other things, though.
	return true -- XXX
end


function def:uiCall_pointerHoverOn(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)

	if self == inst then
		self:tryTakeThimble()
	end
end


local function pressedAndThimbleHandoff(self, wid)

	if self.context.current_pressed == self and wid.allow_hover then
		self.context:transferPressedState(wid)

		wid.press_busy = self.press_busy
		self.press_busy = false
	end

	wid:tryTakeThimble()

	if self.wid_chainRollOff then
		self:wid_chainRollOff()
	end
	if wid.wid_chainRollOn then
		wid:wid_chainRollOn()
	end
end


function def:uiCall_pointerDrag(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)

	if self == inst then
		local rolled = false

		if self.press_busy == "menu-drag" then

			-- Implement Drag-to-select.
			-- Need to test the full range of items because the mouse can drag outside the bounds of the viewport.

			-- Mouse position relative to viewport #1
			local mx, my = self:getRelativePosition(mouse_x, mouse_y)
			mx = mx - self.vp_x
			my = my - self.vp_y

			local item_i, item_t = self:getItemAtPoint(mx + self.scr_x, my + self.scr_y, 1, #self.menu.items)
			if item_i and item_t.selectable then
				self.menu:setSelectedIndex(item_i)

			else
				self.menu:setSelectedIndex(0)
			end
		end
	end
end


local function findOriginItemIndex(c_prev, origin_item)

	for i, c_item in ipairs(c_prev.menu.items) do
		--print(i, c_item, #c_prev.menu.items)
		if c_item == origin_item then
			return i
		end
	end

	-- return nil
end


function def:uiCall_pointerHoverMove(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)

	if self == inst then
		local mx, my = self:getRelativePosition(mouse_x, mouse_y)
		local xx = mx + self.scr_x - self.vp_x
		local yy = my + self.scr_y - self.vp_y

		local hover_ok = false

		if not self.press_busy and widShared.pointInViewport(self, 2, mx, my) then

			local menu = self.menu

			-- Update item hover
			local i, item = self:getItemAtPoint(xx, yy, math.max(1, self.items_first), math.min(#menu.items, self.items_last))

			if item and item.selectable then
				-- Un-hover any existing hovered item
				if self.item_hover ~= item then

					self.item_hover = item
				end

				-- Implement mouse hover-to-select.
				if (mouse_dx ~= 0 or mouse_dy ~= 0) then
					local selected_item = self.menu.items[self.menu.index]
					if item ~= selected_item then
						self.menu:setSelectedIndex(i)
					end
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
		self.item_hover = false
	end
end


function def:uiCall_pointerPress(inst, x, y, button, istouch, presses)

	if self == inst then
		if button <= 3 then
			self:tryTakeThimble()
		end

		local ax, ay = self:getAbsolutePosition()
		local mouse_x = x - ax
		local mouse_y = y - ay

		if widShared.pointInViewport(self, 2, mouse_x, mouse_y) then

			x = x - ax + self.scr_x - self.vp_x
			y = y - ay + self.scr_y - self.vp_y

			-- Check for click-able items.
			if not self.press_busy then
				local item_i, item_t = self:trySelectItemAtPoint(x, y, math.max(1, self.items_first), math.min(#self.menu.items, self.items_last))

				self.press_busy = "menu-drag"

				self:cacheUpdate(true)
			end
		end
	end
end


--function def:uiCall_pointerPressRepeat(inst, x, y, button, istouch, reps)


function def:uiCall_pointerUnpress(inst, x, y, button, istouch, presses)

	if self == inst then
		if button == self.context.mouse_pressed_button then
			self.press_busy = false

			-- Handle mouse unpressing over the selected item.
			if button == 1 then
				local item_selected = self.menu.items[self.menu.index]
				if item_selected and item_selected.selectable and item_selected.actionable then

					local ax, ay = self:getAbsolutePosition()
					local mouse_x = x - ax
					local mouse_y = y - ay

					-- Apply scroll and viewport offsets
					local xx = mouse_x + self.scr_x - self.vp_x
					local yy = mouse_y + self.scr_y - self.vp_y

					-- XXX safety precaution: ensure mouse position is within widget viewport #2?
					if xx >= item_selected.x and xx < item_selected.x + item_selected.w
					and yy >= item_selected.y and yy < item_selected.y + item_selected.h
					then
						if item_selected.type == "command" then
							activateCommand(self, item_selected)
						end
					end
				end
			end
		end
	end
end


function def:uiCall_pointerWheel(inst, x, y)

	if self == inst then
		-- (Positive Y == rolling wheel upward.)
		-- Only scroll if we are not at the edge of the scrollable area. Otherwise, the wheel
		-- event should bubble up.

		-- XXX support mapping single-dimensional wheel to horizontal scroll motion
		-- XXX support horizontal wheels

		if (y > 0 and self.scr_y > 0) or (y < 0 and self.scr_y < self.doc_h - self.vp_h) then
			local old_scr_x, old_scr_y = self.scr_x, self.scr_y

			-- Scroll about 1/4 of the visible items.
			--local n = self.h / self.item_h * 4
			self:scrollDeltaV(math.floor(self.wheel_jump_size * -y + 0.5))

			if old_scr_x ~= self.scr_x or old_scr_y ~= self.scr_y then
				self:cacheUpdate(true)
			end

			-- Stop bubbling
			return true
		end
	end
end


function def:uiCall_update(dt)

	dt = math.min(dt, 1.0)

	local scr_x_old, scr_y_old = self.scr_x, self.scr_y

	local needs_update = false

	-- Handle update-time drag-scroll.
	if self.press_busy == "menu-drag" and widShared.dragToScroll(self, dt) then
		needs_update = true
	end

	self:scrollUpdate(dt)

	-- Force a cache update if the external scroll position is different.
	if scr_x_old ~= self.scr_x or scr_y_old ~= self.scr_y then
		needs_update = true
	end

	local selected = self.menu.items[self.menu.index]

	local cur_thimble = self.context.current_thimble
	local in_chain = false
	local wid = self.chain_next
	while wid do
		if cur_thimble == wid then
			in_chain = true
			break
		end
		wid = wid.chain_next
	end

	--print("chain_next", self.chain_next, "in_chain", in_chain)
	--print("menu.index", self.menu.index, "selected", selected, "type", selected and selected.type)

	-- Is the mouse currently hovering over the selected item?
	local item_i, item_t
	if self.context.mouse_focus then
		local mx, my = self:getRelativePosition(self.context.mouse_x, self.context.mouse_y)
		item_i, item_t = self:getItemAtPoint(mx + self.scr_x - self.vp_x, my + self.scr_y - self.vp_y, 1, #self.menu.items)
	end

	--or not (self.chain_next and self.chain_next.origin_item == selected)

	--print("item_t", item_t, "selected", selected, "sel==itm", selected == item_t, "sel.type", selected and selected.type or "n/a")

	-- Update cache if necessary.
	if needs_update then
		self:cacheUpdate(true)
	end
end


function def:uiCall_destroy(inst)

	if self == inst then
		-- If this widget is part of a chain and currently holds the context pressed and/or thimble state,
		-- try to transfer it back to the previous menu in the chain.
		if self.press_busy == "menu-drag" then
			local c_prev = self.chain_prev
			if c_prev then
				pressedAndThimbleHandoff(self, c_prev)
			end
		end

		widShared.chainUnlink(self)
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
			local tq_px = skin.tq_px
			local tq_arrow = skin.tq_arrow

			local menu = self.menu
			local items = menu.items

			local font = skin.font_item

			local items_first, items_last = math.max(self.items_first, 1), math.min(self.items_last, #items)

			-- Don't draw menu contents outside of the widget bounding box.
			love.graphics.push("all")
			uiGraphics.intersectScissor(ox + self.x, oy + self.y, self.w, self.h)

			-- Back panel body
			local slc_body = skin.slc_body
			uiGraphics.drawSlice(slc_body, 0, 0, self.w, self.h)

			-- Scroll offsets
			love.graphics.translate(-self.scr_x + self.vp_x, -self.scr_y + self.vp_y)

			-- (Pop up menus do not render hover-glow.)

			-- Draw selection glow, if applicable
			local sel_item = items[menu.index]
			if sel_item then
				love.graphics.setColor(skin.color_select_glow)
				uiGraphics.quad1x1(tq_px, sel_item.x, sel_item.y, sel_item.w, sel_item.h)
			end

			-- Separators
			love.graphics.setColor(skin.color_separator)
			for i = items_first, items_last do
				local item = items[i]
				if item.type == "separator" then
					uiGraphics.quad1x1(tq_px, item.x, math.floor(item.y + item.h/2), item.w, skin.separator_size)
				end
			end

			-- Bijoux for commands, arrow graphics for groups
			for i = items_first, items_last do
				local item = items[i]
				--print("item.bijou", item.bijou, "xywh", item.bijou_x, item.bijou_y, item.bijou_w, item.bijou_h)
				if item.bijou then
					local tq_bijou = skin[item.bijou]
					if tq_bijou then
						local tbl_color = selectItemColor(item, self, skin)
						love.graphics.setColor(tbl_color)
						uiGraphics.quadXYWH(
							tq_bijou,
							item.x + self.pad_bijou_x1,
							item.y + self.pad_bijou_y1,
							self.bijou_draw_w,
							self.bijou_draw_h
						)
					end
				end
			end

			love.graphics.setFont(font)

			-- Main text
			for i = items_first, items_last do
				local item = items[i]

				-- Main text label
				if item.text_int then
					local tbl_color = selectItemColor(item, self, skin)
					love.graphics.setColor(tbl_color)

					love.graphics.print(
						item.text_int,
						item.x + item.text_x,
						item.y + item.text_y
					)
				end
			end

			love.graphics.pop()
		end,


		--renderLast = function(self, ox, oy) end,


		renderThimble = function(self, ox, oy)
			-- nothing
		end,
	},
}


return def
