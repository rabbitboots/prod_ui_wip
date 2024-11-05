
-- ProdUI
local uiLayout = require("prod_ui.ui_layout")
local widShared = require("prod_ui.logic.wid_shared")


local plan = {}


local function makeLabel(content, x, y, w, h, text, label_mode)
	label_mode = label_mode or "single"

	local label = content:addChild("base/label")
	label.x, label.y, label.w, label.h = x, y, w, h
	label:setLabel(text, label_mode)

	return label
end


function plan.make(parent)
	local context = parent.context

	local frame = parent:addChild("wimp/window_frame")

	frame.w = 640
	frame.h = 480

	frame:setFrameTitle("Button skin tests")

	local content = frame:findTag("frame_content")
	if content then
		content.layout_mode = "resize"

		content:setScrollBars(false, false)

		-- Make a one-off SkinDef Patch that we can adjust without changing all other buttons with the default skin.
		local resources = content.context.resources
		local patch = resources:newSkinDef("button1")
		resources:registerSkinDef(patch, patch, false)
		-- This patch is empty (except for an __index reference), so refreshSkinDef() isn't necessary in
		-- this specific case. You should call it whenever changing resources which need to be refreshed
		-- from the theme (prefixed with "*") or scaled (prefixed with "$").
		resources:refreshSkinDef(patch)

		local button_norm = content:addChild("base/button", {skin_id = patch})
		button_norm.x = 256
		button_norm.w = 224
		button_norm.h = 64
		button_norm:setLabel("Normal Skinned Button")

		local function radioAlignH(self)
			button_norm.skin.label_align_h = self.usr_align
		end

		local function radioAlignV(self)
			button_norm.skin.label_align_v = self.usr_align
		end

		local xx, yy, ww1, ww2, hh1, hh2 = 0, 0, 64, 192, 40, 64

		makeLabel(content, xx, yy, ww2, hh1, "skin.label_align_h", "single")

		yy = yy + hh1

		local bb_rdo
		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_h"
		bb_rdo.usr_align = "left"
		bb_rdo:setLabel("Left")
		bb_rdo.wid_buttonAction = radioAlignH

		xx = xx + ww1

		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_h"
		bb_rdo.usr_align = "center"
		bb_rdo:setLabel("Center")
		bb_rdo.wid_buttonAction = radioAlignH

		xx = xx + ww1

		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_h"
		bb_rdo.usr_align = "right"
		bb_rdo:setLabel("Right")
		bb_rdo.wid_buttonAction = radioAlignH

		xx = 0
		yy = yy + hh2

		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww2, h = hh2})
		bb_rdo.radio_group = "align_h"
		bb_rdo.usr_align = "justify"
		bb_rdo:setLabel("Justify")
		bb_rdo.wid_buttonAction = radioAlignH

		bb_rdo:setCheckedConditional("usr_align", button_norm.skin.label_align_h)

		yy = yy + hh2

		yy = yy + hh1

		makeLabel(content, xx, yy, ww2, hh1, "skin.label_align_v", "single")

		yy = yy + hh1

		local bb_rdo
		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_v"
		bb_rdo.usr_align = "top"
		bb_rdo:setLabel("Top")
		bb_rdo.wid_buttonAction = radioAlignV

		xx = xx + ww1

		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_v"
		bb_rdo.usr_align = "middle"
		bb_rdo:setLabel("Middle")
		bb_rdo.wid_buttonAction = radioAlignV

		xx = xx + ww1

		bb_rdo = content:addChild("barebones/radio_button", {x = xx, y = yy, w = ww1, h = hh2})
		bb_rdo.radio_group = "align_v"
		bb_rdo.usr_align = "bottom"
		bb_rdo:setLabel("Bottom")
		bb_rdo.wid_buttonAction = radioAlignV

		bb_rdo:setCheckedConditional("usr_align", button_norm.skin.label_align_v)

		xx = xx + ww1
	end

	frame:reshape(true)
	frame:center(true, true)

	return frame
end


return plan
