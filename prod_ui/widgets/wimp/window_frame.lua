
--[[

wimp/window_frame: A WIMP-style window frame.

........................  <─ Resize area
.┌────────────────────┐.
.│       Window [o][x]│.  <─ Window frame header, drag sensor and control buttons
.├────────────────────┤.
.│File Edit View Help │.  <─ Optional menu bar
.├────────────────────┤.
.│┌─────────────────┐^│.  <─ Content container, with optional scroll bars
.││                 │║│.
.││                 │║│.
.││                 │║│.
.││                 │║│.
.│└─────────────────┘v│.
.│<═════════════════> │.
.├────────────────────┤.
.│Condition: Green    │.  <─ Optional status bar ([XXX 13] TODO)
.└────────────────────┘.
........................

Your widgets go into the 'content' container widget. You can get a reference to this widget with:

```lua
local content = frame:findTag("frame_content")
if content then
	-- etc.
end
```

Frames support modal relationships: Frame A can be blocked until Frame B is dismissed. Compare with
root-modal frames, where only the one frame (and pop-ups) can be interacted with.

Frame-modals are harder to manage than root-modals, and should only be used when really necessary
(ie the user needs to open a prompt in one frame, while looking up information in another frame).
--]]


local context = select(1, ...)

local commonFrame = require(context.conf.prod_ui_req .. "common.common_frame")
local commonMath = require(context.conf.prod_ui_req .. "common.common_math")
local commonScroll = require(context.conf.prod_ui_req .. "common.common_scroll")
local commonWimp = require(context.conf.prod_ui_req .. "common.common_wimp")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiLayout = require(context.conf.prod_ui_req .. "ui_layout")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widShared = require(context.conf.prod_ui_req .. "common.wid_shared")


local _lerp = commonMath.lerp


local function dummy_renderThimble() end


local def = {
	skin_id = "wimp_frame",

	default_settings = {
		frame_render_shadow = false,
		header_button_side = "right", -- "left", "right"
		header_enable_close_button = true,
		header_enable_size_button = true,
		header_show_close_button = true,
		header_show_size_button = true,
		header_text = "",
		header_condensed = false,
	}
}


def.trickle = {}


local function button_wid_maximize(self)
	local frame = self:findAncestorByField("is_frame", true)

	if frame then
		if frame.wid_maximize and frame.wid_unmaximize then
			if not frame.maximized then
				frame:wid_maximize()
			else
				frame:wid_unmaximize()
			end

			frame:reshape(true)
		end
	end
end


local function button_wid_close(self)
	self:bubbleEvent("frameCall_close", self)
end


-- We need to catch mouse hover+press events that occur in the frame's resize area.
function def:ui_evaluateHover(mx, my, os_x, os_y)
	local wx, wy = self.x + os_x, self.y + os_y
	local rp = self.maximized and 0 or self.skin.sensor_resize_pad
	return mx >= wx - rp and my >= wy - rp and mx < wx + self.w + rp and my < wy + self.h + rp
end


function def:ui_evaluatePress(mx, my, os_x, os_y, button, istouch, presses)
	local wx, wy, ww, wh = self.x + os_x, self.y + os_y, self.w, self.h
	local rp = self.maximized and 0 or self.skin.sensor_resize_pad
	-- in frame + padding area
	if mx >= wx - rp and my >= wy - rp and mx < wx + ww + rp and my < wy + wh + rp then
		-- just in frame
		if mx >= wx and my >= wy and mx < wx + ww and my < wy + wh then
			return true
		-- just in padding area: allow clicking through the resize sensor with mouse buttons
		-- 2, 3, etc.
		else
			return button == 1
		end
	end
end


function def:setCondensedHeader(enabled)
	if self.header_condensed ~= enabled then
		self.header_condensed = enabled
		self:reshape(true)
	end
end


