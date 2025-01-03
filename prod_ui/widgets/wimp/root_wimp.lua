-- WIMP UI root widget.


--local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local context = select(1, ...)

local notifMgr = require(context.conf.prod_ui_req .. "lib.notif_mgr")
local stepHandlers = require(context.conf.prod_ui_req .. "common.step_handlers")
local uiLayout = require(context.conf.prod_ui_req .. "ui_layout")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local widShared = require(context.conf.prod_ui_req .. "common.wid_shared")


local def = {}


function def:uiCall_create(inst)
	if self == inst then
		self.allow_hover = true
		self.can_have_thimble = false
		self.allow_focus_capture = false
		self.visible = true
		self.clip_hover = true

		--[[
		WIMP 2nd-gen sort_id lanes:
		1: Background elements
		2: Workspace panels
		3: Workspace frames, normal priority
		4: Workspace frames, always-on-top
		5: Application menu bar
		6: Pop-up menus
		--]]
		self.sort_max = 6

		-- Viewport #2 is used as the boundary for window-frame placement.
		widShared.setupViewports(self, 2)

		-- Widget layout sequence for children.
		uiLayout.initLayoutSequence(self)
		-- Assigns:
		--self.lp_seq (table)
		--self.lp_x
		--self.lp_y
		--self.lp_w
		--self.lp_h

		-- Used to implement 2nd-gen modal frames (blocking all other 2nd-gen widget click actions, except
		-- for things like pop-up menus).
		-- Widgets with a modal value less than this may not be accessible.
		self.modal_level = 0

		-- One 2nd-gen window frame can be selected at a time.
		self.selected_frame = false

		-- Helps with ctrl+tabbing through 2nd-gen frames.
		self.frame_order_counter = 0

		-- When true, include a "nothing" selection while ctrl+tabbing through frames.
		self.step_on_root = false

		-- Reference to the base of a pop-up menu, if active.
		self.pop_up_menu = false

		-- Used to save and restore the current thimble while some temporary pop-up menus are active.
		-- nil: bank is not active
		-- false: "nothing" is banked (so upon restoration, 'current_thimble' will become false)
		-- table: Widget reference.
		self.banked_thimble = nil

		-- ToolTip state.
		self.tool_tip = notifMgr.newToolTip(self.context.resources.fonts.p) -- XXX font ref needs to be refresh-able

		self.tool_tip_hover = false
		self.tool_tip_time = 0.0
		self.tool_tip_time_max = 0.2

		-- Drag-and-drop state.
		-- NOTE: this is unrelated to love.filedropped() and love.directorydropped().
		-- false/nil: Not active.
		-- table: a DropState object.
		self.drop_state = false

		-- Table of widgets to offer keyPressed and keyReleased input.
		self.hooks_key_pressed = {}
		self.hooks_key_released = {}

		self:reshape(true)
		-- You may need to call reshape(true) again after creating the initial 2nd-gen widgets to properly
		-- set up viewports.
	end
end


function def:uiCall_reshape()
	uiLayout.resetLayout(self)
	uiLayout.applyLayout(self)

	self.vp2_x = self.lp_x
	self.vp2_y = self.lp_y
	self.vp2_w = self.lp_w
	self.vp2_h = self.lp_h
end


--- Clears the current pop-up menu and runs a cleanup callback on the reference widget (wid_ref). Check that 'self.pop_up_menu' is valid before calling.
-- @param self The root widget.
-- @param reason_code A string to pass to the wid_ref indicating the context for clearing the menu.
local function clearPopUp(self, reason_code)
	-- check 'if self.pop_up_menu' before calling.

	-- If mouse was pressing on any part of the pop-up menu chain from the base onward, blank out current_pressed in
	-- the context table.
	-- We exclude `wid_ref` which may be part of the chain (to the left of the base pop-up) because it is not
	-- being destroyed by this function.
	if self.context.current_pressed and widShared.chainHasThisWidgetRight(self.pop_up_menu, self.context.current_pressed) then
		self.context.current_pressed = false
	end

	local wid_ref = self.pop_up_menu.wid_ref

	-- Remove nested pop-ups, then the base pop-up, then clear the root's reference to it.
	widShared.chainRemovePost(self.pop_up_menu)
	self.pop_up_menu:remove()
	self.pop_up_menu = false

	-- Some widgets need to perform additional cleanup when the menu disappears.
	if wid_ref.wid_popUpCleanup then
		wid_ref:wid_popUpCleanup(reason_code)
	end
