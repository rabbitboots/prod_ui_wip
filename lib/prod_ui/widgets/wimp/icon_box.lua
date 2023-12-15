
--[[

XXX: Under construction.

A box of icons.

Multi category:

+-----------------------------+-+
| [v] Category                |^|
| +-------------------------+ +-+
| | +---+ +---+ +---+ +---+ | | |
| | |[B]| |[B]| |[B]| |[B]| | | |
| | |Foo| |Bar| |Baz| |Bop| | | |
| | +---+ +---+ +---+ +---+ | | |
| | +---+ +---+             | | |
| | |[B]| |[B]|             | | |
| | |Zip| |Pop|             | | |
| | +---+ +---+             | | |
| +-------------------------+ | |
|                             | |
| [>] Collapsed category      +-+
| --------------------------- |v|
+-----------------------------+-+


Single category:

+-------------------------+-+
| +---+ +---+ +---+ +---+ |^|
| |[B]| |[B]| |[B]| |[B]| +-+
| |Foo| |Bar| |Baz| |Bop| | |
| +---+ +---+ +---+ +---+ | |
| +---+ +---+             | |
| |[B]| |[B]|             | |
| |Zip| |Pop|             +-+
| +---+ +---+             |v|
+-------------------------+-+

Icon flows:

L2R: Left to right
R2L: Right to left
T2B: Top to bottom
B2T: Bottom to top

L2R_T2B: Left to right, top to bottom
R2L_T2B: Right to left, top to bottom
L2R_B2T: Left to right, bottom to top
R2L_B2T: Right to left, bottom to top

T2B_L2R: Top to bottom, left to right
B2T_L2R: Bottom to top, left to right
T2B_R2L: Top to bottom, right to left
B2T_R2L: Bottom to top, right to left

--]]


local context = select(1, ...)


local commonMenu = require(context.conf.prod_ui_req .. "logic.common_menu")
local commonScroll = require(context.conf.prod_ui_req .. "logic.common_scroll")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widDebug = require(context.conf.prod_ui_req .. "logic.wid_debug")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


local def = {
	skin_id = "icon_box1",
	click_repeat_oob = true, -- Helps with integrated scroll bar buttons
}


widShared.scrollSetMethods(def)
def.setScrollBars = commonScroll.setScrollBars
def.impl_scroll_bar = context:getLua("shared/impl_scroll_bar1")


function def:uiCall_create(inst)

	if self == inst then
		-- ...
	end
end


def.skinners = {
	default = {

		install = function(self, skinner, skin)
			uiTheme.skinnerCopyMethods(self, skinner)
		end,


		remove = function(self, skinner, skin)
			uiTheme.skinnerClearData(self)
		end,


		--refresh = function(self, skinner, skin)
		--update = function(self, skinner, skin, dt)


		render = function(self, ox, oy)

			love.graphics.push("all")

			-- [[
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle("line", 0, 0, self.w - 1, self.h - 1)
			love.graphics.print("<WIP Icon Box>", 0, 0)
			--]]

			love.graphics.pop()
		end,

		--renderLast = function(self, ox, oy) end,
		--renderThimble = function(self, ox, oy) end,
	},
}


return def
