
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


local function _assertNoThimble(self, inst)
	if self == inst then
		if self.context.thimble1 == self or self.context.thimble2 == self then
			error("this widget is not supposed to be capable of holding the thimble.")
		end
	end
end


function plan.make(root)
	local context = root.context

	local unselectable = true
	local view_level = "high"
	local frame = root:newWindowFrame(view_level)
	frame.w = 320
	frame.h = 350
	frame:initialize(unselectable, view_level)
	frame:setFrameTitle("Unselectable Frame")
	frame.auto_layout = true
	frame:setScrollBars(false, false)

	frame.userUpdate = function(self, dt)
		if self.context.root.selected_frame == self then
			error("this frame is not supposed to be selectable.")
		end
	end
	frame.uiCall_thimble1Take = _assertNoThimble
	frame.uiCall_thimble2Take = _assertNoThimble


	makeLabel(frame, 0, 0, 320, 190, "This frame can be manipulated with the mouse, but it cannot be selected (among other frames), and its controls should not be capable of taking keyboard focus.", "multi")

	local xx, yy = 0, 200
	local ww, hh = 224, 64

	local bb_button = frame:addChild("base/button")
	bb_button.x = xx
	bb_button.y = yy
	bb_button.w = ww
	bb_button.h = hh

	bb_button.uiCall_thimble1Take = _assertNoThimble
	bb_button.uiCall_thimble2Take = _assertNoThimble

	bb_button:initialize()
	bb_button.can_have_thimble = false

	bb_button:setLabel("Example Button")


	yy = yy + hh

	local bb_cbox = frame:addChild("base/checkbox")
	bb_cbox.x = xx
	bb_cbox.y = yy
	bb_cbox.w = ww
	bb_cbox.h = hh

	bb_cbox.uiCall_thimble1Take = _assertNoThimble
	bb_cbox.uiCall_thimble2Take = _assertNoThimble

	bb_cbox:initialize()
	bb_cbox.can_have_thimble = false

	bb_cbox:setLabel("Example Checkbox")

	frame:reshape()
	frame:center(true, true)

	return frame
end


return plan
