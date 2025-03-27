-- To load: local lib = context:getLua("shared/lib")


--[[
Shared container logic.
--]]


local context = select(1, ...)


local lgcContainer = {}


local commonScroll = require(context.conf.prod_ui_req .. "common.common_scroll")
local uiShared = require(context.conf.prod_ui_req .. "ui_shared")
local widLayout = context:getLua("core/wid_layout")


local _enum_scr_rng = uiShared.makeLUTV("zero", "auto", "manual")


lgcContainer.methods = {}
local _methods = lgcContainer.methods


function lgcContainer.setupMethods(self)
	uiShared.attachFields(lgcContainer.methods, self, false)
end


function _methods:setScrollRangeMode(mode)
	uiShared.enum(1, mode, "scrollRangeMode", _enum_scr_rng)

	self.scroll_range_mode = mode
end


function _methods:getScrollRangeMode()
	return self.scroll_range_mode
end


function _methods:setSashesEnabled(enabled)
	self.sashes_enabled = not not enabled

	if not self.sashes_enabled then
		self.sash_hover = false
		if self.press_busy == "sash" then
			self.press_busy = false
		end
	end
end


function _methods:getSashesEnabled()
	return self.sashes_enabled
end


function _methods:getSashBreadth()
	return self.skin.sash_breadth
end


function _methods:configureSashNode(n1, n2)
	uiShared.type1(1, n1, "table")
	uiShared.type1(2, n2, "table")

	if n1.mode ~= "slice" then
		error("argument #1: expected a slice node.")
	end
	if n2.nodes and #n2.nodes > 0 then
		error("argument #2: sashes are supposed to be leaf nodes.")
	end

	n2:setMode("slice", "px", n1.slice_edge, self.skin.sash_breadth, true)
end


function _methods:setLayoutBase(layout_base)
	uiShared.enum(1, layout_base, "LayoutBase", widLayout._enum_layout_base)

	self.layout_base = layout_base
end


function _methods:getLayoutBase()
	return self.layout_base
end


function lgcContainer.keepWidgetInView(self, wid, pad_x, pad_y)
	-- [XXX 1] There should be an optional rectangle within the widget that gets priority for being in view.
	-- Examples include the caret in a text box, the selection in a menu, and the thumb in a slider bar.

	-- Get widget position relative to this container.
	local x, y = wid:getPositionInAncestor(self)
	local w, h = wid.w, wid.h

	if wid.focal_x then -- [XXX 1] Untested
		x = x + wid.focal_x
		y = y + wid.focal_y
		w = wid.focal_w
		h = wid.focal_h
	end

	local skin = self.skin

	self:scrollRectInBounds(
		x - pad_x,
		y - pad_y,
		x + w + pad_x,
		y + h + pad_y,
		false
	)
end


function lgcContainer.checkMouseOverSash(self, node, mx, my, con_x, con_y)
	if node.slice_sash then
		if mx >= node.x + con_x
		and mx < node.x + node.w - con_x
		and my >= node.y + con_y
		and my < node.y + node.h - con_y
		then
			return node
		end

	elseif node.nodes then
		for i, child in ipairs(node.nodes) do
			local rv = lgcContainer.checkMouseOverSash(self, child, mx, my, con_x, con_y)
			if rv then
				return rv
			end
		end
	end
end


function lgcContainer.renderSash(node, wid, ox, oy)
	if node.slice_sash then
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.rectangle("fill", node.x, node.y, node.w, node.h)
	end
end


function lgcContainer.getSashCursorID(edge, is_drag)
	if is_drag then
		return (edge == "left" or edge == "right") and "cursor_sash_drag_h" or "cursor_sash_drag_v"
	else
		return (edge == "left" or edge == "right") and "cursor_sash_hover_h" or "cursor_sash_hover_v"
	end
end


function lgcContainer.sashStateSetup(self)
	self.sashes_enabled = false
	self.sash_hover = false

	-- Length of the node to resize at start of drag state
	self.att_len = 0

	-- Mouse cursor position (absolute) at start of drag state
	self.att_ax, self.att_ay = 0, 0
