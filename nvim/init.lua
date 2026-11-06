-- cspell:disable
vim.g.mapleader = " "

vim.keymap.set({'n', 'v'}, 'y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set({'n', 'v'}, 'Y', '"+y$', { desc = 'Yank to end of line to system clipboard' })
vim.keymap.set({'n', 'v'}, 'p', '"+p', { desc = 'Paste from system clipboard' })
vim.keymap.set({'n', 'v'}, 'P', '"+P', { desc = 'Paste before from system clipboard' })

-- У Visual mode копіюємо через VS Code, щоб працювало з кількома курсорами
vim.keymap.set('x', 'y', '<cmd>call VSCodeCall("editor.action.clipboardCopyAction")<CR><Esc>', { desc = 'Yank (multi-cursor safe)' })

-- Обгортання виділеного тексту в () без перенесення на новий рядок
local function wrap_selection()
    vim.cmd('normal! "ad')
    local text = vim.fn.getreg('a'):gsub('[\r\n]+$', '')
    vim.fn.setreg('a', '(' .. text .. ')', 'v')
    vim.cmd('normal! "aP')
end

-- Огортає кожне слово у виділенні в "" і ставить кому після нього
local function quote_words()
    local mode = vim.fn.mode()
    local p1 = vim.fn.getpos('v')
    local p2 = vim.fn.getpos('.')

    local text = table.concat(vim.fn.getregion(p1, p2, { type = mode }), '\n')
    if text:find('[^%w_%s,]') then
        vim.notify('quote_words: у виділенні не лише слова', vim.log.levels.WARN)
        return
    end

    local out = {}
    for word in text:gmatch('[%w_]+') do
        table.insert(out, '"' .. word .. '",')
    end
    if #out == 0 then return end

    -- Початок і кінець виділення (початок має бути раніше за кінець)
    local s_row, s_col = p1[2] - 1, p1[3] - 1
    local e_row, e_col = p2[2] - 1, p2[3] - 1
    if s_row > e_row or (s_row == e_row and s_col > e_col) then
        s_row, e_row = e_row, s_row
        s_col, e_col = e_col, s_col
    end

    local last_line = vim.api.nvim_buf_get_lines(0, e_row, e_row + 1, false)[1]
    if mode == 'V' then
        s_col = 0
        e_col = #last_line
    else
        e_col = math.min(e_col + 1, #last_line)
    end

    vim.api.nvim_buf_set_text(0, s_row, s_col, e_row, e_col, { table.concat(out, ' ') })
    vim.cmd('normal! \27') -- вийти з Visual mode
end
vim.keymap.set('x', '<leader>q', quote_words, { desc = 'Quote words and add commas' })

-- Склеює виділені рядки в один: filter(a=1, b=2)
local function join_to_one_line()
    local r1 = vim.fn.getpos('v')[2]
    local r2 = vim.fn.getpos('.')[2]
    if r1 > r2 then r1, r2 = r2, r1 end
    vim.cmd('normal! \27')

    local lines = vim.api.nvim_buf_get_lines(0, r1 - 1, r2, false)
    local indent = lines[1]:match('^%s*') or ''

    local parts = {}
    for _, l in ipairs(lines) do
        table.insert(parts, vim.trim(l))
    end

    local joined = table.concat(parts, ' ')
    joined = joined:gsub('([%(%[{])%s+', '%1')   -- пробіли після (
    joined = joined:gsub('%s+([%)%]}])', '%1')   -- пробіли перед )
    joined = joined:gsub(',([%)%]}])', '%1')     -- кома перед )

    vim.api.nvim_buf_set_lines(0, r1 - 1, r2, false, { indent .. joined })
end
vim.keymap.set('x', '<leader>j', join_to_one_line, { desc = 'Join lines into one' })

vim.keymap.set('x', '(', wrap_selection, { desc = 'Wrap selection in ()' })
vim.keymap.set('x', ')', wrap_selection, { desc = 'Wrap selection in ()' })

vim.keymap.set('n', '<leader>y', '<cmd>%y+<CR>', { desc = 'Copy whole file' })

-- Збереження: працює і в Normal, і в Visual mode (автоматично скидає Visual mode)
vim.keymap.set({'n', 'v'}, '<leader>s', '<cmd>call VSCodeNotify("workbench.action.files.save")<CR><Esc>', { desc = 'Save file' })

vim.keymap.set('n', '<leader>d', ':%d<CR>', { desc = 'Delete all' })
vim.keymap.set('n', '<leader>w', '<cmd>call VSCodeNotify("workbench.action.closeActiveEditor")<CR>', { desc = 'Close tab' })
vim.keymap.set('n', '<leader>u', '<cmd>call VSCodeNotify("workbench.action.reopenClosedEditor")<CR>', { desc = 'Reopen last closed editor' })
vim.keymap.set('n', '<leader>o', '<cmd>call VSCodeNotify("workbench.action.closeOtherEditors")<CR>', { desc = 'Close other tabs' })
vim.keymap.set('n', '<leader>i', 'I = <Left><Left><Left>', { desc = 'Create variable/constant at line start' })

local function wrap_expr()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    -- 1. Шукаємо крапку біля курсора
    local dot_pos = nil
    for i = col, 1, -1 do
        if line:sub(i, i) == '.' then
            dot_pos = i
            break
        end
    end

    if not dot_pos then
        dot_pos = line:find('%.', col)
    end

    if not dot_pos then return end

    -- 2. Назва функції ліворуч від крапки
    local left_part = line:sub(1, dot_pos - 1)
    local fn_name = left_part:match("([%w_]+)$")
    if not fn_name then return end
    local fn_start = dot_pos - #fn_name

    -- 3. Універсальний аналіз виразу праворуч від крапки
    local right_part = line:sub(dot_pos + 1)
    local stack = {}
    local in_string = nil
    local expr_len = 0

    for i = 1, #right_part do
        local char = right_part:sub(i, i)

        -- Обробка лапок
        if (char == '"' or char == "'") then
            if not in_string then
                in_string = char
            elseif in_string == char and right_part:sub(i - 1, i - 1) ~= '\\' then
                in_string = nil
            end
        elseif not in_string then
            -- Баланс дужок
            if char == '(' or char == '[' or char == '{' then
                table.insert(stack, char)
            elseif char == ')' or char == ']' or char == '}' then
                if #stack > 0 then
                    table.remove(stack)
                else
                    break
                end
            -- Зупиняємося на розділювачах, якщо всі дужки закриті
            elseif #stack == 0 and (char == ',' or char == ';' or char == ':' or char == '=') then
                break
            end
        end

        expr_len = i

        -- Перевірка кінця виразу: якщо дужки збалансовані, немає лапок і ДАЛІ НЕ ЙДЕ КРАПКА (для ланцюжків методів)
        if #stack == 0 and not in_string and (char == ')' or char == ']' or char == '}') then
            local next_char = right_part:sub(i + 1, i + 1)
            if next_char ~= '.' then
                break
            end
        end
    end

    local expr = right_part:sub(1, expr_len):gsub("%s+$", "")
    if #expr == 0 then return end
    local expr_end = dot_pos + #expr

    -- 4. Заміна на word(expr)
    local new_line = line:sub(1, fn_start - 1) .. fn_name .. "(" .. expr .. ")" .. line:sub(expr_end + 1)
    vim.api.nvim_set_current_line(new_line)
end

vim.keymap.set('n', '<leader>t', wrap_expr, { desc = 'Wrap word.expr into word(expr)' })

local function prepend_assign()
    local line = vim.api.nvim_get_current_line()
    local indent = line:match("^%s*") or ""
    local text = line:sub(#indent + 1)
    
    -- Вставляє " = " перед текстом рядка, зберігаючи відступи, та переходить в Insert mode
    vim.api.nvim_set_current_line(indent .. " = " .. text)
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], #indent })
    vim.cmd('startinsert')
end
vim.keymap.set('n', '<leader>a', prepend_assign, { desc = 'Prepend assignment baseline' })

-- Коментування через Ctrl+/ (або Ctrl+_) з поверненням у Normal mode
vim.keymap.set({'n', 'v'}, '<C-/>', '<cmd>call VSCodeNotify("editor.action.commentLine")<CR><Esc>', { desc = 'Toggle comment' })
vim.keymap.set({'n', 'v'}, '<C-_>', '<cmd>call VSCodeNotify("editor.action.commentLine")<CR><Esc>', { desc = 'Toggle comment' })


vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        if vim.v.event.operator == 'y' then
            vim.api.nvim_win_set_cursor(0, vim.api.nvim_buf_get_mark(0, ']'))
        end
    end,
})

vim.keymap.set('n', 'go', 'vat<Esc>o', { desc = 'Jump to end of tag and open line' })

-- Перехід у провідник (Sidebar) і назад до коду
vim.keymap.set({'n', 'v'}, '<A-e>', '<cmd>call VSCodeNotify("workbench.view.explorer")<CR>', { desc = 'Focus Explorer' })

vim.opt.shortmess:append("IacF")
vim.opt.report = 999
vim.opt.ignorecase = true
vim.opt.smartcase = true

local keys = { 'c', 'C', 'x', 's', 'S' }
for _, key in ipairs(keys) do
    vim.keymap.set({'n', 'v'}, key, '"_' .. key)
end

vim.keymap.set("x", "p", 'P')

vim.keymap.set('n', '<leader>f', '<cmd>call VSCodeNotify("workbench.action.findInFiles")<CR>', { desc = 'Global search' })