
-- ProdUI
local demoShared = require("demo_shared")


local plan = {}


function plan.make(panel)
	--title("Combo Boxes")

	panel:setLayoutBase("viewport-width")
	panel:setScrollRangeMode("zero")
	panel:setScrollBars(false, false)

	local combo_box = panel:addChild("wimp/combo_box")
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
end


return plan
