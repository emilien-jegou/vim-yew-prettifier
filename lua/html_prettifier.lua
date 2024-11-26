function generatePrettifiedHTMLInner(node, indentLevel, indentSpaces)
    indentLevel = indentLevel or 0
    indentSpaces = indentSpaces or 2 -- Default indentation is two spaces
    local indent = string.rep(" ", indentLevel)
    local html = ""
    local wasInlined = false;

    if node.type == "Root" then
        -- Process the children of the root node
        for _, child in ipairs(node.children) do
            local res = generatePrettifiedHTMLInner(child, indentLevel, indentSpaces)
            local childHTML = res[1]
            local childWasInlined = res[2]
            html = html .. childHTML
            wasInlined = childWasInlined
        end
    elseif node.type == "Tag" then
        local tagName = node.name or ""
        local raw = node.raw or ""
        local isSelfClosing = node.isSelfClosing

        -- Opening tag
        local openingTag = "<" .. tagName
        if raw ~= "" then
            openingTag = openingTag .. " " .. raw
        end

        if isSelfClosing then
            -- Self-closing tag
            html = html .. indent .. openingTag .. " /" .. ">\n"
        else
            openingTag = openingTag .. ">"
            local childrenHTML = {}
            local totalInlineWidth = #openingTag -- Start with the opening tag length
            local forceBlock = false

            -- Process children and calculate total width
            for _, child in ipairs(node.children) do
                local res = generatePrettifiedHTMLInner(child, indentLevel + indentSpaces, indentSpaces)
                local childHTML = res[1]:gsub("^%s+", ""):gsub("%s+$", "")
                local childWasInlined = res[2]
                table.insert(childrenHTML, childHTML)

                wasInlined = true
                if childWasInlined then
                    forceBlock = true
                end

                -- Check if any child spans multiple lines
                if childHTML:find("\n") then
                    forceBlock = true
                end

                -- Update inline width calculation
                totalInlineWidth = totalInlineWidth + #childHTML + 1 -- +1 for spaces between inline elements
            end

            local closingTag = "</" .. tagName .. ">"
            totalInlineWidth = totalInlineWidth + #closingTag -- Add the closing tag length

            -- Inline or block format
            if not forceBlock then
                html = html ..
                    indent .. openingTag .. " " .. table.concat(childrenHTML, " ") .. " " .. closingTag .. "\n"
            else
                html = html .. indent .. openingTag .. "\n"
                for _, childHTML in ipairs(childrenHTML) do
                    html = html .. string.rep(" ", indentLevel + indentSpaces) .. childHTML .. "\n"
                end
                html = html .. indent .. closingTag .. "\n"
            end
        end
    elseif node.type == "Fragment" then
        -- Handle fragment nodes
        local fragmentChildren = {}
        local totalInlineWidth = 2 -- Account for `<>` and `</>`
        local forceBlock = false

        for _, child in ipairs(node.children) do
            local res = generatePrettifiedHTMLInner(child, indentLevel + indentSpaces, indentSpaces)
            local childHTML = res[1]:gsub("^%s+", ""):gsub("%s+$", "")
            local childWasInlined = res[2]
            table.insert(fragmentChildren, childHTML)

            wasInlined = true

            -- Check if any child spans multiple lines
            if childHTML:find("\n") or childWasInlined == true then
                forceBlock = true
            end

            -- Update inline width calculation
            totalInlineWidth = totalInlineWidth + #childHTML + 1
        end

        if not forceBlock then
            wasInlined = true
            html = html .. indent .. "<> " .. table.concat(fragmentChildren, " ") .. " </>\n"
        else
            html = html .. indent .. "<>\n"
            for _, childHTML in ipairs(fragmentChildren) do
                -- Fix indentation logic for children
                html = html .. string.rep(" ", indentLevel + indentSpaces) .. childHTML .. "\n"
            end
            html = html .. indent .. "</>\n"
        end
    elseif node.type == "Text" then
        -- Note: we could technically reindent inner block of code but
        -- I decided not to as it could break nested string literal
        if node.raw ~= "" then
            local textContent = node.raw:gsub("^%s+", ""):gsub("%s+$", "")
            html = html .. indent .. textContent .. "\n"
        end
    elseif node.type == "Comment" then
        -- Preserve comment nodes
        html = html .. indent .. node.raw .. "\n"
    end

    return { html, wasInlined }
end

function generatePrettifiedHTML(node, indentLevel, indentSpaces)
    local res = generatePrettifiedHTMLInner(node, indentLevel, indentSpaces)
    return res[1]
end

return generatePrettifiedHTML
