-- * Widget Skin: Split button.


return {
	skinner_id = "wimp/button_split",

	box = "*boxes/button",
	label_style = "*labels/norm",
	tq_px = "*quads/atlas/pixel",

	-- Cursor IDs for hover and press states.
	cursor_on = "hand",
	cursor_press = "hand",

	-- Alignment of label text in Viewport #1.
	label_align_h = "center", -- "left", "center", "right", "justify"
	label_align_v = "middle", -- "top", "middle", "bottom"

	-- A default graphic to use if the widget doesn't provide one.
	-- graphic =

	-- Icon to show in the aux part of the button.
	tq_aux_glyph = "*quads/atlas/arrow_down",

	aux_placement = "right", -- "left", "right", "top", "bottom"

	-- Aux part size (width for 'left' and 'right' placement; height for 'top' and 'bottom' placement)
	-- "auto": size is based on Viewport #2
	aux_size = 28,

	-- Quad (graphic) alignment within Viewport #2.
	quad_align_h = "center", -- "left", "center", "right"
	quad_align_v = "middle", -- "top", "middle", "bottom"

	-- Placement of graphic in relation to text labels.
	graphic_placement = "overlay", -- "left", "right", "top", "bottom", "overlay"

	-- How much space to assign the graphic when not using "overlay" placement.
	graphic_spacing = 0,


	res_idle = {
		slice = "*slices/atlas/button",
		color_body = {1.0, 1.0, 1.0, 1.0},
		color_label = {0.9, 0.9, 0.9, 1.0},
		color_aux_icon = {1.0, 1.0, 1.0, 1.0},
		--color_label_ul
		label_ox = 0,
		label_oy = 0,
	},

	res_hover = {
		slice = "*slices/atlas/button_hover",
		color_body = {1.0, 1.0, 1.0, 1.0},
		color_label = {0.9, 0.9, 0.9, 1.0},
		color_aux_icon = {1.0, 1.0, 1.0, 1.0},
		--color_label_ul
		label_ox = 0,
		label_oy = 0,
	},

	res_pressed = {
		slice = "*slices/atlas/button_press",
		color_body = {1.0, 1.0, 1.0, 1.0},
		color_label = {0.9, 0.9, 0.9, 1.0},
		color_aux_icon = {1.0, 1.0, 1.0, 1.0},
		--color_label_ul
		label_ox = 0,
		label_oy = 1,
	},

	res_disabled = {
		slice = "*slices/atlas/button_disabled",
		color_body = {1.0, 1.0, 1.0, 1.0},
		color_label = {0.5, 0.5, 0.5, 1.0},
		color_aux_icon = {0.5, 0.5, 0.5, 1.0},
		--color_label_ul
		label_ox = 0,
		label_oy = 0,
	},
}
