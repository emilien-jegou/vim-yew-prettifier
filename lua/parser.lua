-- Define a function to create AST nodes
local function createNode(type, name, raw)
    return { type = type, name = name or "", raw = raw or "", children = {} }
end

-- The main parser function
function parser(input)
    local index = 1
    local length = #input
    local root = createNode("Root", nil)
    local stack = { root }
    local current = root
    local insideString = false
    local stringChar = nil -- Tracks the type of string: single or double quotes

    while index <= length do
        local char = input:sub(index, index)
        local nextChar = input:sub(index + 1, index + 1)
        local nextTwoChars = input:sub(index, index + 1)

        if insideString then
            -- Track string content, including escapes
            if char == stringChar and input:sub(index - 1, index - 1) ~= '\\' then
                insideString = false
                stringChar = nil
            end
            index = index + 1
        elseif char == '"' or char == "'" then
            -- Enter a string
            insideString = true
            stringChar = char
            index = index + 1
        elseif char == '<' then
            if nextTwoChars == '</' then
                -- Closing tag
                index = index + 2
                local closeTagName = ""
                while index <= length and input:sub(index, index) ~= '>' do
                    closeTagName = closeTagName .. input:sub(index, index)
                    index = index + 1
                end
                index = index + 1 -- Skip '>'
                table.remove(stack)
                current = stack[#stack]
            elseif nextChar == '>' then
                -- Opening fragment '<>'
                index = index + 2 -- Skip '<>'
                local node = createNode("Fragment", nil)
                table.insert(current.children, node)
                table.insert(stack, node)
                current = node
            else
                -- Opening or self-closing tag
                index = index + 1
                local tagName = ""
                local bracketCount = 0

                while index <= length do
                    local c = input:sub(index, index)
                    if c == '<' then
                        bracketCount = bracketCount + 1
                    elseif c == '>' then
                        if bracketCount > 0 then
                            bracketCount = bracketCount - 1
                        else
                            break
                        end
                    elseif c:match("[%s/]") and bracketCount == 0 then
                        break
                    end
                    tagName = tagName .. c
                    index = index + 1
                end

                -- Skip whitespace between tag name and attributes
                while index <= length and input:sub(index, index):match("%s") do
                    index = index + 1
                end

                -- Parse attributes or raw content
                local rawStart = index
                local rawEnd = index - 1
                local isSelfClosing = false
                local raw = ""
                local angleBracketCount = 0

                while index <= length do
                    local c = input:sub(index, index)
                    local nextC = input:sub(index + 1, index + 1)

                    if c == '"' or c == "'" then
                        -- Toggle string state inside attributes
                        if insideString then
                            if c == stringChar and input:sub(index - 1, index - 1) ~= '\\' then
                                insideString = false
                                stringChar = nil
                            end
                        else
                            insideString = true
                            stringChar = c
                        end
                    elseif not insideString then
                        if c == '/' and nextC == '>' then
                            isSelfClosing = true
                            rawEnd = index - 1
                            index = index + 2 -- Skip '/>'
                            break
                        elseif c == '>' then
                            rawEnd = index - 1
                            index = index + 1 -- Skip '>'
                            break
                        end
                    end

                    raw = raw .. c
                    index = index + 1
                end

                local node = createNode("Tag", tagName, raw:gsub("%s+$", ""))
                node.isSelfClosing = isSelfClosing
                table.insert(current.children, node)

                if not isSelfClosing then
                    table.insert(stack, node)
                    current = node
                end
            end
        elseif char == '{' then
            -- Parse text node including braces
            local braceCount = 1
            local textContent = '{'
            index = index + 1
            while index <= length and braceCount > 0 do
                local c = input:sub(index, index)
                if c == '{' and not insideString then
                    braceCount = braceCount + 1
                elseif c == '}' and not insideString then
                    braceCount = braceCount - 1
                elseif (c == '"' or c == "'") and not insideString then
                    insideString = true
                    stringChar = c
                elseif c == stringChar and insideString and input:sub(index - 1, index - 1) ~= '\\' then
                    insideString = false
                    stringChar = nil
                end
                textContent = textContent .. c
                index = index + 1
            end
            textContent = textContent:gsub("^%s*(.-)%s*$", "%1")
            local node = createNode("Text", nil, textContent)
            table.insert(current.children, node)
        elseif nextTwoChars == '/*' then
            -- Parse comment
            index = index + 2
            local commentContent = ''
            while index <= length and input:sub(index, index + 1) ~= '*/' do
                commentContent = commentContent .. input:sub(index, index)
                index = index + 1
            end
            index = index + 2 -- Skip '*/'
            local node = createNode("Comment", nil, '/*' .. commentContent .. '*/')
            table.insert(current.children, node)
        else
            -- Skip over any text outside of '{...}'
            while index <= length do
                local c = input:sub(index, index)
                local nextTwo = input:sub(index, index + 1)
                if c == '<' or c == '{' or nextTwo == '/*' or nextTwo == '</' then
                    break
                else
                    index = index + 1
                end
            end
        end
    end

    return root
end

return parser