end


-- Call in def.trickle:uiCall_pointerHover().
function lgcContainer.sashPointerHoverLogic(self, inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if not self.sashes_enabled then
		return
	end

	local mx, my = self:getRelativePosition(mouse_x, mouse_y)
	if not self.sash_hover then
		local skin = self.skin
		local node = lgcContainer.checkMouseOverSash(self, self.layout_tree, mx, my, skin.sash_contract_x, skin.sash_contract_y)
		if node then
			self.sash_hover = node
			local cursor_id = lgcContainer.getSashCursorID(node.slice_edge, false)
			self.cursor_hover = self.skin[cursor_id]
			return true
		else
			self.sash_hover = false
			self.cursor_hover = false
		end
	else
		local node = self.sash_hover
		local expand_x = self.skin.sash_expand_x
		local expand_y = self.skin.sash_expand_y

		if not (mx >= node.x - expand_x
		and mx < node.x + node.w + expand_x
		and my >= node.y - expand_y
		and my < node.y + node.h + expand_y)
		then
			self.sash_hover = false
			self.cursor_hover = false
		end
	end
end


function lgcContainer.wid_uiCall_pointerHover(self, inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		local mx, my = self:getRelativePosition(mouse_x, mouse_y)
		commonScroll.widgetProcessHover(self, mx, my)
	end
end


function lgcContainer.wid_uiCall_pointerHoverOff(self, inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	if self == inst then
		commonScroll.widgetClearHover(self)
	end
end


function lgcContainer.wid_trickle_uiCall_pointerHoverOff(self, inst, mouse_x, mouse_y, mouse_dx, mouse_dy)
	self.sash_hover = false
	self.cursor_hover = false
end


function lgcContainer.sash_tricklePointerPress(self, inst, x, y, button, istouch, presses)
	if self.sashes_enabled
	and self.sash_hover
	and button == 1
	and self.context.mouse_pressed_button == button
	then
		local cn = widLayout.getPreviousSibling(self.sash_hover) -- change_node
		if cn and cn.mode == "slice" and cn.slice_mode == "px" then
			self.press_busy = "sash"
			self.att_ax, self.att_ay = x, y
			if cn.slice_edge == "right" or cn.slice_edge == "left" then
				self.att_len = cn.w
			else -- "top", "bottom"
				self.att_len = cn.h
			end
			local cursor_id = lgcContainer.getSashCursorID(cn.slice_edge, true)
			self.cursor_press = self.skin[cursor_id]

			return true
		end
	end
end


function lgcContainer.sash_tricklePointerDrag(self, inst, x, y, dx, dy)
	if self.sashes_enabled
	and self.press_busy == "sash"
	then
		local cn = widLayout.getPreviousSibling(self.sash_hover) -- change_node
		if cn and cn.mode == "slice" then
			local parent = cn.parent
			if not parent then
				error("missing parent node (no original dimensions to resize against).")
			end

			local edge = cn.slice_edge
			if edge == "right" then
				cn.slice_amount = math.min(cn.slice_amount + parent.w, self.att_len - (x - self.att_ax))

			elseif edge == "left" then
				cn.slice_amount = math.min(cn.slice_amount + parent.w, self.att_len + (x - self.att_ax))

			elseif edge == "top" then
				cn.slice_amount = math.min(cn.slice_amount + parent.h, self.att_len - (y - self.att_ay))

			elseif edge == "bottom" then
				cn.slice_amount = math.min(cn.slice_amount + parent.h, self.att_len + (y - self.att_ay))

			else
				error("invalid slice edge.")
			end

			self:reshape()
		end

		return true
	end
end


function lgcContainer.sash_pointerUnpress(self, inst, x, y, button, istouch, presses)
	if self.sashes_enabled and self.press_busy == "sash" then
		self.press_busy = false
		self.cursor_press = false

		return true
	end
end


return lgcContainer