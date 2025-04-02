local plan = {}


local demoShared = require("demo_shared")


function plan.make(panel)
	panel:setLayoutBase("viewport-width")
	panel:setScrollRangeMode("auto")
	panel:setScrollBars(false, true)

	demoShared.makeTitle(panel, nil, "Widgets")

	demoShared.makeParagraph(panel, nil, "A catalog of ProdUI's built-in widgets.")
end


return plan
