
local plan = {}


local commonWimp = require("prod_ui.common.common_wimp")
local pTable = require("prod_ui.lib.pile_table")


function plan.make(parent)
	local context = parent.context

	-- Clone the skin to avoid messing up other frames.
	local resources = context.resources
	local skin_defs = resources.skin_defs

	local skin_clone = pTable.deepCopy(skin_defs["wimp_frame"])
	resources:registerSkinDef(skin_clone, skin_clone, false)

	local function _userDestroy(self)
		self.context.resources:removeSkinDef(skin_clone)
	end


	local frame = parent:addChild("wimp/window_frame", {skin_id = skin_clone, userDestroy = _userDestroy})
	local header = frame:findTag("frame_header")

	frame.w = 640
	frame.h = 480

	frame:setFrameTitle("WIMP Window Frame")

	local content = frame:findTag("frame_content")
	if content then
		content.layout_mode = "resize"
		content:setScrollBars(false, false)

		local xx, yy, ww, hh = 16, 16, 192, 32

		-- Checkbox: Condensed Header
		do
			local checkbox = content:addChild("base/checkbox", {x=xx, y=yy, w=ww, h=hh})
			checkbox.checked = false
			checkbox.bijou_side = "right"
			checkbox:setLabel("Condensed Header")

			checkbox.wid_buttonAction = function(self)
				local frame = commonWimp.getFrame(self)
				if frame then
					frame:setCondensedHeader(not not self.checked)
				end
			end
			yy = yy + hh
		end

		-- Checkbox: Show resize sensors
		do
			local checkbox = content:addChild("base/checkbox", {x=xx, y=yy, w=ww, h=hh})
			checkbox.checked = false
			checkbox.bijou_side = "right"
			checkbox:setLabel("S_h_ow resize sensors", "single-ul")

			checkbox.wid_buttonAction = function(self)
				local frame = commonWimp.getFrame(self)
				if frame then
					frame.DEBUG_show_resize_range = not not self.checked
				end
			end
			checkbox:reshape()

			yy = yy + hh
		end

		-- Radio Buttons: Control placement
		do
			yy = yy + hh
			local text1 = content:addChild("base/text", {
				x=xx, y=yy, w=ww, h=hh,
				font = context.resources.fonts.p
			})
			text1.text = "Control Placement"
			text1.x = text1.x + 9 -- XXX work on syncing padding with embedded widget labels
			text1:refreshText()
			yy = yy + hh

			local r_action = function(self)
				local frame = commonWimp.getFrame(self)
				if frame then
					frame:writeSetting("header_button_side", self.usr_button_side)
					frame:reshape(true)
				end
			end

			-- Left side
			do
				local rad_btn = content:addChild("base/radio_button", {x=xx, y=yy, w=ww, h=hh})
				rad_btn.bijou_side = "right"
				rad_btn.radio_group = "rg_control_side"
				rad_btn:setLabel("Left")
				rad_btn.usr_button_side = "left"
				rad_btn.wid_buttonAction = r_action

				-- initial state
				if header and header.skin.button_side == rad_btn.usr_button_side then
					rad_btn:setChecked(true)
				end
				yy = yy + hh
			end

			-- Right side
			do
				local rad_btn = content:addChild("base/radio_button", {x=xx, y=yy, w=ww, h=hh})
				rad_btn.bijou_side = "right"
				rad_btn.radio_group = "rg_control_side"
				rad_btn:setLabel("Right")
				rad_btn.usr_button_side = "right"
				rad_btn.wid_buttonAction = r_action

				-- initial state
				if header and header.skin.button_side == rad_btn.usr_button_side then
					rad_btn:setChecked(true)
				end
				yy = yy + hh
			end
		end


		-- Radio Buttons: Header text alignment
		do
			yy = yy + hh
			local text1 = content:addChild("base/text", {
				x=xx, y=yy, w=ww, h=hh,
				font = context.resources.fonts.p
			})
			text1.text = "Header Text Alignment"
			text1.x = text1.x + 9 -- XXX work on syncing padding with embedded widget labels
			text1:refreshText()
			yy = yy + hh

			local r_action = function(self)
				local frame = commonWimp.getFrame(self)
				if frame then
					skin_clone.header_text_align_h = self.usr_text_align_h
					self.context.resources:refreshSkinDefInstance(skin_clone)
					frame:reshape(true)
					print("skin_clone.header_text_align_h", skin_clone.header_text_align_h)
					print("frame.skin.header_text_align_h", frame.skin.header_text_align_h)
				end
			end

			-- Left
			do
				local rad_btn = content:addChild("base/radio_button", {x=xx, y=yy, w=ww, h=hh})
				rad_btn.bijou_side = "right"
				rad_btn.radio_group = "rg_header_text_align_h"
				rad_btn:setLabel("Left")
				rad_btn.usr_text_align_h = 0
				rad_btn.wid_buttonAction = r_action

				-- initial state
				if header and header.skin.text_align_h == rad_btn.usr_text_align_h then
					rad_btn:setChecked(true)
				end
				yy = yy + hh
			end

			-- Center
			do
				local rad_btn = content:addChild("base/radio_button", {x=xx, y=yy, w=ww, h=hh})
				rad_btn.bijou_side = "right"
				rad_btn.radio_group = "rg_header_text_align_h"
				rad_btn:setLabel("Center")
				rad_btn.usr_text_align_h = 0.5
				rad_btn.wid_buttonAction = r_action

				-- initial state
				if header and header.skin.text_align_h == rad_btn.usr_text_align_h then
					rad_btn:setChecked(true)
				end
				yy = yy + hh
			end

			-- Right
			do
				local rad_btn = content:addChild("base/radio_button", {x=xx, y=yy, w=ww, h=hh})
				rad_btn.bijou_side = "right"
				rad_btn.radio_group = "rg_header_text_align_h"
				rad_btn:setLabel("Right")
				rad_btn.usr_text_align_h = 1
				rad_btn.wid_buttonAction = r_action

				-- initial state
				if header and header.skin.text_align_h == rad_btn.usr_text_align_h then
					rad_btn:setChecked(true)
				end
				yy = yy + hh
			end
		end

		-- Button: Close
		do
			yy = yy + hh
			local btn = content:addChild("base/button", {x=xx, y=yy, w=ww, h=hh})
			btn:setLabel("Close Window")
			btn.wid_buttonAction = function(self)
				self:bubbleEvent("frameCall_close")
			end
			yy = yy + hh
		end
	end

	frame:reshape(true)
	frame:center(true, true)

	return frame
end


return plan
