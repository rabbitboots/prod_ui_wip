

local context = select(1, ...)


local lgcLabel = context:getLua("shared/lgc_label")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widDebug = require(context.conf.prod_ui_req .. "common.wid_debug")


return {
	default = {
		install = function(self, skinner, skin)
			uiTheme.skinnerCopyMethods(self, skinner)
		end,


		remove = function(self, skinner, skin)
			uiTheme.skinnerClearData(self)
		end,


		--refresh = function (self, skinner, skin)
		--update = function(self, skinner, skin, dt)


		render = function(self, ox, oy)
			local skin = self.skin
			local res = uiTheme.pickButtonResource(self, skin)
			local tex_quad = self.checked and res.quad_checked or res.quad_unchecked

			-- Calculate bijou drawing coordinates.
			local box_x
			if skin.bijou_align_h == "right" then
				box_x = math.floor(0.5 + self.vp2_x + self.vp2_w - skin.bijou_w)

			elseif skin.bijou_align_h == "center" then
				box_x = math.floor(0.5 + self.vp2_x + (self.vp2_w - skin.bijou_w) * 0.5)

			else -- "left"
				box_x = math.floor(0.5 + self.vp2_x)
			end

			local box_y
			if skin.bijou_align_v == "bottom" then
				box_y = math.floor(0.5 + self.vp2_y + self.vp2_h - skin.bijou_h)

			elseif skin.bijou_align_v == "middle" then
				box_y = math.floor(0.5 + self.vp2_y + (self.vp2_h - skin.bijou_h) * 0.5)

			else -- "top"
				box_y = math.floor(0.5 + self.vp2_y)
			end

			-- Draw the bijou.
			-- XXX: Scissor to Viewport #2?
			love.graphics.setColor(res.color_bijou)
			uiGraphics.quadXYWH(tex_quad, box_x, box_y, skin.bijou_w, skin.bijou_h)

			-- Draw the text label.
			if self.label_mode then
				lgcLabel.render(self, skin, skin.label_style.font, res.color_label, res.color_label_ul, res.label_ox, res.label_oy, ox, oy)
			end

			-- XXX: Debug border (viewport rectangle)
			--[[
			widDebug.debugDrawViewport(self, 1)
			widDebug.debugDrawViewport(self, 2)
			--]]
		end,
	},
}