local function getCursorCode(a_x, a_y)
	return (a_y == 0 and a_x ~= 0) and "sizewe" -- -
	or (a_y ~= 0 and a_x == 0) and "sizens" -- |
	or ((a_y == 1 and a_x == 1) or (a_y == -1 and a_x == -1)) and "sizenwse" -- \
	or ((a_y == -1 and a_x == 1) or (a_y == 1 and a_x == -1)) and "sizenesw" -- /
	or false -- unknown

	-- [XXX 16] on Fedora 36/37 + GNOME, a different cursor design is used for diagonal resize
	-- which has four orientations (up-left, up-right, down-left, down-right) instead
	-- of just two. It looks a bit incorrect when resizing a window from the bottom-left
	-- or bottom-right corners.
end


function def:initiateResizeMode(axis_x, axis_y)
	if axis_x == 0 and axis_y == 0 then
		error("invalid resize mode (0, 0).")
	end

	self.press_busy = "resize"
	self.adjust_axis_x = axis_x
	self.adjust_axis_y = axis_y

	local ax, ay = self:getAbsolutePosition()
	local mx, my = self.context.mouse_x, self.context.mouse_y

	-- Track mouse offsets for a less jarring transition to resize mode.
	self.adjust_ox = axis_x < 0 and ax - mx or axis_x > 0 and ax + self.w - mx or 0
	self.adjust_oy = axis_y < 0 and ay - my or axis_y > 0 and ay + self.h - my or 0

	--print("adjust_ox", self.adjust_ox, "adjust_oy", self.adjust_oy)
end


function def:setDefaultBounds()
	-- Allow container to be moved partially out of bounds, but not
	-- so much that the mouse wouldn't be able to drag it back.

	local header_h = self.vp3_h

	-- XXX: theme/scale
	self.p_bounds_x1 = -48
	self.p_bounds_x2 = -48
	self.p_bounds_y1 = -self.h + math.max(4, math.floor(header_h/4))
	self.p_bounds_y2 = -48
end


function def:setFrameTitle(text)
	uiShared.type1(1, text, "string", "nil")

	self:writeSetting("header_text", text)
end


function def:getFrameTitle()
	return self.header_text
end


--- Controls what happens when the container has both scroll bars active and the user clicks
-- on the square patch where the bars meet.
local function frame_wid_patchPressed(self, x, y, button, istouch, presses)
	-- XXX doesn't set the resize cursor. Maybe the core resize action would be better handled by a
	-- separate resize sensor.

	if button == 1 then
		local content = self:findTag("frame_content")
		if not content then
			return
		end

		if content.press_busy then
			return
		end

		local ax, ay = content:getAbsolutePosition()
		local mx, my = x - ax, y - ay

		print(mx, my)

		-- [XXX 14] support scroll bars on left or top side of container
		if content.scr_h and content.scr_h.active and content.scr_v and content.scr_v.active
		and mx >= content.vp_x + content.vp_w and my >= content.vp_y + content.vp_h then
			self:initiateResizeMode(1, 1)
		end
	end
end


local function _configureButton(button, visible, hover)
	if not visible then
		button.visible = false
		button.allow_hover = false
	else
		button.visible = not not visible
		button.allow_hover = not not hover
	end

	-- Reshape the frame after calling.
