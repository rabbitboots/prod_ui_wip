require("lib.strict")

--[[
clear && love12d svg2png.lua --source vacuum_dark --dpi 96

* Requires Inkscape 1.3.2 to be aliased to 'inkscape132'
--]]
local example_usage = [[love svg2png.lua --source <input_path> --dpi <number>]]

local love_major, love_minor = love.getVersion()
if love_major < 12 then
	error("LÖVE 12 is required.")
end


local shared = require("shared")


-- Libraries
local nativefs = require("lib.nativefs")
local t2s2 = require("lib.t2s2.t2s2")


local arg_src_path -- theme name
local arg_dpi


local svg_info
local svg_i = 1

local base_data
local no_scale

local out_path


local task_i = 1


local function checkArgSourcePath()
	if not arg_src_path then
		error("missing argument: source path")
	end
end


local function checkArgDPI()
	if not arg_dpi then
		error("missing argument: DPI")
	end
end


function love.load(arguments)
	if #arguments < 1 then
		error("usage: " .. example_usage)
	end

	local i = 1
	while i <= #arguments do
		local argument = arguments[i]

		if argument == "--source" then
			i = i + 1
			arg_src_path = arguments[i]
			checkArgSourcePath()
			i = i + 1

		elseif argument == "--dpi" then
			i = i + 1
			arg_dpi = tonumber(arguments[i])
			checkArgDPI()
			i = i + 1

		else
			error("unknown argument: " .. tostring(argument))
		end
	end
end


local function scaleCoord(value, dpi)
	return math.floor(0.5 + value * (dpi / 96))
end


local function tryScaleCoord(value, dpi)
	if value ~= nil then
		return scaleCoord(value, dpi)
	else
		return value
	end
end


local function assertAllOrNone(err_label, ...)
	local has_nil, has_any

	for i = 1, select("#", ...) do
		if select(i, ...) == nil then
			has_nil = true
		else
			has_any = true
		end
	end

	if has_nil and has_any then
		error("mixed nil and content in all-or-nothing parameters: " .. err_label or "(unknown)")
	end
end


local tasks_export = {
	-- 1
	function()
		checkArgSourcePath()
		checkArgDPI()

		task_i = task_i + 1
		return true
	end,

	-- 2
	function()
		out_path = "output/" .. arg_src_path .. "/" .. arg_dpi
		nativefs.createDirectory(out_path)
		shared.recursiveDelete(out_path)
		nativefs.createDirectory(out_path .. "/png")

		-- Grab and scale quadslice coordinates, if applicable.
		if nativefs.getInfo(arg_src_path .. "/base_data.lua") then
			base_data = shared.nfsLoadLuaFile(arg_src_path .. "/base_data.lua")
			no_scale = {}
			for i, v in ipairs(base_data.no_scale) do
				no_scale[v] = true
			end

			print("Scaling quadslice coords -> base_data.lua -> tbl.slice_coords")
			for k, v in pairs(base_data.slice_coords) do
				if not no_scale[k] then
					v.x = scaleCoord(v.x, arg_dpi)
					v.y = scaleCoord(v.y, arg_dpi)
					v.w1 = scaleCoord(v.w1, arg_dpi)
					v.h1 = scaleCoord(v.h1, arg_dpi)
					v.w2 = scaleCoord(v.w2, arg_dpi)
					v.h2 = scaleCoord(v.h2, arg_dpi)
					v.w3 = scaleCoord(v.w3, arg_dpi)
					v.h3 = scaleCoord(v.h3, arg_dpi)

					v.ox1 = tryScaleCoord(v.ox1, arg_dpi)
					v.oy1 = tryScaleCoord(v.oy1, arg_dpi)
					v.ox2 = tryScaleCoord(v.ox2, arg_dpi)
					v.oy2 = tryScaleCoord(v.oy2, arg_dpi)
					assertAllOrNone("draw offsets", v.ox1, v.oy1, v.ox2, v.oy2)

					v.bx1 = tryScaleCoord(v.bx1, arg_dpi)
					v.by1 = tryScaleCoord(v.by1, arg_dpi)
					v.bx2 = tryScaleCoord(v.bx2, arg_dpi)
					v.by2 = tryScaleCoord(v.by2, arg_dpi)
					assertAllOrNone("border offsets", v.bx1, v.by1, v.bx2, v.by2)
				end
			end
			local out_str = t2s2.serialize(base_data)
			shared.nfsWrite("output/" .. arg_src_path .. "/" .. arg_dpi .. "/base_data.lua", out_str .. "\n")
		end

		svg_info = nativefs.getDirectoryItemsInfo(arg_src_path .. "/svg")
		task_i = task_i + 1
		return true
	end,

	-- 3
	function()
		if svg_i <= #svg_info then
			local item = svg_info[svg_i]
			if item.type == "file" then
				local file_no_ext = string.sub(item.name, 1, -5)
				local ext = string.sub(item.name, -4)
				if string.lower(ext) == ".svg" then
					local dpi_out = no_scale[file_no_ext] and 96 or arg_dpi
					local out_file_path = out_path .. "/png/" .. file_no_ext .. ".png"
					print("export: " .. out_file_path)
					print("OUT_PATH", out_path)
					local ok = os.execute(
						"inkscape132 --export-filename=" .. out_file_path
						.. " --export-dpi=" .. dpi_out
						.. " " .. arg_src_path .. "/svg/" .. item.name
					)
				end
			end
			svg_i = svg_i + 1
		else
			task_i = task_i + 1
		end

		return true
	end,
}


function love.update(dt)
	if love.keyboard.isDown("escape") then
		print("*** Cancelled ***")
		love.event.quit(1)

	elseif not tasks_export[task_i] then
		print("* Finished all tasks.")
		print("task_i", task_i)
		love.event.quit()
		return

	else
		print("* Task #" .. task_i)
		if not tasks_export[task_i]() then
			print("* Aborted on task #" .. task_i)
			love.event.quit()
			return
		end
	end
end