end


function def:uiCall_pointerPress(inst, x, y, button, istouch, presses)
	-- User clicked on the root widget (whether directly or because other widgets aren't clickable).
	if self == inst then
		if button <= 3 then
			-- Clicking on "nothing" should release the thimble and deselect any frames.
			if self.context.current_thimble then
				self.context.current_thimble:releaseThimble()
			end

			self:setSelectedFrame(false)
		end

		-- If root-modal state is active, the top modal frame should get focus.
		if self.modal_level > 0 then
			-- Locate the top modal.
			local wid, top
			for i, child in ipairs(self.children) do
				if child.modal_level and child.modal_level > 0 and child.modal_level < math.huge then
					top = child.modal_level
					wid = child
				end
			end

			if wid and wid.is_frame then
				self:setSelectedFrame(wid, true)
			end
		end
	-- This is bubbling up from an instance.
	else
		-- Auto thimble assignment
		if inst.can_have_thimble == "auto" then
			if button <= 3 and self.context.mouse_pressed_button == button then
				inst:takeThimble()
				self.banked_thimble = nil
			end
		end
	end

	-- Destroy pop-up menu if clicking outside of its lateral chain.
	local cur_pres = self.context.current_pressed
	local pop_up = self.pop_up_menu

	if pop_up then
		--[[
		Breakdown for the following line:
		* There is no currently-pressed widget
		* Or: the currently-pressed widget is the tree root (self)
		* Or: the currently-pressed widget is not the pop-up menu, and the pop-up menu chain does not contain currently-pressed.
		--]]
		if not cur_pres or cur_pres == self or (pop_up ~= cur_pres and not widShared.chainHasThisWidget(pop_up, cur_pres)) then
			-- Hack to discard banked thimble when user clicked on another widget which has just taken the thimble.
			-- Also do so if we have clicked on nothing or the root widget.
			if cur_pres == self.context.current_thimble
			or not cur_pres or cur_pres == self
			then
				self.banked_thimble = nil
			end

			clearPopUp(self, "concluded")
			self.banked_thimble = nil
		end
	end
end


function def:uiCall_pointerDragDestRelease(inst, x, y, button, istouch, presses)
	-- DropState cleanup
	self.drop_state = false
end


function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	local context = self.context

	-- Check keyPressed hooks.
	if self.modal_level == 0 then
		if widShared.evaluateKeyhooks(self.hooks_key_pressed, key, scancode, isrepeat) then
			return true
		end
	end

	-- Run thimble logic.
	-- Block keyboard-driven thimble actions if the mouse is currently pressed.
	if not context.current_pressed then
		-- Keypress-driven step events.
		local wid_cur = context.current_thimble
		local mods = context.key_mgr.mod

		-- Tab through top-level frames.
		if scancode == "tab" and mods["ctrl"] then
			if mods["shift"] then
				self:stepSelectedFrame(1)
			else
				self:stepSelectedFrame(-1)
			end

		-- Try to close the current window frame.
		elseif self.selected_frame and scancode == "f4" and mods["ctrl"] then
			self.selected_frame:remove()

		else
			-- Thimble is held:
			if wid_cur then
				-- Cycle through widgets.
				if scancode == "tab" then
					local dest_cur
					if mods["shift"] then
						dest_cur = stepHandlers.intergenerationalPrevious(wid_cur)
					else
						dest_cur = stepHandlers.intergenerationalNext(wid_cur)
					end

					if dest_cur then
						dest_cur:takeThimble("widget_in_view")
					else
						wid_cur:releaseThimble()
					end

				-- Thimble action #1.
				elseif scancode == "return" or scancode == "kpenter" or (scancode == "space" and not isrepeat) then
					wid_cur:bubbleStatement("uiCall_thimbleAction", wid_cur, key, scancode, isrepeat)
					context.current_pressed = false

				-- Thimble action #2.
				elseif (scancode == "application" or (mods["shift"] and scancode == "f10")) and not isrepeat then
					wid_cur:bubbleStatement("uiCall_thimbleAction2", wid_cur, key, scancode, isrepeat)
					context.current_pressed = false
				end
			end
		end
	end

	return true
end


function def:uiCall_keyReleased(inst, key, scancode)
	-- Check keyReleased hooks.
	if self.modal_level == 0 then
		if widShared.evaluateKeyhooks(self.hooks_key_released, key, scancode) then
			return true
		end
	end
end


function def:uiCall_windowResize(w, h)
	-- XXX consider rate-limiting this (either here or in the core) to about 1/10th of a second.
	-- It fires over and over on Fedora, but pauses the main thread on Windows. Apparently, Wayland
	-- can fire it multiple times per frame.

	self.w, self.h = w, h

	-- Reshape self and descendants
	self:reshape(true)
end


local function refreshSelectedFrame(self)
	local selected = self.selected_frame

	for i, child in ipairs(self.children) do
		if child.is_frame then
			child:refreshSelected(child == selected)
		end
	end
end


function def:rootCall_getFrameOrderID()
	self.frame_order_counter = self.frame_order_counter + 1
	return self.frame_order_counter
end


-- @param set_new_order When true, assign a new top order_id to the frame. This may be desired when clicking on a frame, and not when ctrl+tabbing through them.
function def:setSelectedFrame(inst, set_new_order)
	if inst and not self:hasThisChild(inst) then
		error("instance is not a child of the root widget.")
	end

	local old_selected = self.selected_frame
	self.selected_frame = inst or false

	if inst then
		inst:bringToFront()
		if old_selected ~= inst then
			inst:_trySettingThimble()

			if set_new_order then
				inst.order_id = self:rootCall_getFrameOrderID()
			end
		end
	end

	refreshSelectedFrame(self)
end


local function frameSearch(self, dir, v1, v2)
	local candidate = false

	for i, child in ipairs(self.children) do
		if child.is_frame
		and child.modal_level >= self.modal_level
		and not child.ref_modal_next
		and child.order_id > v1 and child.order_id < v2
		then
			if dir == 1 then
				v2 = child.order_id
				candidate = child
			else
				v1 = child.order_id
				candidate = child
			end
		end
	end

	return candidate
end


-- Select the topmost window frame.
-- @param exclude Optionally provide one window frame to exclude from the search. Use this when the
-- current selected frame is in the process of being destroyed.
function def:selectTopWindowFrame(exclude)
	for i = #self.children, 1, -1 do
		local child = self.children[i]

		if child.is_frame
		and child.modal_level >= self.modal_level
		and not child.ref_modal_next
		and child ~= exclude
		then
			self:setSelectedFrame(child, false)
			return true
		end
	end

	self:setSelectedFrame(false)
	return false
end


-- @param dir 1 or -1.
-- @return true if the step was successful, false if no step happened.
function def:stepSelectedFrame(dir)
	if dir ~= 1 and dir ~= -1 then
		error("argument #1: invalid direction.")
	end

	--[[
	We need to keep the step-through order of frames separate from their position in the root's list of children.

	Traveling left-to-right: find the next-biggest order ID. If this is the biggest, search again for the smallest
	ID. Right-to-left is the opposite. Ignore widgets that are not frames, that are below the modal threshold, or
	which are being frame-modal blocked.
	--]]

	local current = self.selected_frame
	local candidate
	local v1, v2 = 0, math.huge
	if current then
		if dir == 1 then
			v1 = current.order_id
		else
			v2 = current.order_id
		end
	end

	local candidate = frameSearch(self, dir, v1, v2)

	-- Success
	if candidate then
		self:setSelectedFrame(candidate, false)
		return true

	-- We are at the first or last selectable frame.
	-- step_on_root: select "nothing"
	elseif self.step_on_root then
		self:setSelectedFrame(false)

	-- Not step_on_root: try one more time, from the first or last point.
	else
		v1, v2 = 0, math.huge
		candidate = frameSearch(self, dir, v1, v2)

		if candidate and candidate ~= current then
			self:setSelectedFrame(candidate, false)
			return true
		end
	end

	return false
end


--- Doctor the context 'current_pressed' field. Intended for use with pop-up menus in some special cases.
-- @param inst The invoking widget.
-- @param new_pressed The widget that will be assigned to 'current_pressed' if it meets the criteria.
-- @param press_busy_code If truthy, and we go through with the change, assign this value to 'new_pressed.press_busy'.
function def:rootCall_doctorCurrentPressed(inst, new_pressed, press_busy_code)
	--print("rootCall_doctorCurrentPressed", inst, new_pressed, press_busy_code, debug.traceback())

	-- If this was the result of a click action, doctor the current-pressed state
	-- to reference the menu, not the clicked widget.
	if self.context.current_pressed and new_pressed.allow_hover then
		--self.context.current_hover = new_pressed
		self.context.current_pressed = new_pressed

		if press_busy_code then
			new_pressed.press_busy = press_busy_code
		end
	end
end


--- Set a widget as the current pop-up, destroying any existing pop-up chain first.
-- @param inst The event invoker.
-- @param pop_up The widget to assign as a pop-up.
-- @return A reference to the new pop-up widget.
function def:rootCall_assignPopUp(inst, pop_up)
	--print("rootCall_assignPopUp", inst, pop_up, debug.traceback())

	-- Caller should create and initialize the widget before attaching it to the root here.

	-- Destroy any existing pop-up menu tree.
	if self.pop_up_menu then
		clearPopUp(self, "concluded")
	end

	-- If invoking widget is part of a window-frame, bring it to the front.
	local frame = inst:findAncestorByField("is_frame", true)
	if frame then
		self:setSelectedFrame(frame, true)
	end

	self.pop_up_menu = pop_up

	-- If the calling function is a uiCall_pointerPress event, it should return true to block further propagation
	-- up. Otherwise, the window-frame and root pointerPress code may interfere with thimble and banking state.
end


local function thimbleUnbank(self)
	if self.banked_thimble == false then
		self.context:clearThimble()

	elseif self.banked_thimble ~= nil then
		if not self.banked_thimble._dead then
			self.banked_thimble:tryTakeThimble()
		end
	end

	self.banked_thimble = nil
end


function def:rootCall_destroyPopUp(inst, reason_code)
	--print("rootCall_destroyPopUp", inst, reason_code, debug.traceback())

	if self.pop_up_menu then
		--print("rootCall_destroyPopUp", "reason_code", reason_code, "self.pop_up_menu.banked_thimble", self.pop_up_banked_thimble)

		clearPopUp(self, reason_code)
	end
end


--- Some non-pop-up widgets need to bank and restore the thimble, or set the initial banked state before invoking
--  a pop-up.
function def:rootCall_bankThimble(inst)
	--print("rootCall_bankThimble", inst, debug.traceback())

	self.banked_thimble = inst

	--print("self.banked_thimble", self.banked_thimble)
end


--- Bank the thimble, but only if the current bank is inactive.
function def:rootCall_tryBankThimble(inst)
	--print("rootCall_tryBankThimble", inst, debug.traceback())

	if self.banked_thimble == nil then
		self.banked_thimble = inst
		print("self.banked_thimble", self.banked_thimble)
	else
		print("(something is already banked.)")
	end
end


function def:rootCall_restoreThimble(inst)
	--print("rootCall_restoreThimble", inst, debug.traceback())
	-- Important: this won't do anything if you bubble the event from a widget that has already been removed (since
	-- its parent reference was wiped, the event goes nowhere). Call this before destroying the invoking widget.
	-- Alternatively, get a reference to the top widget instance before destroying and call it with runStatement().
	thimbleUnbank(self)
