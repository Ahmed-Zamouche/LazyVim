-- toggleterm-config.lua
local utils = require("user.utils")
local docker = require("user.docker")

local status_ok, toggleterm = pcall(require, "toggleterm")
if not status_ok then
  return
end

toggleterm.setup({
  size = 20,
  open_mapping = [[<c-\>]],
  hide_numbers = true,
  shade_filetypes = {},
  shade_terminals = true,
  shading_factor = 2,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  direction = "float",
  close_on_exit = true,
  shell = vim.o.shell,
  float_opts = {
    border = "curved",
    winblend = 0,
    highlights = {
      border = "Normal",
      background = "Normal",
    },
  },
})

---@diagnostic disable-next-line: duplicate-set-field
function _G.set_terminal_keymaps()
  local opts = { noremap = true }
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "jk", [[<C-\><C-n>]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

local Terminal = require("toggleterm.terminal").Terminal

local ids = 0
local function next_id()
  local id = ids
  ids = ids + 1
  return id
end

local function get_ssh_hosts(path)
  local hosts = {}
  path = path or utils.os.path.join({ utils.os.home(), ".ssh", "config" })

  if type(path) ~= "string" then
    print("expected arg path of type 'string' actual  '" .. type(path))
    return hosts
  end

  if not utils.file_exists(path) then
    print("file '" .. path .. "' do not exist!")
    return hosts
  end

  local file = io.open(path, "r")
  if file == nil then
    print("could not open file '" .. path .. "'!")
    return hosts
  end

  local cur_host = ""
  for line in file:lines() do
    for key, value in string.gmatch(line, "%s*(%w+)%s+(.*)") do
      if key == "Host" then
        cur_host = string.lower(value)
        hosts[cur_host] = {}
        hosts[cur_host][string.lower(key)] = cur_host
      else
        hosts[cur_host][string.lower(key)] = value
      end
    end
  end

  for k, _ in pairs(hosts) do
    hosts[k].port = hosts[k].port or 22
    hosts[k].hostname = hosts[k].hostname or os.getenv("HOSTNAME")
    hosts[k].user = hosts[k].user or os.getenv("USERNAME")
    hosts[k].term = nil
  end
  hosts.current = nil
  return hosts
end

local function get_containers()
  local suc, hosts = docker.container({ cmd = "list" })
  if not suc or hosts == nil then
    return {}
  end

  for k, _ in pairs(hosts) do
    hosts[k].term = nil
  end
  hosts.current = nil
  return hosts
end

local shells = {
  float = {
    term = nil,
    size = -1,
  },
  vertical = {
    term = nil,
    size = 80,
  },
  horizontal = {
    term = nil,
    size = 20,
  },
}

function TermToggleShell(direction)
  direction = direction or "float"
  if shells[direction].term == nil then
    shells[direction].term = Terminal:new({
      id = next_id(),
      display_name = vim.o.shell .. ":" .. direction,
      cmd = vim.o.shell,
      direction = direction,
      hidden = true,
    })
  end
  shells[direction].term:toggle(shells[direction].size, direction)
end

local lazygit = nil
function TermToggleLazyGit()
  if lazygit == nil then
    lazygit = Terminal:new({ id = next_id(), display_name = "lazygit", cmd = "lazygit", hidden = true })
  end
  lazygit:toggle()
end

local lua = nil
function TermToggleLua()
  if lua == nil then
    lua = Terminal:new({ id = next_id(), display_name = "Lua", cmd = "lua", hidden = true })
  end
  lua:toggle()
end

local node = nil
function TermToggleNode()
  if node == nil then
    node = Terminal:new({ id = next_id(), display_name = "Node", cmd = "node", hidden = true })
  end
  node:toggle()
end

local python = nil
function TermTogglePython()
  if python == nil then
    python = Terminal:new({ id = next_id(), display_name = "Python", cmd = "python3", hidden = true })
  end
  python:toggle()
end

local serial = nil
function TermToggeleSerial(device, baudrate)
  local d = device or "/dev/ttyUSB0"
  local b = baudrate or 115200
  local cmd = "picocom -rl -b " .. b .. " " .. d
  if serial == nil then
    serial = Terminal:new({ id = next_id(), display_name = "serial", cmd = cmd, hidden = true })
  end
  serial:toggle()
end

local top = nil
function TermToggeleTop()
  if top == nil then
    top = Terminal:new({ id = next_id(), display_name = "top", cmd = "btop", hidden = true })
  end
  top:toggle()
end

local ssh_hosts = { items = get_ssh_hosts(), selected = nil }
function TermSelectSsh()
  vim.ui.select(utils.get_keys(ssh_hosts.items), {
    prompt = "Select a host:",
  }, function(choice)
    local host = ssh_hosts.items[choice]
    if host ~= nil then
      if host.term == nil then
        host.term = Terminal:new({
          id = next_id(),
          display_name = "ssh://" .. host.user .. "@" .. host.hostname .. ":" .. host.port,
          cmd = "ssh " .. host.user .. "@" .. host.hostname .. " -p" .. host.port,
          hidden = true,
        })
      end
      host.term:open()
      ssh_hosts.selected = host
    end
  end)
end

function TermToggleSsh()
  if ssh_hosts.selected ~= nil then
    ssh_hosts.selected.term:toggle()
  else
    TermSelectSsh()
  end
end

local containers = { items = get_containers(), selected = nil }
function TermSelectContainer()
  local names = {}
  for _, v in pairs(containers.items) do
    table.insert(names, v.Names)
  end
  vim.ui.select(names, {
    prompt = "Select a container:",
  }, function(choice)
    local container = nil
    for _, v in pairs(containers.items) do
      if v.Names == choice then
        container = v
      end
    end

    if container ~= nil then
      if container.term == nil then
        container.term = Terminal:new({
          id = next_id(),
          display_name = "container://" .. container.Image,
          cmd = "docker start " .. container.ID .. " && docker attach " .. container.ID,
          hidden = true,
        })
      end
      container.term:open()
      containers.selected = container
    end
  end)
end

function TermToggleContainer()
  if containers.selected ~= nil then
    containers.selected.term:toggle()
  else
    TermSelectContainer()
  end
end
