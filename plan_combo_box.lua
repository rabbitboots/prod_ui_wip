
-- ProdUI
local uiLayout = require("prod_ui.ui_layout")
local widShared = require("prod_ui.common.wid_shared")


local plan = {}


local function makeLabel(frame, x, y, w, h, text, label_mode)
	label_mode = label_mode or "single"

	local label = frame:addChild("base/label")
	label.x, label.y, label.w, label.h = x, y, w, h
	label:initialize()
	label:setLabel(text, label_mode)

	return label
end


function plan.make(root)
	local context = root.context

	local frame = root:newWindowFrame()
	frame.w = 640
	frame.h = 480
	frame:initialize()
	frame:setFrameTitle("Combo Boxes")

	frame.auto_layout = true
	frame:setScrollBars(false, false)

	makeLabel(frame, 32, 0, 512, 32, "**Under Construction** This widget doesn't work correctly yet.", "single")
	local combo_box = frame:addChild("wimp/combo_box")
	combo_box.x = 32
	combo_box.y = 96
	combo_box.w = 256
	combo_box.h = 32
	combo_box:initialize()

	combo_box:addItem("foo")
	combo_box:addItem("bar")
	combo_box:addItem("baz")
	combo_box:addItem("bop")

	for i = 1, 100 do
		combo_box:addItem(tostring(i))
	end

	combo_box.wid_inputChanged = function(self, str)
		print("ComboBox: Input changed: " .. str)
	end
	combo_box.wid_action = function(self)
		print("ComboBox: user pressed enter")
	end
	combo_box.wid_thimble1Release = function(self)
		print("ComboBox: user navigated away from this widget")
	end

	frame:reshape(true)
	frame:center(true, true)

	return frame
end


return plan
