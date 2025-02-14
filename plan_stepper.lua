
-- ProdUI
local uiLayout = require("prod_ui.ui_layout")
local widShared = require("prod_ui.common.wid_shared")


local plan = {}


local function timeFormatted()
	return string.format("%.2f", tostring(love.timer.getTime()))
end


local function makeLabel(frame, x, y, w, h, text, label_mode)
	label_mode = label_mode or "single"

	local label = frame:addChild("base/label")
	label.x, label.y, label.w, label.h = x, y, w, h
	label:initialize()
	label:setLabel(text, label_mode)

	return label
end


function plan.make(parent)
	local context = parent.context

	local frame = parent:addChild("wimp/window_frame")
	frame.w = 640
	frame.h = 640
	frame:initialize()

	frame:setFrameTitle("Stepper")

	frame.auto_layout = true
	frame:setScrollBars(false, true)

	local stepper_h = frame:addChild("base/stepper")
	stepper_h.x = 32
	stepper_h.y = 32
	stepper_h.w = 240
	stepper_h.h = 32
	stepper_h:initialize()

	stepper_h:insertOption("Foobar")
	stepper_h:insertOption("Bazbop")
	local remove_test_i = stepper_h:insertOption("Remove Test")
	stepper_h:insertOption({text = "Dipdop"})

	stepper_h:removeOption(remove_test_i)

	stepper_h:reshape()


	local stepper_v = frame:addChild("base/stepper")
	stepper_v.x = 288
	stepper_v.y = 32
	stepper_v.w = 64
	stepper_v.h = 128
	stepper_v:initialize()
	stepper_v:insertOption("Foobar")
	stepper_v:insertOption("Bazbop")
	stepper_v:insertOption({text = "Dipdop"})

	stepper_v.vertical = true

	stepper_v:reshape()

	frame:reshape(true)
	frame:center(true, true)

	return frame
end


return plan
