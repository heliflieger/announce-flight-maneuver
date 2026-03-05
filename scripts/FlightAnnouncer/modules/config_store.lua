-- Flight Announcer
-- Author: info
-- License: See LICENSE file (c) 2026

local M = {}

local has_lfs, lfs = pcall(require, "lfs")

local function serialize_value(val, indent)
  indent = indent or ""
  if type(val) == "string" then
    return string.format("%q", val)
  end
  if type(val) == "number" or type(val) == "boolean" then
    return tostring(val)
  end
  if type(val) == "table" then
    local parts = {}
    table.insert(parts, "{\n")
    local new_indent = indent .. "  "
    for k, v in pairs(val) do
      if type(k) == "number" then
        table.insert(parts, new_indent .. serialize_value(v, new_indent) .. ",\n")
      else
        table.insert(parts, new_indent .. "[" .. serialize_value(k, new_indent) .. "] = " .. serialize_value(v, new_indent) .. ",\n")
      end
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts)
  end
  return "nil"
end

local function deep_copy(orig)
  if type(orig) ~= "table" then
    return orig
  end
  local copy = {}
  for key, value in pairs(orig) do
    copy[deep_copy(key)] = deep_copy(value)
  end
  return copy
end

function M.new(ctx)
  local config = ctx.config
  local constants = ctx.constants

  local api = {}

  function api.ensureDir()
    if os and type(os.mkdir) == "function" then
      pcall(os.mkdir, config.dir)
      pcall(os.mkdir, constants.USER_AUDIO_DIR)
    end
  end

  function api.getAvailable()
    local configs = {}

    if has_lfs and lfs and lfs.attributes and lfs.dir then
      if lfs.attributes(config.dir, "mode") == "directory" then
        for file in lfs.dir(config.dir) do
          if file:match("%.user$") and file ~= "active.user" then
            table.insert(configs, (file:gsub("%.user$", "")))
          end
        end
      end
    elseif system and system.listFiles then
      local ok, files = pcall(system.listFiles, config.dir)
      if ok and type(files) == "table" then
        for _, file in ipairs(files) do
          if type(file) == "string" and file:match("%.user$") and file ~= "active.user" then
            table.insert(configs, (file:gsub("%.user$", "")))
          end
        end
      end
    end

    if #configs == 0 and ctx.file_exists(config.dir .. "/default.user") then
      table.insert(configs, "default")
    end

    table.sort(configs)
    return configs
  end

  function api.load(name)
    local path = config.dir .. "/" .. name .. ".user"
    local chunk, err = loadfile(path)
    if not chunk then
      ctx.log_line("Error loading config " .. path .. ": " .. tostring(err))
      return nil
    end

    local success, data = pcall(chunk)
    if not success then
      ctx.log_line("Error executing config " .. path)
      return nil
    end

    return ctx.normalize_cfg(data)
  end

  function api.save_active_state(name)
    local active_name = ctx.sanitize_config_name(name)

    local file, err = io.open(constants.APP_STATE_PATH, "w")
    if not file then
      ctx.log_line("Active-state save failed: " .. tostring(err))
      return false
    end

    local content = "return { active_config = " .. string.format("%q", active_name) .. " }"
    local ok, write_err = file:write(content)
    file:close()
    if not ok then
      ctx.log_line("Active-state write failed: " .. tostring(write_err))
      return false
    end
    return true
  end

  function api.load_active_state()
    local chunk = loadfile(constants.APP_STATE_PATH)
    if not chunk then
      return nil
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
      ctx.log_line("Active-state load invalid")
      return nil
    end

    if type(data.active_config) == "string" and data.active_config ~= "" then
      return ctx.sanitize_config_name(data.active_config)
    end

    return nil
  end

  function api.save_global_switch(switch_value)
    local file, err = io.open(constants.SWITCH_STATE_PATH, "w")
    if not file then
      ctx.log_line("Switch-state save failed: " .. tostring(err))
      return false
    end

    local content = "return " .. serialize_value({switch = switch_value})
    local ok, write_err = file:write(content)
    file:close()
    if not ok then
      ctx.log_line("Switch-state write failed: " .. tostring(write_err))
      return false
    end
    return true
  end

  function api.load_global_switch()
    local chunk = loadfile(constants.SWITCH_STATE_PATH)
    if not chunk then
      local legacy_chunk = loadfile("SCRIPTS:/FlightAnnouncer.user/active.user")
      if not legacy_chunk then
        return nil
      end
      local ok_legacy, legacy_data = pcall(legacy_chunk)
      if ok_legacy and type(legacy_data) == "table" then
        return legacy_data.switch
      end
      return nil
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
      return nil
    end
    return data.switch
  end

  function api.delete(name)
    local filename = ctx.sanitize_config_name(name)
    local path = config.dir .. "/" .. filename .. ".user"
    if os and type(os.remove) == "function" then
      local ok, err = os.remove(path)
      if ok then
        return true
      end
      return false, tostring(err)
    end
    return false, "os.remove unavailable"
  end

  function api.save(name, data)
    api.ensureDir()
    local cfg = ctx.normalize_cfg(data)
    cfg.switch = nil
    local filename = ctx.sanitize_config_name(name)
    local path = config.dir .. "/" .. filename .. ".user"
    local file, err = io.open(path, "w")
    if not file then
      return false, "open failed: " .. tostring(err)
    end

    local content = "return " .. serialize_value(cfg)
    local ok, write_err = file:write(content)
    file:close()

    if not ok then
      return false, "write failed: " .. tostring(write_err)
    end
    return true
  end

  function api.ensureDefault()
    local default_path = config.dir .. "/default.user"
    if ctx.file_exists(default_path) then
      return
    end

    local seed = {
      name = "Standard Programm",
      switch = "SB",
      wav_files = {}
    }
    local ok = api.save("default", seed)
    if ok then
      ctx.log_line("default.user created")
    else
      ctx.log_line("default.user could not be created")
    end
  end

  function api.exists(name)
    local filename = ctx.sanitize_config_name(name)
    return ctx.file_exists(config.dir .. "/" .. filename .. ".user")
  end

  api.deep_copy = deep_copy

  return api
end

return M
