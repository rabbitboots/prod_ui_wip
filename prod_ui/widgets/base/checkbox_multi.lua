--[[
	A skinned, multi-state checkbox.
	The skin provides graphics for each state.
	The library user must set an appropriate max value for this widget.
--]]


local context = select(1, ...)


local lgcButton = context:getLua("shared/lgc_button")
local lgcLabel = context:getLua("shared/lgc_label")
local textUtil = require(context.conf.prod_ui_req .. "lib.text_util")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widDebug = require(context.conf.prod_ui_req .. "logic.wid_debug")
local widShared = require(context.conf.prod_ui_req .. "logic.wid_shared")


local def = {
	skin_id = "checkbox_multi1",
}


def.wid_buttonAction = lgcButton.wid_buttonAction
def.wid_buttonAction2 = lgcButton.wid_buttonAction2
def.wid_buttonAction3 = lgcButton.wid_buttonAction3


def.setEnabled = lgcButton.setEnabled
def.setValue = lgcButton.setValue
def.setMaxValue = lgcButton.setMaxValue
def.rollValue = lgcButton.rollValue
def.setLabel = lgcLabel.widSetLabel


def.uiCall_pointerHoverOn = lgcButton.uiCall_pointerHoverOn
def.uiCall_pointerHoverOff = lgcButton.uiCall_pointerHoverOff
def.uiCall_pointerPress = lgcButton.uiCall_pointerPress
def.uiCall_pointerRelease = lgcButton.uiCall_pointerReleaseCheckMulti
def.uiCall_pointerUnpress = lgcButton.uiCall_pointerUnpress
def.uiCall_thimbleAction = lgcButton.uiCall_thimbleActionCheckMulti
def.uiCall_thimbleAction2 = lgcButton.uiCall_thimbleAction2


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		widShared.setupViewport(self, 1)
		widShared.setupViewport(self, 2)

		lgcLabel.setup(self)

		self.value = 1
		self.value_max = 1

		-- [XXX 8] (Optional) image associated with the button.
		--self.graphic = <tq>

		-- State flags
		self.enabled = true
		self.hovered = false
		self.pressed = false

		self:skinSetRefs()
		self:skinInstall()

		self:reshape()
	end
end


function def:uiCall_reshape()
	local skin = self.skin

	-- Viewport #1 is the text bounding box.
	-- Viewport #2 is the bijou drawing rectangle.

	widShared.resetViewport(self, 1)
	widShared.carveViewport(self, 1, "border")
	widShared.splitViewport(self, 1, 2, false, skin.bijou_spacing, (skin.bijou_side == "right"))
	widShared.carveViewport(self, 2, "margin")
	lgcLabel.reshapeLabel(self)
end


def.skinners = { -- (2024-11-01 copied from shared/skn_button_bijou.lua)
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
			local tex_quad = res.quads_state[self.value]

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
			-- State values without a matching quad will render no graphic.
			-- XXX: Scissor to Viewport #2?
			if tex_quad then
				love.graphics.setColor(res.color_bijou)
				uiGraphics.quadXYWH(tex_quad, box_x, box_y, skin.bijou_w, skin.bijou_h)
			end

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


return def
