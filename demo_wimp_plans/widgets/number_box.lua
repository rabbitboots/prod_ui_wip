
-- ProdUI
--local demoShared = require("demo_shared")


local plan = {}


function plan.make(panel)
	--title("Number Box")

	panel:setLayoutBase("viewport-width")
	panel:setScrollRangeMode("zero")
	panel:setScrollBars(false, false)

	-- [=[
	local num_box = panel:addChild("wimp/number_box")
	num_box.x = 32
	num_box.y = 96
	num_box.w = 256
	num_box.h = 32

	num_box.wid_action = function(self)
		-- WIP
	end

	num_box:initialize()
	--]=]
end


return plan
