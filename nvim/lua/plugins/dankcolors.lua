return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#121414',
				base01 = '#121414',
				base02 = '#7a8383',
				base03 = '#7a8383',
				base04 = '#c8d5d5',
				base05 = '#f8ffff',
				base06 = '#f8ffff',
				base07 = '#f8ffff',
				base08 = '#ff9fc1',
				base09 = '#ff9fc1',
				base0A = '#cddedf',
				base0B = '#9ef3a5',
				base0C = '#f4feff',
				base0D = '#cddedf',
				base0E = '#eefeff',
				base0F = '#eefeff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#7a8383',
				fg = '#f8ffff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#cddedf',
				fg = '#121414',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#7a8383' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#f4feff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#eefeff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#cddedf',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#cddedf',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#f4feff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#9ef3a5',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#c8d5d5' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#c8d5d5' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#7a8383',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
