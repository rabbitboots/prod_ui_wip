--[[
A skinned repeat-action button.
--]]


local context = select(1, ...)


local lgcButton = context:getLua("shared/lgc_button")
local lgcLabel = context:getLua("shared/lgc_label")
local uiGraphics = require(context.conf.prod_ui_req .. "ui_graphics")
local uiTheme = require(context.conf.prod_ui_req .. "ui_theme")
local widShared = require(context.conf.prod_ui_req .. "common.wid_shared")


local def = {
	skin_id = "button1",
}


def.wid_buttonAction = lgcButton.wid_buttonAction
def.wid_buttonAction2 = lgcButton.wid_buttonAction2
def.wid_buttonAction3 = lgcButton.wid_buttonAction3


def.setEnabled = lgcButton.setEnabled
def.setLabel = lgcLabel.widSetLabel


def.uiCall_pointerHoverOn = lgcButton.uiCall_pointerHoverOn
def.uiCall_pointerHoverOff = lgcButton.uiCall_pointerHoverOff
def.uiCall_pointerPress = lgcButton.uiCall_pointerPressActivate
def.uiCall_pointerPressRepeat = lgcButton.uiCall_pointerPressRepeat
def.uiCall_pointerRelease = lgcButton.uiCall_pointerRelease
def.uiCall_pointerUnpress = lgcButton.uiCall_pointerUnpress
def.uiCall_thimbleAction = lgcButton.uiCall_thimbleAction
def.uiCall_thimbleAction2 = lgcButton.uiCall_thimbleAction2


function def:uiCall_create(inst)
	if self == inst then
		self.visible = true
		self.allow_hover = true
		self.can_have_thimble = true

		widShared.setupViewports(self, 2)

		lgcLabel.setup(self)

		-- (Optional) If true, click-repeat actions can fire if the pointer is outside the widget bounds.
		-- If false/nil, the pointer must be in range.
		--self.click_repeat_oob = false

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
	widShared.resetViewport(self, 1)
	widShared.carveViewport(self, 1, "border")

	lgcLabel.reshapeLabel(self)
end


def.skinners = context:getLua("shared/skn_button")


return def
