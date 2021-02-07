-- Copyright 2021 Joshua Krämer, subject to the ISC license

local M = {}

local function text_width(start_position, stop_position)
	local text = buffer:text_range(start_position, stop_position)
	local style = buffer.style_at[start_position]
	return buffer:text_width(style, text)
end

local function scan_line(line)
	local cell_count = 0
	local cell_widths = {}
	local position = buffer:position_from_line(line)
	local cell_start_position = position

	while position < buffer.line_end_position[line] do
		if buffer.char_at[position] == 9 then
			cell_count = cell_count + 1
			cell_widths[cell_count] = text_width(cell_start_position, position)
			position = buffer:position_after(position)
			cell_start_position = position
		else
			position = buffer:position_after(position)
		end
	end

	if cell_count > 0 then
		buffer.elastic_tabstops.lines[line] = {
			cell_count = cell_count,
			cell_widths = cell_widths,
			cell_blocks = {}
		}
	else
		buffer.elastic_tabstops.lines[line] = false
	end

	return cell_count
end

local function array_remove(array, start, count)
	local new_index = 1

	for index = 1, #array do
		if (index >= start) and (index < start + count) then
			array[index] = nil
		else
			if index ~= new_index then
				array[new_index] = array[index]
				array[index] = nil
			end

			new_index = new_index + 1
		end
	end
end

local function resize_line_cache(start, count)
	if count > 0 then
		table.move(buffer.elastic_tabstops.lines, start + 1, #buffer.elastic_tabstops.lines, start + 1 + count)
	elseif count < 0 then
		array_remove(buffer.elastic_tabstops.lines, start, -count)
	end
end

local function search_boundary(start_line, reverse)
	local stop_line = reverse and 1 or buffer.line_count
	local step = reverse and -1 or 1
	local boundary_line = start_line
	local max_cell_count = 0

	for line = start_line + step, stop_line, step do
		if not buffer.elastic_tabstops.lines[line] then
			break
		end
		boundary_line = line
		max_cell_count = math.max(max_cell_count, buffer.elastic_tabstops.lines[line].cell_count)
	end

	return boundary_line, max_cell_count
end

local function assign_column_blocks(start_line, stop_line, max_cell_count)
	local lines = buffer.elastic_tabstops.lines
	local block_widths = buffer.elastic_tabstops.block_widths

	for column = 1, max_cell_count do
		local start_new_block = true
		for line = start_line, stop_line do
			if lines[line] and lines[line].cell_count >= column then
				if start_new_block then
					block_index = column*2^16 + line
					block_widths[block_index] = 0
					start_new_block = false
				end

				block_widths[block_index] = math.max(block_widths[block_index], lines[line].cell_widths[column])
				lines[line].cell_blocks[column] = block_index
			else
				start_new_block = true
			end
		end
	end
end

local function set_tabstops(start_line, stop_line)
	local lines = buffer.elastic_tabstops.lines
	local block_widths = buffer.elastic_tabstops.block_widths

	for line = start_line, stop_line do
		if lines[line] then
			buffer:clear_tab_stops(line)
			buffer.elastic_tabstops.tabstops[line] = {}
			local tabstop = 0

			for cell, block in ipairs(lines[line].cell_blocks) do
				local cell_width = math.max(buffer.elastic_tabstops.min_width, block_widths[block] + buffer.elastic_tabstops.padding)
				tabstop = tabstop + cell_width
				buffer:add_tab_stop(line, tabstop)
				buffer.elastic_tabstops.tabstops[line][cell] = tabstop
			end
		end
	end
end

local function restore_tabstops()
	for line_number, line in pairs(buffer.elastic_tabstops.tabstops) do
		for _, tabstop in pairs(line) do
			buffer:add_tab_stop(line_number, tabstop)
		end
	end
end

events.connect(events.MODIFIED, function(position, mod, text, length)
	local inserted = mod & buffer.MOD_INSERTTEXT > 0
	local deleted = mod & buffer.MOD_DELETETEXT > 0

	if not (inserted or deleted) then
		return
	end

	local line = position and buffer:line_from_position(position)
	local added_lines = text and select(2, text:gsub("\n", ""))
	added_lines = deleted and added_lines*-1 or added_lines

	if buffer.elastic_tabstops == nil then
		char_width = buffer:text_width(buffer.STYLE_DEFAULT, "n")
		buffer.elastic_tabstops = {
			min_width = buffer.tab_width*char_width,
			padding = buffer.tab_width*char_width/2,
			lines = {},
			block_widths = {},
			tabstops = {}
		}
	end

	-- If first/last line of modified/deleted range contained tabstops, they were possibly connected with adjacent blocks, which means adjacent lines need to be updated later
	local extend_up = buffer.elastic_tabstops.lines[line] ~= nil
	local extend_down = added_lines < 0 and (buffer.elastic_tabstops.lines[line - added_lines] ~= nil) or extend_up

	if added_lines ~= 0 and buffer.elastic_tabstops.lines then
		resize_line_cache(line, added_lines)
	end

	local first_line = line
	local last_line = line + (added_lines > 0 and added_lines or 0)
	local max_cell_count = 0
	local cell_count = 0

	for line = first_line, last_line do
		cell_count = scan_line(line)

		if cell_count > 0 then
			max_cell_count = math.max(max_cell_count, cell_count)

			if line == first_line then
				extend_up = true
			end

			if line == last_line then
				extend_down = true
			end
		end
	end

	if extend_up then
		first_line, cell_count = search_boundary(first_line, true)
		max_cell_count = math.max(max_cell_count, cell_count)
	end

	if extend_down then
		last_line, cell_count = search_boundary(last_line, false)
		max_cell_count = math.max(max_cell_count, cell_count)
	end

	if max_cell_count > 0 then
		assign_column_blocks(first_line, last_line, max_cell_count)
		set_tabstops(first_line, last_line)
	end
end)

events.connect(events.BUFFER_AFTER_SWITCH, function()
	if buffer.elastic_tabstops then
		restore_tabstops()
	end
end)

return M
