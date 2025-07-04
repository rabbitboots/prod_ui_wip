
local plan = {}


local function rngChr(n)
	local str = ""
	for i = 1, n do
		str = str .. string.char(love.math.random(33, 127))
	end

	return str
end


local function hof_sort1(a, b)
	return a.label1 < b.label1
end
local function hof_sort2(a, b)
	return (a.label2 == b.label2) and a.label1 < b.label1
		or a.label2 < b.label2
end
local function hof_sort3(a, b)
	return (a.label3 == b.label3) and a.label2 < b.label2
		or (a.label2 == b.label2) and a.label1 < b.label1
		or a.label3 < b.label3
end
local function hof_sort4(a, b)
	return (a.label4 == b.label4) and a.label3 < b.label3
		or (a.label3 == b.label3) and a.label2 < b.label2
		or (a.label2 == b.label2) and a.label1 < b.label1
		or a.label4 < b.label4
end
local sort_functions = {
	hof_sort1,
	hof_sort2,
	hof_sort3,
	hof_sort4
}


local function columnSortLabels(wid, column)
	local items = wid.MN_items
	print("column.id", column.id)
	table.sort(items, sort_functions[column.id])

	if not wid.column_sort_ascending then
		local lgcTab = wid.context:getLua("shared/lgc_tab")
		lgcTab.reverseSequence(items)
	end

	return true
end


function plan.makeWindowFrame(root)
	local context = root.context

	local frame = root:newWindowFrame()
	frame.w = 640
	frame.h = 480
	frame:initialize()
	frame:setFrameTitle("Tabular Menu Test")

	frame:setLayoutBase("viewport")
	frame:setScrollRangeMode("zero")
	frame:setScrollBars(false, false)

	local menu_tab = frame:addChild("wimp/menu_tab")
	menu_tab.w = 640
	menu_tab.h = 480
	menu_tab:initialize()

	frame:setLayoutNode(menu_tab, frame.layout_tree)

	menu_tab.renderThimble = function() end

	menu_tab.MN_drag_select = true
	menu_tab.MN_wrap_selection = false

	menu_tab:setScrollBars(true, true)


	local primary_column = menu_tab:addColumn("Column 1", true, columnSortLabels) -- ID #1
	primary_column.lock_visibility = true

	menu_tab:addColumn("Column 2", true, columnSortLabels) -- ID #2
	menu_tab:addColumn("Column 3", true, columnSortLabels) -- ID #3
	menu_tab:addColumn("Column 4", true, columnSortLabels) -- ID #4

	menu_tab.column_sort_ascending = true

	-- TODO: Word filter? Or just use a known-good random seed.
	for i = 1, 100 do
		local item = menu_tab:addRow()

		item.label1 = tostring(i)
		item.label2 = rngChr(3)
		item.label3 = rngChr(5)
		item.label4 = rngChr(8)

		item.cells[1] = {text = item.label1}
		item.cells[2] = {text = item.label2}
		item.cells[3] = {text = item.label3}
		item.cells[4] = {text = item.label4}

		local implTabCell = context:getLua("shared/impl_tab_cell")
		for j, cell in ipairs(item.cells) do
			cell.render = implTabCell.render
			cell.reshape = implTabCell.reshape
		end
	end

	menu_tab:refreshRows()

	frame:reshape()
	frame:center(true, true)

	return frame
end


return plan
