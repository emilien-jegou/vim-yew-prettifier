local function vim_funcs_module(deps)
    local parser = deps.parser
    local generatePrettifiedHTML = deps.generatePrettifiedHTML
    local config = deps.config

    local function trim(s)
        return s:match("^%s*(.-)%s*$")
    end

    local function prettify_selection(start_line, end_line)
        if not start_line or not end_line or start_line < 1 or end_line < start_line then
            vim.notify(
                string.format("Invalid line range: start_line=%s, end_line=%s", tostring(start_line), tostring(end_line)),
                vim.log.levels.ERROR
            )
            return
        end


        -- Adjust for 0-based indexing required by Neovim API
        local start_idx = start_line - 1
        local end_idx = end_line


        -- Get the lines from the buffer
        local lines = vim.api.nvim_buf_get_lines(0, start_idx, end_idx, false)
        if not lines or #lines == 0 then
            vim.notify("No lines found in the specified range.", vim.log.levels.WARN)
            return
        end

        local input = table.concat(lines, "\n")

        -- Parse and prettify
        local success, ast = pcall(parser, input)
        if not success or not ast then
            vim.notify("Failed to parse HTML in the specified range. Skipping prettification.", vim.log.levels.ERROR)
            return
        end

        -- Determine the current indent level (number of spaces) of the first line
        local first_line = vim.api.nvim_buf_get_lines(0, start_idx, start_idx + 1, false)[1] or ""
        local current_indent = #first_line:match("^%s*") -- Match leading spaces and count their length

        local prettifiedHTML = generatePrettifiedHTML(ast, current_indent, config.tab_size)

        if prettifiedHTML and prettifiedHTML ~= "" then
            -- Split prettified HTML into lines
            local prettified_lines = vim.fn.split(prettifiedHTML, "\n")

            -- Replace the original range with prettified lines
            vim.api.nvim_buf_set_lines(0, start_idx, end_idx, false, prettified_lines)

            -- Move the cursor to the start of the replaced range
            vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        else
            vim.notify("Prettified HTML is empty. Skipping replacement.", vim.log.levels.WARN)
        end
    end

    local function find_html_block_start()
        -- Save the current cursor position
        local initial_cursor = vim.fn.getpos(".")
        local pattern = "html! *{"

        -- Search for the pattern `html! {` starting at the current cursor position
        local start_line, start_col = nil, nil
        local match_found = vim.fn.searchpos(pattern, "nW")

        if match_found[1] ~= 0 then
            -- Match found: extract line and column
            start_line = match_found[1]
            start_col = match_found[2]
        else
            -- No match from current position, search from the beginning
            vim.cmd("normal! gg") -- Move to the beginning of the file
            match_found = vim.fn.searchpos(pattern, "nW")
            if match_found[1] ~= 0 then
                start_line = match_found[1]
                start_col = match_found[2]
            end
        end

        -- Restore initial cursor if no match was found
        if not start_line or not start_col then
            vim.fn.setpos(".", initial_cursor)
            vim.notify("No `html!` block found in current file", vim.log.levels.ERROR)
            return nil
        end

        -- Calculate the number of leading whitespaces (indentation)
        local line_content = vim.fn.getline(start_line)
        local indent_start = #line_content:match("^%s*") -- Match leading whitespace

        -- Restore the cursor position and return the results
        vim.fn.setpos(".", initial_cursor)
        return start_line, start_col, indent_start
    end

    local function prettify_lookahead()
        -- Find the starting position of the `html!` block
        local start_line, start_col, indent_start = find_html_block_start()
        if not start_line or not start_col or not indent_start then
            return
        end

        -- Move the cursor to the start of the `{` character
        local current_line = vim.fn.getline(start_line)
        local open_brace_col = current_line:find("{", start_col)
        vim.fn.cursor(start_line, open_brace_col)
        local cursor_pos = vim.api.nvim_win_get_cursor(0)

        -- Check if both `{` and `}` are on the same line
        -- `{` and `}` are on the same line, use feedkeys to replace content
        vim.cmd("normal! vi{") -- Visually select the inner block
        vim.cmd('normal! "vy') -- Yank the selected block into register 'v'

        -- Get the yanked content
        local block_content = vim.fn.getreg("v")

        -- If the html block is empty then "vi{" will capture the external bracket,
        -- we can just skip further processing when that's the case
        if block_content == "{" then
            return
        end

        -- Process the content (e.g., prettify)
        local success, ast = pcall(parser, block_content)
        if not success or not ast then
            vim.notify("Failed to parse HTML block", vim.log.levels.ERROR)
            return
        end

        local prettified_html = generatePrettifiedHTML(ast, indent_start + config.tab_size, config.tab_size)

        local trimmed = trim(prettified_html)
        if prettified_html and #trimmed ~= 0 then
            local indent_s = string.rep(" ", indent_start)
            local inlined_total_width = cursor_pos[2] + 4 + #trimmed
            local textwidth = vim.bo.textwidth
            local wrap_width

            if config.max_line_width ~= nil then
                wrap_width = config.max_line_width
            elseif textwidth > 0 then
                wrap_width = textwidth
            else
                wrap_width = vim.api.nvim_win_get_width(0)
            end

            -- Check if the html block can be inlined by looking at the word wrap limit
            if inlined_total_width < wrap_width and not trimmed:find('\n') then
                prettified_html = '{ ' .. trimmed .. ' }'
            else
                prettified_html = '{\n' .. prettified_html .. indent_s .. '}'
            end

            vim.fn.setreg('"', prettified_html)

            -- NOTE: This code handle cases where there is trailing character
            -- such as a comma after the block e.g. 'html! {..}' vs 'html! {..},'
            vim.cmd([[
              normal! "_da{
              if getline('.')[col('.') - 1] =~ '\s'
                  normal! p
              else
                  normal! P
              endif
          ]])

            vim.notify("HTML block prettified successfully", vim.log.levels.INFO)
        else
            vim.notify("Prettified HTML block is empty", vim.log.levels.WARN)
        end
    end

    return prettify_selection, prettify_lookahead
end

return vim_funcs_module