end


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = false
		--self.clip_hover = false
		--self.clip_scissor = false
		self.sort_id = 3

		-- Differentiates between 2nd-gen frame containers and other stuff at the same hierarchical level.
		self.is_frame = true

		self.mouse_in_resize_zone = false

		-- Helps to distinguish double-clicks on the frame header.
		self.cseq_header = false

		-- Set true to draw a red box around the frame's resize area.
		--self.DEBUG_show_resize_range

		-- Link to the last widget within this tree which held thimble1.
		-- The link may become stale, so confirm the widget is still alive and within the tree before using.
		self.banked_thimble1 = false

		self.press_busy = false -- false, "drag", "resize", "button-close", "button-size"

		-- Valid while resizing. (0,0) is an error.
		self.adjust_axis_x = 0 -- -1, 0, 1
		self.adjust_axis_y = 0 -- -1, 0, 1

		-- Offsets from mouse when resizing.
		self.adjust_ox = 0
		self.adjust_oy = 0

		-- How far past the parent bounds this widget is permitted to go.
		self.p_bounds_x1 = 0
		self.p_bounds_y1 = 0
		self.p_bounds_x2 = 0
		self.p_bounds_y2 = 0

		widShared.setupViewports(self, 4)

		-- Layout rectangle
		self.lp_x = 0
		self.lp_y = 0
		self.lp_w = 1
		self.lp_h = 1

		-- Used when unmaximizing as a result of dragging.
		self.adjust_mouse_orig_a_x = 0
		self.adjust_mouse_orig_a_y = 0

		self.maximized = false
		self.maxim_x = 0
		self.maxim_y = 0
		self.maxim_w = 128
		self.maxim_h = 128

		-- Set true to allow dragging the container by clicking on its body
		self.allow_body_drag = false -- XXX moved from container, maybe not the correct place here.

		-- Used to position frame relative to pointer when dragging.
		self.drag_ox = 0
		self.drag_oy = 0

		-- Minimum container size
		self.min_w = 64
		self.min_h = 64

		-- Maximum container size
		self.max_w = 2^16
		self.max_h = 2^16

		self:skinSetRefs()
		self:skinInstall()
		self:applyAllSettings()

		-- Potentially shortened version of 'text' for display.
		self.header_text_disp = ""

		-- Text offsetting
		self.header_text_ox = 0
		self.header_text_oy = 0


		-- Close button
		local b_close = self:addChild("base/button", {skin_id = "wimp_frame_button"})
		b_close.graphic = self.context.resources.tex_quads["window_graphic_close"]
		b_close.tag = "header_close"
		b_close.wid_buttonAction = button_wid_close
		b_close.can_have_thimble = false
		_configureButton(b_close, self.header_show_close_button, self.header_enable_close_button)

		-- Maximize/restore button
		local b_size = self:addChild("base/button", {skin_id = "wimp_frame_button"})
		b_size.graphic = self.context.resources.tex_quads["window_graphic_maximize"]
		b_size.graphic_max = self.context.resources.tex_quads["window_graphic_maximize"]
		b_size.graphic_unmax = self.context.resources.tex_quads["window_graphic_unmaximize"]
		b_size.tag = "header_max"
		b_size.wid_buttonAction = button_wid_maximize
		b_size.can_have_thimble = false
		_configureButton(b_size, self.header_show_size_button, self.header_enable_size_button)


		self.needs_update = true

		-- Layout rectangle
		uiLayout.initLayoutRectangle(self)

		-- Don't let inter-generational thimble stepping leave this widget's children.
		self.block_step_intergen = true

		-- Optional menu bar
		if self.make_menu_bar then
			local menu_bar = self:addChild("wimp/menu_bar")
			menu_bar.tag = "frame_menu_bar"
		end

		-- Main content container
		local content = self:addChild("base/container")
		content.tag = "frame_content"
		--content.render = content.renderBlank

		content:setScrollBars(true, true)

		content:reshape()

		content.can_have_thimble = true

		--self:setDefaultBounds()

		self.center = widShared.centerInParent

		self.wid_maximize = widShared.wid_maximize
		self.wid_unmaximize = widShared.wid_unmaximize
		--self.wid_patchPressed = frame_wid_patchPressed

		-- Helps with ctrl+tabbing through frames.
		self.order_id = self:bubbleEvent("rootCall_getFrameOrderID")

		-- Frame-modal widget links. Truthy-checks are used to determine if a frame is currently
		-- being blocked or is blocking another frame.
		self.ref_modal_prev = false
		self.ref_modal_next = false

		-- Table of widgets to offer keyPressed and keyReleased input.
		self.hooks_trickle_key_pressed = {}
		self.hooks_trickle_key_released = {}
		self.hooks_key_pressed = {}
		self.hooks_key_released = {}

		-- Call reshape(true) on this once you've set the initial size.
	end
end


function def:_trySettingThimble1()
	-- Check modal state before calling.

	local wid_banked = self.banked_thimble1

	if wid_banked and wid_banked.can_have_thimble and wid_banked:hasThisAncestor(self) then
		wid_banked:takeThimble1()
	else
		local content = self:findTag("frame_content")
		if content and content.can_have_thimble then
			content:takeThimble1()
		end
	end
