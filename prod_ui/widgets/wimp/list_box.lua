
--[[

A basic WIMP ListBox.

 ┌──────────────────────────┬─┐
 │[I] First item            │^│ ═╗
 │[C] Second item           ├─┤  ║
 │[O] Third                 │ │  ╠═ List items
 │[N] Fourth                │ │  ║
 │[S] And so on             ├─┤ ═╝
 │                          │v│
 ├─┬──────────────────────┬─┼─┤
 │<│                      │>│ │
 └─┴──────────────────────┴─┴─┘

   ^                         ^
   |                         |
Optional           Optional scroll bars
 icons

--]]


local context = select(1, ...)


local lgcMenu = context:getLua("shared/lgc_menu")
local lgcScroll = context:getLua("shared/lgc_scroll")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widShared = context:getLua("core/wid_shared")


local def = {
	skin_id = "list_box1",

	default_settings = {
		icon_side = "left", -- "left", "right"
		show_icons = false,
		text_align_h = "left", -- "left", "center", "right"
		icon_set_id = false, -- lookup for 'resources.icons[icon_set_id]'
	}
}


lgcMenu.attachMenuMethods(def)
widShared.scrollSetMethods(def)
def.setScrollBars = lgcScroll.setScrollBars
def.impl_scroll_bar = context:getLua("shared/impl_scroll_bar1")

def.arrangeItems = lgcMenu.arrangeItemsVerticalTB


-- * Scroll helpers *


def.getInBounds = lgcMenu.getItemInBoundsY
def.selectionInView = lgcMenu.selectionInView


-- * Spatial selection *


def.getItemAtPoint = lgcMenu.widgetGetItemAtPointV -- (self, px, py, first, last)
def.trySelectItemAtPoint = lgcMenu.widgetTrySelectItemAtPoint -- (self, x, y, first, last)


-- * Selection movement *


def.movePrev = lgcMenu.widgetMovePrev
def.moveNext = lgcMenu.widgetMoveNext
def.moveFirst = lgcMenu.widgetMoveFirst
def.moveLast = lgcMenu.widgetMoveLast
def.movePageUp = lgcMenu.widgetMovePageUp
def.movePageDown = lgcMenu.widgetMovePageDown


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
		self:movePrev(1, true, isrepeat)
		return true

	elseif scancode == "down" then
		self:moveNext(1, true, isrepeat)
		return true

	elseif scancode == "home" then
		self:moveFirst(true)
		return true

	elseif scancode == "end" then
		self:moveLast(true)
		return true

	elseif scancode == "pageup" then
		self:movePageUp(true)
		return true

	elseif scancode == "pagedown" then
		self:movePageDown(true)
		return true

	elseif scancode == "left" then
		self:scrollDeltaH(-self.context.settings.wimp.navigation.key_scroll_h)
		return true

	elseif scancode == "right" then
		self:scrollDeltaH(self.context.settings.wimp.navigation.key_scroll_h)
		return true
	end
end


local function _shapeItem(self, item)
	local skin = self.skin
	local font = skin.font

	item.w = font:getWidth(item.text)
	item.h = math.floor((font:getHeight() * font:getLineHeight()) + skin.item_pad_v)
end


