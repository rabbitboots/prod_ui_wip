return {
	skinner_id = "wimp/divider",

	box = "*style/boxes/frame_norm",

	tq_px = "*tex_quads/pixel",
	slc_sash_lr = "*tex_slices/sash_lr",
	slc_sash_tb = "*tex_slices/sash_tb",

	sash_breadth = 16,

	-- Reduces the intersection box when checking for the mouse *entering* a sash.
	-- NOTE: overly large values will make the sash unclickable.
	sash_contract_x = 4,
	sash_contract_y = 4,

	-- Increases the intersection box when checking for the mouse *leaving* a sash.
	-- NOTES:
	-- * Overly large values will prevent the user from clicking on widgets that
	--   are descendants of the divider.
	-- * The expansion does not go beyond the divider's body.
	sash_expand_x = 8,
	sash_expand_y = 8,

	cursor_sash_hover_h = "sizewe",
	cursor_sash_hover_v = "sizens",

	cursor_sash_drag_h = "sizewe",
	cursor_sash_drag_v = "sizens",

	color_body = {1.0, 1.0, 1.0, 1.0},
	slc_body = "*tex_slices/container_body1",
}