end


function def:setModal(target)
	-- You can chain modal frames together, but only one frame may be modal to another frame at a time.
	if target.ref_modal_next then
		error("target frame already has a modal reference set (target.ref_modal_next).")

	elseif self.ref_modal_prev then
		error("this frame already has a modal reference set (self.ref_modal_prev).")
	end

	self.ref_modal_prev = target
	target.ref_modal_next = self
end


function def:clearModal()
	-- Frame-modal state must be popped last-to-first.
	if self.ref_modal_next then
		error("this frame still has a modal reference (self.ref_modal_next).")

	elseif not self.ref_modal_prev then
		error("no modal target frame to clear (self.ref_modal_prev).")
	end

	local target = self.ref_modal_prev
	self.ref_modal_prev = false
	target.ref_modal_next = false

	return target
end


function def:frameCall_close(inst)
	self:remove() -- XXX fortify against calls during update-lock

	-- Stop bubbling
	return true
end


function def.trickle:uiCall_pointerHoverOn(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self.ref_modal_next then
		self.context.current_hover = false
		return true
	end
end


function def:uiCall_pointerHover(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		local mx, my = self:getRelativePosition(mouse_x, mouse_y)
		local axis_x = mx < self.vp_x and -1 or mx >= self.vp_x + self.vp_w and 1 or 0
		local axis_y = my < self.vp_y and -1 or my >= self.vp_y + self.vp_h and 1 or 0
		if not self.maximized and not (axis_x == 0 and axis_y == 0) then
			self.mouse_in_resize_zone = true
			local cursor_id = getCursorCode(axis_x, axis_y)
			self:setCursorLow(cursor_id)
		else
			if self.mouse_in_resize_zone then
				self.mouse_in_resize_zone = false
				self:setCursorLow()
			end
		end
	end
end


function def:uiCall_pointerHoverOff(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		self.mouse_in_resize_zone = false
		self:setCursorLow()
	end
end


function def:uiCall_thimble1Take(inst)
	--print("thimbleTake", self.id, inst.id)
	self.banked_thimble1 = inst
end


function def:refreshSelected(is_selected)
	local header = self:findTag("frame_header")
	if header then
		header.selected = not not is_selected
	end
end


function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	-- Frame-modal check
	if self.ref_modal_next then
		return
	end

	if widShared.evaluateKeyhooks(self, self.hooks_key_pressed, key, scancode, isrepeat) then
		return true
	end
end


function def.trickle:uiCall_keyPressed(inst, key, scancode, isrepeat)
	if widShared.evaluateKeyhooks(self, self.hooks_trickle_key_pressed, key, scancode, isrepeat) then
		return true
	end
end


function def:uiCall_keyReleased(inst, key, scancode)
	-- Frame-modal check
	if self.ref_modal_next then
		return
	end

	if widShared.evaluateKeyhooks(self, self.hooks_key_released, key, scancode) then
		return true
	end
end


function def.trickle:uiCall_keyReleased(inst, key, scancode)
	if widShared.evaluateKeyhooks(self, self.hooks_key_released, key, scancode) then
		return true
	end
end


function def:uiCall_textInput(inst, text)
	-- Frame-modal check
	if self.ref_modal_next then
		return
	end
end


function def:bringToFront()
	self:reorder("last")
	self.parent:sortChildren()
end


function def.trickle:uiCall_pointerPress(inst, x, y, button, istouch, presses)
	if self.ref_modal_next then
		self.context.current_pressed = false
		return true
	end
end


function def:uiCall_pointerPress(inst, x, y, button, istouch, presses)
	-- Press events that create a pop-up menu should block propagation (return truthy)
	-- so that this and the WIMP root do not cause interference.

	local root = self:getTopWidgetInstance()

	-- Frame-modal check
	local modal_next = self.ref_modal_next
	if modal_next then
		root:setSelectedFrame(modal_next, true)
		return
	end

	root:setSelectedFrame(self, true)
	self.order_id = root:sendEvent("rootCall_getFrameOrderID")

	-- If thimble1 is not in this widget tree, move it to the container.
	local thimble1 = self.context.thimble1
	if not thimble1 or not thimble1:hasThisAncestor(self) then
		self:_trySettingThimble1()
	end

	local header_action = false
	if self == inst then
		local mx, my = self:getRelativePosition(x, y)

		if button == 1 and self.context.mouse_pressed_button == button then
			if not widShared.pointInViewport(self, 3, mx, my) then
				self.cseq_header = false
			else
				header_action = true

				if self.context.cseq_presses == 1 then
					self.cseq_header = true
				end
				-- Maximize
				if self.context.cseq_button == 1 and self.context.cseq_presses % 2 == 0 then
					if self.wid_maximize and self.wid_unmaximize then
						if not self.maximized then
							self:wid_maximize()
						else
							self:wid_unmaximize()
						end

						self:reshape(true)
					end
				else
					-- Drag (reposition) action
					self.press_busy = "drag"

					self.drag_ox, self.drag_oy = -mx, -my

					self.adjust_mouse_orig_a_x = x
					self.adjust_mouse_orig_a_y = y

					self.drag_dc_fix_x = x
					self.drag_dc_fix_y = y
				end
			end
		end

		if not header_action then
			-- If we did not interact with the header, and the mouse pointer is outside of viewport #1, then this
			-- is a resize action.
			if not (mx >= self.vp_x and my >= self.vp_y and mx < self.vp_x + self.vp_w and my < self.vp_y + self.vp_h) then
				local axis_x = mx < self.vp_x and -1 or mx >= self.vp_x + self.vp_w and 1 or 0
				local axis_y = my < self.vp_y and -1 or my >= self.vp_y + self.vp_h and 1 or 0
				if not (axis_x == 0 and axis_y == 0) then
					self:initiateResizeMode(axis_x, axis_y)
				end
			end
		end
	end

	-- XXX: These should be initiated with callbacks from the content container.
	--[=[
	-- Callback for when the user clicks on the scroll dead-patch.
	if self.wid_patchPressed and self:wid_patchPressed(x, y, button, istouch, presses) then
		-- ...

	-- Dragging can also be started by clicking on the container body if 'allow_body_drag' is truthy.
	elseif self.allow_body_drag then
		self.press_busy = "drag"
		self.adjust_mouse_orig_a_x = x
		self.adjust_mouse_orig_a_y = y
		--self:captureFocus()
	end
	--]=]
end


function def:uiCall_pointerDrag(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		if self.press_busy == "resize" then
			commonFrame.mouseMovedResize(self, self.adjust_axis_x, self.adjust_axis_y, mouse_x, mouse_y, mouse_dx, mouse_dy)

		elseif self.press_busy == "drag" then
			commonFrame.mouseMovedDrag(self, mouse_x, mouse_y, mouse_dx, mouse_dy)
		end
	end
end


function def:uiCall_pointerUnpress(inst, x, y, button, istouch, presses)
	if self == inst then
		if self.press_busy == "resize" or self.press_busy == "drag" then
			return commonFrame.mouseReleased(self, x, y, button, istouch, presses)
		end
	end
end


function def:uiCall_update(dt)
	if self.needs_update then
		local skin = self.skin
		local res = self.header_condensed and skin.res_cond or skin.res_norm
		local font = res.header_font

		-- Refresh the text string. Shorten to the first line feed, if applicable.
		self.header_text_disp = self.header_text and string.match(self.header_text, "^([^\n]*)\n*") or ""

		-- align text
		-- [XXX 12] Centered text can be cut off by the control buttons.
		local text_w = font:getWidth(self.header_text_disp)
		local text_h = font:getHeight()

		self.header_text_ox = math.floor(0.5 + _lerp(self.vp3_x, self.vp3_x + self.vp3_w - text_w, skin.header_text_align_h))
		if self.header_text_ox + text_w > self.vp3_w then
			self.header_text_ox = self.vp4_w - text_w
		end
		self.header_text_ox = math.max(0, self.header_text_ox)
		self.header_text_oy = math.floor(0.5 + _lerp(self.vp3_y, self.vp3_y + self.vp3_h - text_h, skin.header_text_align_v))

		self.needs_update = false
	end
end


local function _measureButtonShortenPort(self, skin, res, right, w, h)
	local bx, by, bw, bh
	by = math.floor(0.5 + _lerp(self.vp4_y, self.vp4_y + self.vp4_h - h, res.button_align_v))
	bw = w
	bh = h

	if right then
		bx = self.vp4_x + self.vp4_w - w
	else -- left
		bx = self.vp4_x
		self.vp4_x = self.vp4_x + w + res.button_pad_w
	end
	self.vp4_w = math.max(0, self.vp4_w - w - res.button_pad_w)

	return bx, by, bw, bh
end


function def:uiCall_reshape()
	-- self.w, self.h, excluding viewport #1, is the outer frame border. This area is considered an inward extension
	-- of the invisible resize zone surrounding the frame.
	-- Viewport #1, excluding #2, is the inner frame border. This area does nothing when clicked.
	-- Viewport #2 is the area for all other elements.
	-- Viewport #3 is the header area.
	-- Viewport #4 is a subsection of the header area for rendering the frame title.

	local skin = self.skin
	local res = self.header_condensed and skin.res_cond or skin.res_norm
	local res2 = self.selected and res.res_selected or res.res_unselected

	-- (parent should be the WIMP root widget.)
	local parent = self.parent
	local wimp_res = self.context.resources.wimp

	-- Refit if maximized and parent dimensions changed.
	if self.maximized then
		self.x = parent.vp2_x
		self.y = parent.vp2_y
		if self.w ~= parent.vp2_w or self.h ~= parent.vp2_h then
			self.w = parent.vp2_w
			self.h = parent.vp2_h
		end
	end

	widShared.enforceLimitedDimensions(self)

	widShared.resetViewport(self, 1)
	widShared.carveViewport(self, 1, skin.box.border)
	widShared.copyViewport(self, 1, 2)
	widShared.carveViewport(self, 2, skin.box.margin)

	-- Header setup
	self.vp3_h = res.header_h
	local vx, vy, vw, vh = widShared.getViewportXYWH(self, res.viewport_fit)
	self.vp3_x, self.vp3_y, self.vp3_w = vx, vy, vw

	widShared.copyViewport(self, 3, 4)

	local button_h = math.min(res.button_h, self.vp3_h)
	local right = self.header_button_side == "right"

	-- The first bit of padding for buttons
	if self.header_show_close_button or self.header_show_size_button then
		self.vp4_w = self.vp4_w - res.button_pad_w
		if not right then
			self.vp4_x = self.vp4_x + res.button_pad_w
		end
	end

	local b_close = self:findTag("header_close")
	if b_close and self.header_show_close_button then
		b_close.x, b_close.y, b_close.w, b_close.h = _measureButtonShortenPort(self, skin, res, right, res.button_w, button_h)
	end

	local b_size = self:findTag("header_max")
	if b_size and self.header_show_size_button then
		b_size.x, b_size.y, b_size.w, b_size.h = _measureButtonShortenPort(self, skin, res, right, res.button_w, button_h)
		b_size.graphic = self.maximized and b_size.graphic_unmax or b_size.graphic_max
	end

	self.needs_update = true

	-- The rest
	uiLayout.resetLayoutPortFull(self, 2)
	uiLayout.discardTop(self, self.vp3_y - self.vp2_y + self.vp3_h)

	local menu_bar = self:findTag("frame_menu_bar")
	local content = self:findTag("frame_content")

	if menu_bar then
		menu_bar:resize()
		uiLayout.fitTop(self, menu_bar)
	end

	if content then
		uiLayout.fitRemaining(self, content)
		content:updateContentClipScissor()
	end

	-- Needs to happen after shaping the header bar, as the header height factors into the default bounds.
	self:setDefaultBounds()

	-- Hacky way of not interfering with the user resizing the frame. Call keepInBounds* before exiting the resize mode.
	if self.press_busy ~= "resize" then
		widShared.keepInBoundsExtended(self, 2, self.p_bounds_x1, self.p_bounds_x2, self.p_bounds_y1, self.p_bounds_y2)
	end

	-- The rest should take care of themselves with their own reshape calls.
end


function def:uiCall_destroy(inst)
	if self == inst then
		-- Clean up any existing frame-modal connection. Note that this function will raise an error if another frame
		-- is still blocking this frame.
		if self.ref_modal_prev then
			local target = self:clearModal()

			-- Clean up the target's focus a bit.
			--[[
			local root = self:getTopWidgetInstance()
			root:setSelectedFrame(target, true)

			target:reorder("last")
			target.parent:sortChildren()

			target:_trySettingThimble1()
			--]]
		end

		-- Clean up root-level modal level, if applicable.
		local root = self:getTopWidgetInstance()
		if self == root.modals[#root.modals] then
			root:sendEvent("rootCall_clearModalFrame", self)
		end
	end
end


def.default_skinner = {
	schema = {
		header_text_align_h = "unit-interval",
		header_text_align_v = "unit-interval",
		sensor_resize_pad = "scaled-int",
		shadow_extrude = "scaled-int",

		res_norm = {
			header_h = "scaled-int",
			button_pad_w = "scaled-int",
			button_w = "scaled-int",
			button_h = "scaled-int",
			button_align_v = "unit-interval",
		},

		res_cond = {
			header_h = "scaled-int",
			button_pad_w = "scaled-int",
			button_w = "scaled-int",
			button_h = "scaled-int",
			button_align_v = "unit-interval",
		},
	},


	install = function(self, skinner, skin)
		uiTheme.skinnerCopyMethods(self, skinner)
	end,


	remove = function(self, skinner, skin)
		uiTheme.skinnerClearData(self)
	end,


	render = function(self, ox, oy)
		local skin = self.skin

		-- Window shadow
		if self.frame_render_shadow then
			love.graphics.setColor(skin.color_shadow)
			uiGraphics.drawSlice(skin.slc_shadow,
				-skin.shadow_extrude,
				-skin.shadow_extrude,
				self.w + skin.shadow_extrude * 2,
				self.h + skin.shadow_extrude * 2
			)
		end

		-- Window body
		love.graphics.setColor(skin.color_body)
		uiGraphics.drawSlice(skin.slc_body, 0, 0, self.w, self.h)

		-- Window header
		local res = self.header_condensed and skin.res_cond or skin.res_norm
		local res2 = self.selected and res.res_selected or res.res_unselected
		local slc_header_body = res.header_slc_body
		love.graphics.setColor(res2.col_header_fill)
		uiGraphics.drawSlice(slc_header_body, self.vp3_x, self.vp3_y, self.vp3_w, self.vp3_h)

		if self.header_text then
			local font = res.header_font

			love.graphics.setColor(res2.col_header_text)
			love.graphics.setFont(font)

			local sx, sy, sw, sh = love.graphics.getScissor()
			uiGraphics.intersectScissor(ox + self.x + self.vp2_x, oy + self.y + self.vp2_y, self.vp2_w, self.vp2_h)

			love.graphics.print(self.header_text_disp, self.header_text_ox, self.header_text_oy)

			love.graphics.setScissor(sx, sy, sw, sh)
		end

		-- Header buttons
		--[[
		if frame then
			button_max.graphic = frame.maximized and button_max.graphic_unmax or button_max.graphic_max
		else
			button_max.graphic = button_max.graphic_max
		end
		--]]

		if self.DEBUG_show_resize_range then
			local rp = skin.sensor_resize_pad
			love.graphics.push("all")

			love.graphics.setScissor()
			love.graphics.setColor(0.8, 0.1, 0.2, 0.8)

			love.graphics.setLineWidth(1)
			love.graphics.setLineJoin("miter")
			love.graphics.setLineStyle("rough")

			love.graphics.rectangle("line", 0.5 - rp, 0.5 - rp, self.w + rp*2 - 1, self.h + rp*2 - 1)

			love.graphics.pop()
		end
	end,
}


return def
