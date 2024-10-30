

-- ProdUI
local commonMenu = require("prod_ui.logic.common_menu")
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

	frame:setFrameTitle("Number Box")

	local content = frame:findTag("frame_content")
	if content then
		content.layout_mode = "resize"
		content:setScrollBars(false, false)

		-- [=[
		makeLabel(content, 32, 0, 512, 32, "**NOTE** This widget is still being developed.", "single")
		local num_box = content:addChild("wimp/number_box")

		num_box.x = 32
		num_box.y = 96
		num_box.w = 256
		num_box.h = 32

		num_box.wid_action = function(self)
			-- WIP
		end
		--]=]
	end

	frame:reshape(true)
	frame:center(true, true)

	return frame
end


return plan
