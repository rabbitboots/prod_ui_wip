-- XXX: Under construction.
--[[
A flat list of properties with embedded controls.

               Drag to resize columns
                         │
Optional icons (bijoux)  │
   │                     │
   │ Labels              │       Controls
   │   │                 │          │
   V   V                 V          V
┌───────────────────────────────────────────────┬─┐
│ [B] Foo                |                  [x] │^│
│:[B]:Bar::::::::::::::::│:[              0.02]:├─┤
│ [B] Baz                │ ["Twist"           ]:│ │
│ [B] Qux                │ [dir/ectory        ] │ │
│                        |                      ├─┤
│                        |                      │v│
└───────────────────────────────────────────────┴─┘
--]]


local context = select(1, ...)


local commonScroll = require(context.conf.prod_ui_req .. "common.common_scroll")
local lgcMenu = context:getLua("shared/lgc_menu")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widDebug = require(context.conf.prod_ui_req .. "common.wid_debug")
local widShared = require(context.conf.prod_ui_req .. "common.wid_shared")


local def = {
	skin_id = "properties_box1",
	click_repeat_oob = true, -- Helps with integrated scroll bar buttons
}


widShared.scrollSetMethods(def)
def.setScrollBars = commonScroll.setScrollBars
def.impl_scroll_bar = context:getLua("shared/impl_scroll_bar1")

def.arrange = lgcMenu.arrangeListVerticalTB


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
		self:movePrev(self.MN_page_jump_size, true)
		return true

	elseif scancode == "pagedown" then
		self:moveNext(self.MN_page_jump_size, true)
		return true

	elseif scancode == "left" then
		self:scrollDeltaH(-32) -- XXX config
		return true

	elseif scancode == "right" then
		self:scrollDeltaH(32) -- XXX config
		return true
	end
end


