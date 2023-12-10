local weather = require("user.weather")
weather.async_request({ city = "Stockholm" })

return {
  -- the opts function can also be used to change the default opts:
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, function()
        return string.gsub(weather.summary(), "%%", "%%%%")
      end)
    end,
  },
}