end


function def:rootCall_clearThimbleBank(inst)
	--print("rootCall_clearThimbleBank", inst, debug.traceback())
	self.banked_thimble = nil
end


--- Change allow_hover for all 2nd-gen widgets with a modal_level less than the current (or if modal_level is nil).
--  To opt widgets out of this, set their modal_level to math.huge.
-- @param self The root widget.
local function updateModalHoverState(self)
	for i, child in ipairs(self.children) do
		local modal_level = child.modal_level or 0

		if modal_level < self.modal_level then
			child.allow_hover = false

		else
			child.allow_hover = true
		end
	end
end


function def:rootCall_setModalFrame(inst)
	if inst.modal_level ~= 0 then
		-- Troubleshooting:
		-- * Ensure you are not double-assigning modal state to a frame.
		error("frame modal level must be zero upon assignment (got: " .. inst.modal_level .. ")")
	end

	self.modal_level = self.modal_level + 1
	inst.modal_level = self.modal_level

	updateModalHoverState(self)
end


function def:rootCall_clearModalFrame(inst)
	if inst.modal_level ~= self.modal_level then
		-- Troubleshooting:
		-- * Attempted to clear the modal state of a frame twice?
		-- * Clearing modal frames out of order?
		error("mismatch between modal level of frame and root (" .. inst.modal_level .. " vs " .. self.modal_level .. ")")
	end

	self.modal_level = self.modal_level - 1
	inst.modal_level = 0

	updateModalHoverState(self)