function def:addControl(wid_id, text, pos, bijou_id)
	uiShared.type1(2, text, "string")
	uiShared.intEval(3, pos, "number")
	uiShared.typeEval1(4, bijou_id, "string")

	local wid = self:addChild(wid_id, nil, pos)

	wid.selectable = true
	wid.marked = false -- multi-select
	wid.x, wid.y = 0, 0
	wid.w = 256 -- WIP
	wid.h = 40 -- WIP
	wid.text = text
	wid.bijou_id = bijou_id
	wid.tq_bijou = self.context.resources.tex_quads[bijou_id]

	self:arrange(4, pos, #self.children)

	print("addControl text:", wid.text, "xywh: ", wid.x, wid.y, wid.w, wid.h)

	return wid
end


function def:removeControl(wid)
	uiShared.type1(1, wid, "table")

	local wid_i = self.menu:getItemIndex(wid)

	self:removeControlByIndex(wid_i)
end


function def:removeControlByIndex(wid_i)
	uiShared.numberNotNaN(1, wid_i)

	local children = self.children
	local to_remove = children[wid_i]
	if not to_remove then
		error("no control to remove at index: " .. tostring(wid_i))
	end

	to_remove:remove()

	-- Removed control was the last in the list, and was selected:
	if self.menu.index > #children then
		local landing_i = self.menu:findSelectableLanding(#children, -1)
		self:setSelectionByIndex(landing_i or 0)

	-- Removed control was not selected, and the selected control appears after the removed control in the list:
	elseif self.menu.index > wid_i then
		self.menu.index = self.menu.index - 1
	end

	self:arrange(4, wid_i, #children)
end


function def:setSelection(wid)
	uiShared.type1(1, wid, "table")

	local wid_i = self.menu:getItemIndex(wid)
	self:setSelectionByIndex(wid_i)
end


function def:setSelectionByIndex(wid_i)
	uiShared.intGE(1, wid_i, 0)

	self.menu:setSelectedIndex(wid_i)
end


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		widShared.setupDoc(self)
		widShared.setupScroll(self)
		widShared.setupViewports(self, 5)

		self.press_busy = false

		lgcMenu.instanceSetup(self, true, true) -- with mark and drag+drop state

		self.MN_wrap_selection = false

		self.menu = lgcMenu.new(self.children) -- (self.menu.items == self.children)

		self.sash_enabled = true

		-- Column X positions and widths.
		self.col_icon_x = 0
		self.col_icon_w = 0

		self.col_text_x = 0
		self.col_text_w = 0

		-- State flags.
		self.enabled = true

		-- Shows a column of icons when true.
		self.show_icons = false

		self:skinSetRefs()
		self:skinInstall()
	end
end


function def:uiCall_reshape()
	-- Viewport #1 is the main content viewport.
	-- Viewport #2 separates embedded controls (scroll bars) from the content.
	-- Viewport #3 is the area for item labels.
	-- Viewport #4 is the area for item controls (child widgets).
	-- Viewport #5 is a sash that is placed between the labels and controls.

	-- The sash viewport overlaps labels and controls, so cursor intersection
	-- tests should check it first.

	local skin = self.skin

	widShared.resetViewport(self, 1)

	-- Border and scroll bars.
	widShared.carveViewport(self, 1, "border")
	commonScroll.arrangeScrollBars(self)

	-- 'Okay-to-click' rectangle.
	widShared.copyViewport(self, 1, 2)

	-- Margin.
	widShared.carveViewport(self, 1, "margin")

	-- Label and control areas.
	widShared.copyViewport(self, 1, 3)
	widShared.partitionViewport(self, 3, 4, self.vp3_w / 2, "right")

	-- Sash.
	self.vp5_w = skin.sash_w
	widShared.straddleViewport(self, 3, 5, "right", 0.5)

	self:scrollClampViewport()
	commonScroll.updateScrollState(self)

	-- Reposition and resize controls.
	for i, wid in ipairs(self.menu.items) do
		wid.x = 0
		wid.y = 0
		wid.w = 256 -- WIP
		wid.h = 40 -- WIP
	end

	self:cacheUpdate(true)
end


--- Updates cached display state.
-- @param refresh_dimensions When true, update doc_w and doc_h based on the combined dimensions of all controls.
-- @return Nothing.
function def:cacheUpdate(refresh_dimensions)
	local menu = self.menu
	local skin = self.skin

	if refresh_dimensions then
		self.doc_w, self.doc_h = 0, 0

		local children = menu.items

		-- Document height is based on the last control in the menu.
		local last_wid = children[#children]
		if last_wid then
			self.doc_h = last_wid.y + last_wid.h
		end

		-- Calculate column widths.
		if self.show_icons then
			self.col_icon_w = skin.icon_spacing
		else
			self.col_icon_w = 0
		end

		self.col_text_w = 0
		local font = skin.font
		for i, wid in ipairs(children) do
			self.col_text_w = math.max(self.col_text_w, wid.x + wid.w)
		end

		-- Additional text padding.
		self.col_text_w = self.col_text_w + skin.pad_text_x
		self.col_text_w = math.max(self.col_text_w, self.vp3_w - self.col_icon_w)

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

	-- Set the draw ranges for controls.
	lgcMenu.widgetAutoRangeV(self)
end


function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	if self == inst then
		local items = self.menu.items
		local old_index = self.menu.index
		local old_item = items[old_index]

		-- wid_action() is handled in the 'thimbleAction()' callback.

		if self.MN_mark_mode == "toggle" and key == "space" then
			if old_index > 0 and self.menu:canSelect(old_index) then
				self.menu:toggleMarkedItem(self.menu.items[old_index])
				return true
			end

		elseif self:wid_keyPressed(key, scancode, isrepeat)
		or self:wid_defaultKeyNav(key, scancode, isrepeat)
		then
			if old_item ~= items[self.menu.index] then
				if self.MN_mark_mode == "cursor" then
					local mods = self.context.key_mgr.mod
					if mods["shift"] then
						self.menu:clearAllMarkedItems()
						lgcMenu.markItemsCursorMode(self, old_index)
					else
						self.MN_mark_index = false
						self.menu:clearAllMarkedItems()
						self.menu:setMarkedItemByIndex(self.menu.index, true)
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

		-- Hovering over an active sash
		if self.sash_enabled and widShared.pointInViewport(self, 5, mx, my) then
			self:setCursorLow(self.skin.cursor_sash)

		-- Hovering over labels and controls
		elseif widShared.pointInViewport(self, 2, mx, my) then
			self:setCursorLow()

			mx = mx + self.scr_x
			my = my + self.scr_y

			local menu = self.menu

			-- Update item hover
			local i, item = self:getItemAtPoint(mx, my, math.max(1, self.MN_items_first), math.min(#menu.items, self.MN_items_last))

			if item and item.selectable then
				-- Un-hover any existing hovered item
				self.MN_item_hover = item

				hover_ok = true
			end

		else
			-- Clear the sash cursor
			self:setCursorLow()
		end

		if self.MN_item_hover and not hover_ok then
			self.MN_item_hover = false
		end
	end
end


function def:uiCall_pointerHoverOff(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		commonScroll.widgetClearHover(self)
		self:setCursorLow()
		self.MN_item_hover = false
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

		if not lgcMenu.pointerPressScrollBars(self, x, y, button) then
			local mx, my = self:getRelativePosition(x, y)

			if widShared.pointInViewport(self, 2, mx, my) then
				mx, my = mx + self.scr_x, my + self.scr_y

				local item_i, item_t = lgcMenu.checkItemIntersect(self, mx, my, button)

				if item_t and item_t.selectable then
					local old_index = self.menu.index
					local old_item = self.menu.items[old_index]

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
		return lgcMenu.dragDropReleaseLogic(self)
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
	if self.MN_mouse_clicked_item and self.context.cseq_widget ~= self then
		self.MN_mouse_clicked_item = false
	end

	-- Handle update-time drag-scroll.
	if self.MN_drag_scroll
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

			-- PropertiesBox body
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
			local item_hover = self.MN_item_hover
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

			local first = math.max(self.MN_items_first, 1)
			local last = math.min(self.MN_items_last, #items)

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

			love.graphics.push("all")

			-- (WIP) Label area
			love.graphics.setColor(0.5, 0.1, 0.1, 0.5)
			love.graphics.rectangle("fill", self.vp3_x, self.vp3_y, self.vp3_w, self.vp3_h)

			-- (WIP) Control area
			love.graphics.setColor(0.1, 0.1, 0.5, 0.5)
			love.graphics.rectangle("fill", self.vp4_x, self.vp4_y, self.vp4_w, self.vp4_h)

			-- (WIP) Sash
			love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
			love.graphics.rectangle("fill", self.vp5_x, self.vp5_y, self.vp5_w, self.vp5_h)

			love.graphics.pop()

			--widDebug.debugDrawViewport(self, 1)
			--widDebug.debugDrawViewport(self, 2)
		end,

		--renderLast = function(self, ox, oy) end,
		--renderThimble = function(self, ox, oy) end,
	},
}


return def
