local M = {}

local state = {
  buf = nil,
  closing = false,
  filetype_augroup = vim.api.nvim_create_augroup('cargo-popup-filetype', { clear = true }),
  job = nil,
  popup_augroup = vim.api.nvim_create_augroup('cargo-popup', { clear = true }),
  running = false,
  win = nil,
}

local cargo_subcommands = {
  'build',
  'run',
  'test',
  'check',
  'clippy',
  'fmt',
  'doc',
  'bench',
  'clean',
  'update',
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'Cargo' })
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function current_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= '' then
    local stat = vim.uv.fs_stat(name)
    if stat and stat.type == 'directory' then
      return name
    end
    if stat and stat.type == 'file' then
      return vim.fs.dirname(name)
    end
  end

  return vim.uv.cwd()
end

local function cargo_root()
  local manifest = vim.fs.find('Cargo.toml', { path = current_dir(), upward = true })[1]
  return manifest and vim.fs.dirname(manifest) or nil
end

local function popup_dimensions()
  local columns = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local max_width = math.max(1, columns - 4)
  local max_height = math.max(1, lines - 4)
  local width = math.min(math.max(20, math.floor(columns * 0.85)), max_width)
  local height = math.min(math.max(8, math.floor(lines * 0.75)), max_height)

  return {
    col = math.floor((columns - width) / 2),
    height = height,
    row = math.floor((lines - height) / 2),
    width = width,
  }
end

local function set_title(title)
  if not valid_win(state.win) then
    return
  end

  pcall(vim.api.nvim_win_set_config, state.win, {
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })
end

local function stop_job()
  if state.job and state.running then
    pcall(vim.api.nvim_chan_send, state.job, '\003')
    pcall(vim.fn.jobstop, state.job)
  end

  state.job = nil
  state.running = false
end

function M.close()
  if state.closing then
    return
  end

  state.closing = true
  stop_job()

  local win = state.win
  local buf = state.buf
  state.win = nil
  state.buf = nil

  if valid_win(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if valid_buf(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  state.closing = false
end

local function open_popup(title)
  local dim = popup_dimensions()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'cargo_popup'
  vim.bo[buf].swapfile = false

  local win = vim.api.nvim_open_win(buf, true, {
    border = 'rounded',
    col = dim.col,
    height = dim.height,
    relative = 'editor',
    row = dim.row,
    style = 'minimal',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
    width = dim.width,
  })

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false

  state.buf = buf
  state.win = win
  vim.api.nvim_clear_autocmds { group = state.popup_augroup }

  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.popup_augroup,
    pattern = tostring(win),
    once = true,
    callback = function()
      vim.schedule(function()
        if state.win == win or state.buf == buf then
          M.close()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = state.popup_augroup,
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if state.buf == buf then
          M.close()
        end
      end)
    end,
  })

  vim.keymap.set('n', 'q', M.close, { buffer = buf, desc = 'Close cargo popup' })
  vim.keymap.set({ 'n', 't' }, '<C-q>', M.close, { buffer = buf, desc = 'Close cargo popup' })

  return buf
end

---@param args string[]
function M.run(args)
  if vim.fn.executable 'cargo' ~= 1 then
    notify('cargo is not available on PATH', vim.log.levels.ERROR)
    return
  end

  local root = cargo_root()
  if not root then
    notify('No Cargo.toml found above the current buffer', vim.log.levels.WARN)
    return
  end

  M.close()

  local command = #args > 0 and args or { 'cargo', 'build' }
  local title = table.concat(command, ' ')
  local buf = open_popup(title)
  local job_id

  vim.api.nvim_buf_call(buf, function()
    job_id = vim.fn.termopen(command, {
      cwd = root,
      on_exit = function(_, code)
        vim.schedule(function()
          if state.job ~= job_id then
            return
          end

          state.job = nil
          state.running = false
          set_title(code == 0 and title .. ' - done' or title .. ' - exit ' .. code)
          vim.cmd.checktime()
        end)
      end,
    })
  end)

  if job_id <= 0 then
    notify('Failed to start ' .. title, vim.log.levels.ERROR)
    M.close()
    return
  end

  state.job = job_id
  state.running = true
  vim.cmd.startinsert()
end

local function with_extra_args(base, extra)
  local args = vim.deepcopy(base)
  vim.list_extend(args, extra)
  return args
end

local function complete_cargo(arg_lead, cmdline)
  if not cmdline:match '^%s*Cargo%s+%S*$' then
    return {}
  end

  return vim.tbl_filter(function(command)
    return vim.startswith(command, arg_lead)
  end, cargo_subcommands)
end

local function cargo_command(opts)
  M.run(with_extra_args({ 'cargo' }, opts.fargs))
end

local function build_command(opts)
  M.run(with_extra_args({ 'cargo', 'build' }, opts.fargs))
end

local function run_command(opts)
  M.run(with_extra_args({ 'cargo', 'run' }, opts.fargs))
end

local function test_command(opts)
  M.run(with_extra_args({ 'cargo', 'test' }, opts.fargs))
end

local cargo_command_opts = {
  complete = complete_cargo,
  desc = 'Run a cargo command in a popup',
  force = true,
  nargs = '*',
}

vim.api.nvim_create_user_command('Cargo', cargo_command, cargo_command_opts)

vim.api.nvim_create_user_command('CargoStop', M.close, {
  desc = 'Stop the running cargo popup command',
  force = true,
})

vim.keymap.set('n', '<leader>cb', '<cmd>Cargo build<CR>', { desc = 'Cargo build' })
vim.keymap.set('n', '<leader>cr', '<cmd>Cargo run<CR>', { desc = 'Cargo run' })
vim.keymap.set('n', '<leader>ct', '<cmd>Cargo test<CR>', { desc = 'Cargo test' })
vim.keymap.set('n', '<leader>cx', '<cmd>CargoStop<CR>', { desc = 'Stop cargo command' })

vim.api.nvim_create_autocmd('FileType', {
  group = state.filetype_augroup,
  pattern = 'rust',
  callback = function(event)
    vim.api.nvim_buf_create_user_command(event.buf, 'Cargo', cargo_command, cargo_command_opts)
    vim.api.nvim_buf_create_user_command(event.buf, 'Cbuild', build_command, {
      desc = 'Run cargo build in a popup',
      force = true,
      nargs = '*',
    })
    vim.api.nvim_buf_create_user_command(event.buf, 'Crun', run_command, {
      desc = 'Run cargo run in a popup',
      force = true,
      nargs = '*',
    })
    vim.api.nvim_buf_create_user_command(event.buf, 'Ctest', test_command, {
      desc = 'Run cargo test in a popup',
      force = true,
      nargs = '*',
    })
  end,
})

return M