end


function def:rootCall_setDragAndDropState(inst, drop_state)
	uiShared.type(1, inst, "table")
	uiShared.type(2, drop_state, "table")

	self.drop_state = drop_state
end


local function resetToolTipState(self)
	self.tool_tip_hover = false
	self.tool_tip_time = 0.0
	self.tool_tip.visible = false
	self.tool_tip.alpha = 0.0
end


function def:uiCall_update(dt)
	local tool_tip = self.tool_tip
	local current_hover = self.context.current_hover

	-- Don't show tool-tips when:
	-- * Any pop-up menu is open
	-- * Mouse cursor is not hovering over anything
	-- * Current hover is not the same as the last-good hover
	-- * Any mouse button is held
	if self.pop_up_menu
	or not current_hover
	or current_hover ~= self.tool_tip_hover
	or self.context.mouse_pressed_button then
		resetToolTipState(self)
	end

	if current_hover then
		self.tool_tip_hover = current_hover
	end

	if not tool_tip.visible then
		local tip_hover = self.tool_tip_hover
		if tip_hover and tip_hover.str_tool_tip then
			self.tool_tip_time = self.tool_tip_time + dt
		end
		if self.tool_tip_time >= self.tool_tip_time_max then
			tool_tip:arrange(tip_hover.str_tool_tip, 0, 0)
			tool_tip.visible = true
		end
	else
		tool_tip.alpha = math.min(1, tool_tip.alpha + dt * tool_tip.alpha_dt_mul)
	end
