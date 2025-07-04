local plan = {}


-- ProdUI
local demoShared = require("demo_shared")


function plan.make(panel)
	--title("Barebones widgets")

	panel:setLayoutBase("viewport-width")
	panel:setScrollRangeMode("auto")
	panel:setScrollBars(false, true)

	local xx, yy = 0, 0
	local ww, hh = 224, 64

	local bb_button = panel:addChild("barebones/button")
	bb_button:initialize()
	demoShared.setStaticLayout(panel, bb_button, xx, yy, ww, hh)

	bb_button:setLabel("<Button>")

	bb_button.wid_buttonAction = function(self)
		self:setLabel(">Button<")
	end

	yy = yy + hh

	local bb_rep = panel:addChild("barebones/button_repeat")
	bb_rep:initialize()
	demoShared.setStaticLayout(panel, bb_rep, xx, yy, ww, hh)

	bb_rep:setLabel("<Repeat #0>")
	bb_rep.usr_count = 0

	bb_rep.wid_buttonAction = function(self)
		self.usr_count = self.usr_count + 1
		self:setLabel(">Repeat #" .. tostring(self.usr_count) .. "<")
	end

	yy = yy + hh

	local bb_instant = panel:addChild("barebones/button_instant")
	bb_instant:initialize()
	demoShared.setStaticLayout(panel, bb_instant, xx, yy, ww, hh)

	bb_instant:setLabel("Instant-Action Button")
	bb_instant.usr_n = 0

	bb_instant.wid_buttonAction = function(self)
		self.usr_n = self.usr_n + 1
		self:setLabel("Activated! #" .. self.usr_n)
	end

	yy = yy + hh

	local bb_stick = panel:addChild("barebones/button_sticky")
	bb_stick:initialize()
	demoShared.setStaticLayout(panel, bb_stick, xx, yy, ww, hh)

	bb_stick:setLabel("Sticky Button")

	bb_stick.wid_buttonAction = function(self)
		self:setLabel("Stuck!")
	end

	yy = yy + hh

	local bb_checkbox = panel:addChild("barebones/checkbox")
	bb_checkbox:initialize()
	demoShared.setStaticLayout(panel, bb_checkbox, xx, yy, ww, hh)

	bb_checkbox:setLabel("Checkbox")

	yy = yy + hh

	local bb_radio
	bb_radio = panel:addChild("barebones/radio_button")
	bb_radio:initialize()
	demoShared.setStaticLayout(panel, bb_radio, xx, yy, ww, hh)

	bb_radio.radio_group = "bare1"
	bb_radio:setLabel("Radio1")

	yy = yy + hh

	bb_radio = panel:addChild("barebones/radio_button")
	bb_radio:initialize()
	demoShared.setStaticLayout(panel, bb_radio, xx, yy, ww, hh)

	bb_radio.radio_group = "bare1"
	bb_radio:setLabel("Radio2")

	yy = yy + hh

	local bb_lbl
	bb_lbl = panel:addChild("barebones/label")
	bb_lbl:initialize()
	demoShared.setStaticLayout(panel, bb_lbl, xx, yy, ww, hh)

	bb_lbl.enabled = true
	bb_lbl:setLabel("Label (enabled)")

	yy = yy + hh

	bb_lbl = panel:addChild("barebones/label")
	bb_lbl:initialize()
	demoShared.setStaticLayout(panel, bb_lbl, xx, yy, ww, hh)

	bb_lbl.enabled = false
	bb_lbl:setLabel("Label (disabled)")

	yy = yy + hh

	local bb_sl1 = panel:addChild("barebones/slider_bar")
	bb_sl1:initialize()
	demoShared.setStaticLayout(panel, bb_sl1, xx, yy, ww, hh)

	bb_sl1.trough_vertical = false
	bb_sl1:setLabel("Barebones Slider Bar")

	bb_sl1.slider_pos = 0
	bb_sl1.slider_def = 0
	bb_sl1.slider_max = 64

	yy = yy + hh

	local bb_sl2 = panel:addChild("barebones/slider_bar")
	bb_sl2:initialize()
	demoShared.setStaticLayout(panel, bb_sl2, xx, yy, hh, ww)

	bb_sl2.trough_vertical = true
	bb_sl2:setLabel("Vertical")

	bb_sl2.slider_pos = 0
	bb_sl2.slider_def = 0
	bb_sl2.slider_max = 64

	yy = yy + ww

	local bb_input = panel:addChild("barebones/input_box")
	bb_input:initialize()
	demoShared.setStaticLayout(panel, bb_input, xx, yy, ww, 32)

	bb_input:setText("Barebones Input Box")
	--bb_input:setMaxCodePoints(4)
end


return plan
