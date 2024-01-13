-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("user.toggleterm")
require("user.csearchpath")
require("user.weather")

if vim.loop.os_uname().sysname == "Windows_NT" then
  vim.opt.shell = "powershell"
  vim.opt.shellcmdflag = "-command"
  vim.opt.shellquote = '"'
  vim.opt.shellxquote = ""
end
