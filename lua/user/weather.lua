local json = require("thirdparty.json.json")

local M = {
  -- Global constant for the OpenWeatherMap API key
  API_KEY = os.getenv("OPEN_WEATHER_API_KEY"),
  icons = {
    ["01"] = "☀️",
    ["02"] = "🌤️",
    ["03"] = "🌥️",
    ["04"] = "☁️",
    ["09"] = "🌧️",
    ["10"] = "🌦️",
    ["11"] = "🌩️",
    ["13"] = "🌨️",
    ["50"] = "🌫️",
  },
  data = nil,
  city = "Stockholm",
}

function M.async_request(args)
  local uv = vim.loop

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  if not stdout or not stderr then
    return nil
  end

  M.data = nil
  args = args or {}
  M.city = args.city or "Stockholm"
  M.lat = args.lat or nil
  M.lon = args.lon or nil

  if M.lat ~= nil and M.lon ~= nil then
    M.city = nil
  end
  M.units = args.units or "metric"
  M.lang = args.lang or "en"

  local options = {
    args = {
      "--silent",
      "--get",
      "--header",
      "Accept: application/json",
      "http://api.openweathermap.org/data/2.5/weather",
      "--data-urlencode",
      string.format("lang=%s", M.lang),
      "--data-urlencode",
      string.format("units=%s", M.units),
      "--data-urlencode",
      string.format("appid=%s", M.API_KEY),
    },
    stdio = { nil, stdout, nil },
  }
  if M.city ~= nil then
    table.insert(options.args, "--data-urlencode")
    table.insert(options.args, string.format("q=%s", M.city))
  else
    table.insert(options.args, "--data-urlencode")
    table.insert(options.args, string.format("lat=%s", M.lat))
    table.insert(options.args, "--data-urlencode")
    table.insert(options.args, string.format("lon=%s", M.lon))
  end

  ---@diagnostic disable-next-line: lowercase-global
  handle, pid = uv.spawn("curl", options, function()
    stdout:read_stop()
    stdout:close()
    handle:close()
  end)

  local s = ""
  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      s = s .. data
    else
      local suc, res = pcall(function()
        return json.decode(s)
      end)
      if suc then
        M.data = res
      end
    end
  end)
end

function M.icon()
  if M.data then
    return M.icons[M.data.weather[1].icon:sub(1, 2)]
  else
    return " "
  end
end

function M.temp()
  if M.data then
    return math.round(M.data.main.temp)
  else
    return nil
  end
end

function M.humidity()
  if M.data then
    return M.data.main.humidity
  else
    return nil
  end
end

function M.description()
  if M.data then
    return M.data.weather[1].description
  else
    return nil
  end
end
function M.summary()
  return string.format("%s°C🌡️%s%%💧%s", tostring(M.temp()), tostring(M.humidity()), M.icon())
end

function math.round(num, decimals)
  decimals = math.pow(10, decimals or 0)
  num = num * decimals
  if num >= 0 then
    num = math.floor(num + 0.5)
  else
    num = math.ceil(num - 0.5)
  end
  return num / decimals
end

return M
