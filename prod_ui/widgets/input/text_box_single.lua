--[[

A single-line text input box.

         Viewport #1
  ╔═════════════════════════╗
  ║                         ║

┌─────────────────────────────┐
│ The quick brown fox jumps   │
└─────────────────────────────┘

--]]


local context = select(1, ...)


-- LÖVE Supplemental
local utf8 = require("utf8") -- (Lua 5.3+)

local commonMenu = require(context.conf.prod_ui_req .. "logic.common_menu")
local commonWimp = require(context.conf.prod_ui_req .. "logic.common_wimp")
local editBindS = context:getLua("shared/line_ed/s/edit_bind_s")
local editHistS = context:getLua("shared/line_ed/s/edit_hist_s")
local editMethodsS = context:getLua("shared/line_ed/s/edit_methods_s")
local keyCombo = require(context.conf.prod_ui_req .. "lib.key_combo")
local keyMgr = require(context.conf.prod_ui_req .. "lib.key_mgr")
local lgcInputS = context:getLua("shared/lgc_input_s")
local lineEdS = context:getLua("shared/line_ed/s/line_ed_s")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


local def = {
	skin_id = "text_box_s1",
}


-- Override to make something happen when the user presses 'return' or 'kpenter' while the
-- widget is active and has keyboard focus.
def.wid_action = uiShared.dummyFunc -- args: (self)


widShared.scrollSetMethods(def)
-- No integrated scroll bars for single-line text boxes.


lgcInputS.setupDef(def)


def.scrollGetCaretInBounds = lgcInputS.method_scrollGetCaretInBounds
def.updateDocumentDimensions = lgcInputS.method_updateDocumentDimensions
def.updateAlignOffset = lgcInputS.method_updateAlignOffset
def.pop_up_def = lgcInputS.pop_up_def


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		widShared.setupViewport(self, 1)
		widShared.setupViewport(self, 2)

		widShared.setupScroll(self)
		widShared.setupDoc(self)

		self.press_busy = false

		lgcInputS.setupInstance(self)

		-- State flags.
		self.enabled = true
		self.hovered = false
		self.pressed = false

		self:skinSetRefs()
		self:skinInstall()

		local skin = self.skin

		self.line_ed = lineEdS.new(skin.font)

		self:reshape()
	end
end


function def:uiCall_reshape()
	-- Viewport #1 is for text placement and offsetting.
	-- Viewport #2 is the text scissor-box boundary.

	widShared.resetViewport(self, 1)
	widShared.carveViewport(self, 1, "border")
	widShared.copyViewport(self, 1, 2)
	widShared.carveViewport(self, 1, "margin")

	self:scrollClampViewport()

	self.update_flag = true
end


function def:uiCall_pointerHoverOn(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		if self.enabled then
			self.hovered = true
			self:setCursorLow(self.skin.cursor_on)
		end
	end
end


function def:uiCall_pointerHoverOff(inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		if self.enabled then
			self.hovered = false
			self:setCursorLow()
		end
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

		local mx, my = self:getRelativePosition(x, y)

		if widShared.pointInViewport(self, 2, mx, my) then
			-- Propagation is halted when a context menu is created.
			if lgcInputS.mousePressLogic(self, button, mx, my) then
				return true
			end
		end
	end

	-- Allow propagation so that the root widget can destroy pop-up menus.
end


function def:uiCall_pointerUnpress(inst, x, y, button, istouch, presses)
	if self == inst then
		if button == 1 and button == self.context.mouse_pressed_button then
			self.press_busy = false
		end
	end
end


function def:uiCall_pointerDrag(inst, x, y, dx, dy) -- XXX: can't remember if this is necessary, or just the stub of an old function.
	return true
end


function def:uiCall_thimbleTake(inst)
	if self == inst then
		love.keyboard.setTextInput(true)
	end
end


function def:uiCall_thimbleRelease(inst)
	if self == inst then
		love.keyboard.setTextInput(false)
	end
end


function def:uiCall_thimbleAction(inst, key, scancode, isrepeat)
	if self == inst then
		if self.enabled then
			self:wid_action()
		end
	end
end


function def:uiCall_textInput(inst, text)
	if self == inst then
		lgcInputS.textInputLogic(self, text)
	end
end



function def:uiCall_keyPressed(inst, key, scancode, isrepeat)
	if self == inst then
		return lgcInputS.keyPressLogic(self, key, scancode, isrepeat)
	end
end


function def:uiCall_update(dt)
	local line_ed = self.line_ed
	local scr_x_old = self.scr_x

	-- Handle update-time drag-scroll.
	if self.press_busy == "text-drag" then
		-- Need to continuously update the selection.
		local needs_update, mouse_drag_x = lgcInputS.mouseDragLogic(self)
		if needs_update then
			self.update_flag = true
		end
		if mouse_drag_x ~= 0 then
			self:scrollDeltaH(mouse_drag_x * dt * 4) -- XXX style/config
			self.update_flag = true
		end
	end

	line_ed:updateCaretBlink(dt)

	self:scrollUpdate(dt)

	-- Force a cache update if the external scroll position is different.
	if scr_x_old ~= self.scr_x then
		self.update_flag = true
	end

	if self.update_flag then
		lgcInputS.updateCaretShape(self)
		self.update_flag = false
	end
end


function def:uiCall_destroy(inst)
	if self == inst then
		commonWimp.checkDestroyPopUp(self)
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
			local res = uiTheme.pickButtonResource(self, skin)
			local line_ed = self.line_ed

			love.graphics.push("all")

			-- Body.
			local slc_body = res.slice
			love.graphics.setColor(res.color_body)
			uiGraphics.drawSlice(slc_body, 0, 0, self.w, self.h)

			uiGraphics.intersectScissor(
				ox + self.x + self.vp2_x,
				oy + self.y + self.vp2_y,
				self.vp2_w,
				self.vp2_h
			)

			-- Text editor component.
			lgcInputS.draw(
				self,
				res.color_highlight,
				skin.font_ghost,
				res.color_text,
				line_ed.font,
				skin.color_insert -- XXX: color_replace
			)

			love.graphics.pop()

			-- Debug renderer.
			-- [[
			love.graphics.print(
				"line: " .. line_ed.line
				.. "\n#line: " .. #line_ed.line
				.. "\ncar_byte: " .. line_ed.car_byte
				.. "\nh_byte: " .. line_ed.h_byte
				.. "\ncaret_is_showing: " .. tostring(line_ed.caret_is_showing)
				.. "\ncaret_blink_time: " .. tostring(line_ed.caret_blink_time)
				.. "\ncaret box: " .. line_ed.caret_box_x .. ", " .. line_ed.caret_box_y .. ", " .. line_ed.caret_box_w .. ", " .. line_ed.caret_box_h
				,
				0, 64
			)

			local yy, hh = 240, line_ed.font:getHeight()
			love.graphics.print("History state:", 0, 216)

			for i, entry in ipairs(line_ed.hist.ledger) do
				love.graphics.print(i .. " c: " .. entry.car_byte .. " h: " .. entry.h_byte .. "line: " .. entry.line, 0, yy)
				yy = yy + hh
			end
			--]]
		end,
	},
}


return def