end


function def:uiCall_destroy(inst)
	-- Bubbled events from children
	if self ~= inst then
		--[=[
		-- If the instance is the current pop-up widget, clean up root's link to it.
		if self.pop_up_menu and inst == self.pop_up_menu then
			-- On the fence about this.
			self.pop_up_menu = false
		end
		--]=]

		-- If the current selected window frame is being destroyed, then automatically select the next top frame.
		if inst.is_frame and self.selected_frame == inst then
			self:selectTopWindowFrame(inst)
		end
	end
end


function def:renderLast(os_x, os_y)
	if self.tool_tip.visible then
		local mx, my = self.context.mouse_x, self.context.mouse_y
		local xx, yy, ww, hh = self.x, self.y, self.w, self.h
		local tool_tip = self.tool_tip
		local tw, th = tool_tip.w, tool_tip.h
		local x = math.max(xx, math.min(mx + 16, ww - tw))
		local y = math.max(yy, math.min(my + 16, hh - th))
		self.tool_tip:draw(x, y)
	end

	if self.drop_state then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print("Dropping...", self.context.mouse_x - 20, self.context.mouse_y - 20)
	end

	-- DEBUG
	--[[
	love.graphics.setFont(self.context.resources.fonts.p)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("selected_frame: " .. tostring(self.selected_frame), 64, 64)
	--]]

	-- DEBUG: Draw click-sequence intersect.
	--[[
	local context = self.context
	if context.cseq_widget then
		love.graphics.setLineStyle("rough")
		love.graphics.setLineJoin("miter")
		love.graphics.setLineWidth(1)

		love.graphics.setColor(1, 0, 0, 1)
		local x, y, r = context.cseq_x, context.cseq_y, context.cseq_range
		love.graphics.rectangle("line", x - r, y - r, r * 2 - 1, r * 2 - 1)

		love.graphics.setColor(0, 1, 0, 1)
		local wid = context.cseq_widget
		local wx, wy = wid:getAbsolutePosition()
		love.graphics.rectangle("line", wx, wy, wid.w - 1, wid.h - 1)
	end
	--]]

	-- DEBUG: Draw mouse-press range (for drag-and-drop)
	--[[
	if context.mouse_pressed_button then
		love.graphics.setLineStyle("rough")
		love.graphics.setLineJoin("miter")
		love.graphics.setLineWidth(1)

		love.graphics.setColor(0, 0, 1, 1)
		local mpx, mpy, mpr = context.mouse_pressed_x, context.mouse_pressed_y, context.mouse_pressed_range
		love.graphics.rectangle("line", mpx - mpr, mpy - mpr, mpr * 2 - 1, mpr * 2 - 1)
	end
	--]]
end


return def
