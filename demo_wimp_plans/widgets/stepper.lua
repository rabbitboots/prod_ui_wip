local plan = {}


local function timeFormatted()
	return string.format("%.2f", tostring(love.timer.getTime()))
end


function plan.make(panel)
	--title("Stepper")

	panel:setLayoutBase("viewport-width")
	panel:setScrollRangeMode("auto")
	panel:setScrollBars(false, true)

	local stepper_h = panel:addChild("base/stepper")
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


	local stepper_v = panel:addChild("base/stepper")
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
end


return plan