function def:addItem(text, pos, icon_id)
	uiShared.type1(1, text, "string")
	uiShared.intEval(2, pos, "number")
	uiShared.typeEval1(3, icon_id, "string")

	local skin = self.skin
	local font = skin.font

	local items = self.MN_items

	local item = {}

	item.selectable = true
	item.marked = false -- multi-select

	item.text = text
	item.icon_id = icon_id
	item.tq_icon = false
	item.tq_icon = lgcMenu.getIconQuad(self.icon_set_id, item.icon_id)

	item.x, item.y = 0, 0
	_shapeItem(self, item)

	pos = pos or #items + 1

	if pos < 1 or pos > #items + 1 then
		error("addItem: insert position is out of range.")
	end

	table.insert(items, pos, item)

	self:arrangeItems(1, pos, #items)

	print("addItem text:", item.text, "y: ", item.y)

	return item
end


function def:removeItem(item_t)
	uiShared.type1(1, item_t, "table")

	local item_i = self:menuGetItemIndex(item_t)

	local removed_item = self:removeItemByIndex(item_i)
	return removed_item
end


function def:removeItemByIndex(item_i)
	uiShared.numberNotNaN(1, item_i)

	local items = self.MN_items
	local removed_item = items[item_i]
	if not removed_item then
		error("no item to remove at index: " .. tostring(item_i))
	end

	table.remove(items, item_i)

	lgcMenu.removeItemIndexCleanup(self, item_i, "MN_index")

	self:arrangeItems(1, item_i, #items)

	return removed_item
end


function def:setSelection(item_t)
	uiShared.type1(1, item_t, "table")

	local item_i = self:menuGetItemIndex(item_t)
	self:setSelectionByIndex(item_i)
end


function def:setSelectionByIndex(item_i)
	uiShared.intGE(1, item_i, 0)

	local old_index = self.MN_index
	self:menuSetSelectedIndex(item_i)
	if old_index ~= self.MN_index then
		self:wid_select(self.MN_items[self.MN_index], self.MN_index)
	end
end


def.setIconSetID = lgcMenu.setIconSetID
def.getIconSetID = lgcMenu.getIconSetID


function def:uiCall_initialize()
	self.visible = true
	self.allow_hover = true
	self.thimble_mode = 1

	widShared.setupDoc(self)
	widShared.setupScroll(self, -1, -1)
	widShared.setupViewports(self, 2)

	self.press_busy = false

	lgcMenu.setup(self, nil, true, true) -- with mark and drag+drop state

	self.MN_wrap_selection = false

	-- Column X positions and widths.
	self.col_icon_x = 0
	self.col_icon_w = 0

	self.col_text_x = 0
	self.col_text_w = 0

	-- State flags.
	self.enabled = true

	self:skinSetRefs()
	self:skinInstall()
	self:applyAllSettings()
end


function def:uiCall_reshapePost()
	-- Viewport #1 is the main content viewport.
	-- Viewport #2 separates embedded controls (scroll bars) from the content.

	local skin = self.skin

	widShared.resetViewport(self, 1)

	-- Border and scroll bars.
	widShared.carveViewport(self, 1, skin.box.border)
	lgcScroll.arrangeScrollBars(self)

	-- 'Okay-to-click' rectangle.
	widShared.copyViewport(self, 1, 2)

	-- Margin.
	widShared.carveViewport(self, 1, skin.box.margin)

	self:scrollClampViewport()
	lgcScroll.updateScrollState(self)

	self:cacheUpdate(true)
end


--- Updates cached display state.
-- @param refresh_dimensions When true, update doc_w and doc_h based on the combined dimensions of all items.
-- @return Nothing.
function def:cacheUpdate(refresh_dimensions)
	local skin = self.skin

	if refresh_dimensions then
		self.doc_w, self.doc_h = 0, 0

		-- Document height is based on the last item in the menu.
		local last_item = self.MN_items[#self.MN_items]
		if last_item then
			self.doc_h = last_item.y + last_item.h
		end

		-- Calculate column widths.
		self.col_icon_w = self.show_icons and skin.icon_spacing or 0

		self.col_text_w = 0
		local font = skin.font
		for i, item in ipairs(self.MN_items) do
			self.col_text_w = math.max(self.col_text_w, item.x + item.w)
		end

		-- Additional text padding.
		self.col_text_w = self.col_text_w + skin.pad_text_x

		self.col_text_w = math.max(self.col_text_w, self.vp_w - self.col_icon_w)

		-- Get column left positions.
		if self.icon_side == "left" then
			self.col_icon_x = 0
			self.col_text_x = self.col_icon_w
		else
			self.col_icon_x = self.col_text_w
			self.col_text_x = 0
		end

		self.doc_w = math.max(self.vp_w, self.col_icon_w + self.col_text_w)
	end

	-- Set the draw ranges for items.
	lgcMenu.widgetAutoRangeV(self)
end


function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	if self == inst then
		local items = self.MN_items
		local old_index = self.MN_index
		local old_item = items[old_index]

		-- wid_action() is handled in the 'thimbleAction()' callback.

		if self.MN_mark_mode == "toggle" and key == "space" then
			if old_index > 0 and self:menuCanSelect(old_index) then
				self:menuToggleMarkedItem(self.MN_items[old_index])
				return true
			end

		elseif self:wid_keyPressed(key, scancode, isrepeat)
		or self:wid_defaultKeyNav(key, scancode, isrepeat)
		then
			if old_item ~= items[self.MN_index] then
				if self.MN_mark_mode == "cursor" then
					local mods = self.context.key_mgr.mod
					if mods["shift"] then
						self:menuClearAllMarkedItems()
						lgcMenu.markItemsCursorMode(self, old_index)
					else
						self.MN_mark_index = false
						self:menuClearAllMarkedItems()
						self:menuSetMarkedItemByIndex(self.MN_index, true)
					end
				end
				self:wid_select(items[self.MN_index], self.MN_index)
			end
			return true
		end
	end
end


function def:uiCall_pointerHover(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		local mx, my = self:getRelativePosition(mouse_x, mouse_y)

		lgcScroll.widgetProcessHover(self, mx, my)

		local hover_ok = false

		if widShared.pointInViewport(self, 2, mx, my) then
			mx, my = mx + self.scr_x, my + self.scr_y

			-- Update item hover
			local i, item = self:getItemAtPoint(mx, my, math.max(1, self.MN_items_first), math.min(#self.MN_items, self.MN_items_last))

			if item and item.selectable then
				-- Un-hover any existing hovered item
				self.MN_item_hover = item

				hover_ok = true
			end
		end

		if self.MN_item_hover and not hover_ok then
			self.MN_item_hover = false
		end
	end
end


function def:uiCall_pointerHoverOff(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		lgcScroll.widgetClearHover(self)
		self.MN_item_hover = false
	end
end


function def:uiCall_pointerPress(inst, x, y, button, istouch, presses)
	if self == inst
	and self.enabled
	and button == self.context.mouse_pressed_button
	then
		if button <= 3 then
			self:tryTakeThimble1()
		end

		if not lgcMenu.pointerPressScrollBars(self, x, y, button) then
			local mx, my = self:getRelativePosition(x, y)

			if widShared.pointInViewport(self, 2, mx, my) then
				mx = mx + self.scr_x
				my = my + self.scr_y

				local item_i, item_t = lgcMenu.checkItemIntersect(self, mx, my, button)

				if item_t and item_t.selectable then
					local old_index = self.MN_index
					local old_item = self.MN_items[old_index]

					-- Buttons 1, 2 and 3 all select an item.
					-- Only button 1 updates the item mark state.
					if button <= 3 then
						lgcMenu.widgetSelectItemByIndex(self, item_i)
						self.MN_mouse_clicked_item = item_t

						if button == 1 then
							lgcMenu.pointerPressButton1(self, item_t, old_index)
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
		lgcMenu.pointerPressRepeatLogic(self, x, y, button, istouch, reps)
	end
end


function def:uiCall_pointerDrag(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst and self.press_busy == "menu-drag" then
		lgcMenu.menuPointerDragLogic(self, mouse_x, mouse_y)
	end
end


function def:uiCall_pointerUnpress(inst, x, y, button, istouch, presses)
	if self == inst
	and self.enabled
	and button == self.context.mouse_pressed_button
	then
		lgcScroll.widgetClearPress(self)
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
		return lgcMenu.dragDropReleaseLogic(self)
	end
end


function def:uiCall_thimbleAction(inst, key, scancode, isrepeat)
	if self == inst
	and self.enabled
	then
		local index = self.MN_index
		local item = self.MN_items[index]

		self:wid_action(item, index)

		return true -- Stop bubbling.
	end
end


function def:uiCall_thimbleAction2(inst, key, scancode, isrepeat)
	if self == inst
	and self.enabled
	then
		local index = self.MN_index
		local item = self.MN_items[index]

		self:wid_action2(item, index)

		return true -- Stop bubbling.
	end
end


function def:uiCall_update(dt)
	dt = math.min(dt, 1.0)

	local scr_x_old, scr_y_old = self.scr_x, self.scr_y
	local needs_update = false

	-- Clear click-sequence item.
	if self.MN_mouse_clicked_item and self.context.cseq_widget ~= self then
		self.MN_mouse_clicked_item = false
	end

	-- Handle update-time drag-scroll.
	if self.MN_drag_scroll
	and self.press_busy == "menu-drag"
	and widShared.dragToScroll(self, dt)
	then
		needs_update = true

	elseif lgcScroll.press_busy_codes[self.press_busy] then
		if self.context.mouse_pressed_ticks > 1 then
			local mx, my = self:getRelativePosition(self.context.mouse_x, self.context.mouse_y)
			local button_step = 350 -- XXX style/config
			lgcScroll.widgetDragLogic(self, mx, my, button_step*dt)
		end
	end

	self:scrollUpdate(dt)

	-- Force a cache update if the external scroll position is different.
	if scr_x_old ~= self.scr_x or scr_y_old ~= self.scr_y then
		needs_update = true
	end

	-- Update scroll bar registers and thumb position.
	lgcScroll.updateScrollBarShapes(self)
	lgcScroll.updateScrollState(self)

	if needs_update then
		self:cacheUpdate(false)
	end
end


local check, change = uiTheme.check, uiTheme.change


def.default_skinner = {
	validate = function(skin)
		-- Settings
		check.exact(skin, "icon_side", nil, "left", "right")
		check.type(skin, "show_icons", "nil", "boolean")
		check.exact(skin, "text_align_h", nil, "left", "center", "right")
		check.type(skin, "icon_set_id", "nil", "string")
		-- / Settings

		check.box(skin, "box")
		check.quad(skin, "tq_px")
		check.scrollBarData(skin, "data_scroll")
		check.scrollBarStyle(skin, "scr_style")

		check.loveType(skin, "font", "Font")

		-- Item height is calculated as: math.floor((font:getHeight() * font:getLineHeight()) + item_pad_v)
		check.integer(skin, "item_pad_v")

		check.slice(skin, "sl_body")

		-- Vertical text alignment is centered.

		-- Icon column width and positioning, if active.
		check.integer(skin, "icon_spacing")

		-- Additional padding for left or right-aligned text. No effect with center alignment.

		check.integer(skin, "pad_text_x")

		check.colorTuple(skin, "color_body")
		check.colorTuple(skin, "color_item_text")
		check.colorTuple(skin, "color_item_icon")
		check.colorTuple(skin, "color_select_glow")
		check.colorTuple(skin, "color_hover_glow")
		check.colorTuple(skin, "color_active_glow")
		check.colorTuple(skin, "color_item_marked")
	end,


	transform = function(skin, scale)
		change.integerScaled(skin, "item_pad_v", scale)
		change.integerScaled(skin, "icon_spacing", scale)
		change.integerScaled(skin, "pad_text_x", scale)
	end,


	install = function(self, skinner, skin)
		uiTheme.skinnerCopyMethods(self, skinner)

		-- Update shapes, positions, and icons of any existing items
		for i, item in ipairs(self.MN_items) do
			item.tq_icon = lgcMenu.getIconQuad(self.icon_set_id, item.icon_id)
			_shapeItem(self, item)
		end

		self:arrangeItems(1)

		-- Update the scroll bar style
		self:setScrollBars(self.scr_h, self.scr_v)
	end,


	remove = function(self, skinner, skin)
		uiTheme.skinnerClearData(self)
	end,


	--refresh = function(self, skinner, skin)
	--update = function(self, skinner, skin, dt)


	render = function(self, ox, oy)
		local skin = self.skin

		local tq_px = skin.tq_px
		local sl_body = skin.sl_body

		local items = self.MN_items
		local rr, gg, bb, aa = love.graphics.getColor()

		love.graphics.push("all")

		-- XXX: pick resources for enabled or disabled state, etc.
		--local res = (self.active) and skin.res_active or skin.res_inactive

		-- ListBox body.
		love.graphics.setColor(skin.color_body)
		uiGraphics.drawSlice(sl_body, 0, 0, self.w, self.h)

		love.graphics.setColor(rr, gg, bb, aa)
		lgcScroll.drawScrollBarsHV(self, skin.data_scroll)

		-- Scissor, scroll offsets for content.
		uiGraphics.intersectScissor(ox + self.x + self.vp2_x, oy + self.y + self.vp2_y, self.vp2_w, self.vp2_h)
		love.graphics.translate(-self.scr_x, -self.scr_y)

		-- Hover glow.
		local item_hover = self.MN_item_hover
		if item_hover then
			love.graphics.setColor(skin.color_hover_glow)
			uiGraphics.quadXYWH(tq_px, 0, item_hover.y, self.doc_w, item_hover.h)
		end

		-- Selection glow.
		local sel_item = items[self.MN_index]
		if sel_item then
			local is_active = self == self.context.thimble1
			local col = is_active and skin.color_active_glow or skin.color_select_glow
			love.graphics.setColor(col)
			uiGraphics.quadXYWH(tq_px, 0, sel_item.y, self.doc_w, sel_item.h)
		end

		-- Menu items.
		local font = skin.font
		love.graphics.setFont(font)
		local font_h = font:getHeight()

		local first = math.max(self.MN_items_first, 1)
		local last = math.min(self.MN_items_last, #items)

		-- 1: Item markings
		love.graphics.setColor(skin.color_item_marked)
		for i = first, last do
			local item = items[i]
			if item.marked then
				uiGraphics.quadXYWH(tq_px, 0, item.y, self.doc_w, item.h)
			end
		end

		-- 2: Item icons, if enabled
		if self.show_icons then
			love.graphics.setColor(skin.color_item_icon)
			for i = first, last do
				local item = items[i]
				local tq_icon = item.tq_icon
				if tq_icon then
					uiGraphics.quadShrinkOrCenterXYWH(tq_icon, self.col_icon_x, item.y, self.col_icon_w, item.h)
				end
			end
		end

		-- 3: Text labels
		love.graphics.setColor(skin.color_item_text)
		for i = first, last do
			local item = items[i]
			if item.text then
				-- Need to align manually to prevent long lines from wrapping.
				local text_x
				if self.text_align_h == "left" then
					text_x = self.col_text_x + skin.pad_text_x

				elseif self.text_align_h == "center" then
					text_x = self.col_text_x + math.floor((self.col_text_w - item.w) * 0.5)

				elseif self.text_align_h == "right" then
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
	end,

	--renderLast = function(self, ox, oy) end,
	--renderThimble = function(self, ox, oy) end,
}


return def
