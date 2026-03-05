-- Flight Announcer
-- Author: info
-- License: See LICENSE file (c) 2026

local M = {}

local SWITCH_THRESHOLD = 500
local DEBUG_LOG_PATH = "SCRIPTS:/FlightAnnouncer.user/debug.log"
local APP_STATE_PATH = "SCRIPTS:/FlightAnnouncer.user/.active.lua"
local SWITCH_STATE_PATH = "SCRIPTS:/FlightAnnouncer.user/.switch.lua"
local USER_AUDIO_DIR = "SCRIPTS:/FlightAnnouncer.user/audio"
local ICON_PATH = "fa-icon.png"
local ID_METHOD_NAMES = {"id", "getId", "identifier", "uid"}

local function normalize_language(value)
  if type(value) ~= "string" then
    return "en"
  end
  local language = value:lower():match("([a-z][a-z])")
  if language == "de" then
    return "de"
  end
  return "en"
end

local function load_translation_pack(language)
  local lang = normalize_language(language)
  local candidates = {
    "SCRIPTS:/FlightAnnouncer/i18n/" .. lang .. ".lua",
    "SCRIPTS:/tools/FlightAnnouncer/i18n/" .. lang .. ".lua",
    "i18n/" .. lang .. ".lua",
  }

  for _, path in ipairs(candidates) do
    local chunk = loadfile(path)
    if chunk then
      local ok, data = pcall(chunk)
      if ok and type(data) == "table" then
        return data
      end
    end
  end

  return {}
end

local function detect_system_locale()
  if system then
    local fn_names = {"getLocale", "getLocaleCode", "getLanguage", "getLanguageCode"}
    for _, fn_name in ipairs(fn_names) do
      local fn = system[fn_name]
      if type(fn) == "function" then
        local ok, value = pcall(fn)
        if ok and type(value) == "string" and value ~= "" then
          return value
        end
      end
    end
  end

  if os and type(os.setlocale) == "function" then
    local ok, locale = pcall(os.setlocale, nil)
    if ok and type(locale) == "string" and locale ~= "" then
      return locale
    end
  end

  return nil
end

local function translate(state, translations, key, params)
  local lang = normalize_language(state and state.language)
  local lang_pack = translations[lang] or translations.en or {}
  local fallback = translations.en or {}
  local template = lang_pack[key] or fallback[key] or tostring(key)

  if type(params) ~= "table" then
    return template
  end

  local rendered = template
  for param_key, param_value in pairs(params) do
    rendered = rendered:gsub("{" .. tostring(param_key) .. "}", tostring(param_value))
  end
  return rendered
end

local function is_volatile_source_string(value)
  return type(value) == "string" and value:match("^table:%s*0x[0-9a-fA-F]+$") ~= nil
end

local function normalize_switch_label(value)
  if type(value) ~= "string" then
    return value
  end
  return value:gsub("â†‘", "↑"):gsub("â†“", "↓")
end

local function log_line(message)
  local line = "[FlightAnnouncer] " .. tostring(message)
  print(line)
  local file = io.open(DEBUG_LOG_PATH, "a")
  if file then
    file:write(line .. "\n")
    file:close()
  end
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function load_tool_icon()
  local ok, icon = pcall(lcd.loadBitmap, ICON_PATH)
  if ok and icon then
    log_line("Icon loaded: " .. tostring(ICON_PATH))
    return icon
  end

  log_line("Icon load failed, using nil")
  return nil
end

local function normalize_cfg(data)
  if type(data) ~= "table" then
    data = {}
  end
  if type(data.name) ~= "string" or data.name == "" then
    data.name = "Flight Announcer"
  end
  if (type(data.switch) ~= "string" and type(data.switch) ~= "number") or data.switch == "" then
    data.switch = "SB"
  end
  if type(data.switch) == "string" then
    data.switch = normalize_switch_label(data.switch)
  end
  if type(data.wav_files) ~= "table" then
    data.wav_files = {}
  end
  return data
end

local function sanitize_config_name(value)
  local name = tostring(value or "default")
  name = name:gsub("%.user$", "")
  name = name:gsub("[^%w_%-]", "_")
  name = name:gsub("_+", "_")
  if name == "" then
    name = "default"
  end
  return name
end

local function source_to_string(source)
  if source == nil then
    return ""
  end
  if type(source) == "string" then
    return source
  end
  local ok_name, source_name = pcall(function()
    if type(source.name) == "function" then
      return source:name()
    end
    return nil
  end)
  if ok_name and type(source_name) == "string" and source_name ~= "" then
    if is_volatile_source_string(source_name) then
      return ""
    end
    return normalize_switch_label(source_name)
  end
  local as_text = tostring(source)
  if type(as_text) == "string" and as_text ~= "" and not is_volatile_source_string(as_text) then
    return normalize_switch_label(as_text)
  end
  return ""
end

local function source_to_storage(source)
  if source == nil then
    return ""
  end
  if type(source) == "number" then
    return source
  end

  if type(source) == "string" then
    if is_volatile_source_string(source) then
      return ""
    end

    local normalized = normalize_switch_label(source):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
      return ""
    end

    if normalized:match("^%-?%d+$") then
      return tonumber(normalized)
    end

    local scategory, smember = normalized:match("^%s*([^,]+),([^,]+)%s*$")
    if scategory and smember and tonumber(scategory) and tonumber(smember) then
      return tonumber(scategory) .. "," .. tonumber(smember)
    end

    local hex = normalized:match("^Source:%s*0x([0-9a-fA-F]+)$")
    if hex then
      local numeric_id = tonumber(hex, 16)
      if numeric_id then
        return numeric_id
      end
      return ""
    end

    local ok_src, resolved = pcall(system.getSource, normalized)
    if ok_src and resolved then
      return source_to_storage(resolved)
    end

    return ""
  end

  local ok_category, category = pcall(function() return source:category() end)
  local ok_member, member = pcall(function() return source:member() end)
  if ok_category and ok_member and tonumber(category) and tonumber(member) then
    return tonumber(category) .. "," .. tonumber(member)
  end

  local direct_id = source.id
  if type(direct_id) == "number" or (type(direct_id) == "string" and direct_id ~= "" and not is_volatile_source_string(direct_id)) then
    return direct_id
  end

  for _, method_name in ipairs(ID_METHOD_NAMES) do
    local ok_colon, value_colon = pcall(function()
      return source[method_name](source)
    end)
    if ok_colon and (type(value_colon) == "number" or (type(value_colon) == "string" and value_colon ~= "" and not is_volatile_source_string(value_colon))) then
      return value_colon
    end

    local method = source[method_name]
    if type(method) == "function" then
      local ok_no_self, value_no_self = pcall(method)
      if ok_no_self and (type(value_no_self) == "number" or (type(value_no_self) == "string" and value_no_self ~= "" and not is_volatile_source_string(value_no_self))) then
        return value_no_self
      end

      local ok_with_self, value_with_self = pcall(method, source)
      if ok_with_self and (type(value_with_self) == "number" or (type(value_with_self) == "string" and value_with_self ~= "" and not is_volatile_source_string(value_with_self))) then
        return value_with_self
      end
    end
  end

  local as_text = tostring(source)
  local hex = as_text and as_text:match("^Source:%s*0x([0-9a-fA-F]+)$")
  if hex then
    local numeric_id = tonumber(hex, 16)
    if numeric_id then
      return numeric_id
    end
  end

  return ""
end

local function source_from_value(value)
  if value == nil or value == "" then
    return nil
  end
  if is_volatile_source_string(value) then
    return nil
  end
  if type(value) == "userdata" and type(value.value) == "function" then
    return value
  end
  if type(value) == "table" and type(value.value) == "function" then
    return value
  end

  if type(value) == "string" then
    local normalized = normalize_switch_label(value)

    local scategory, smember = normalized:match("^%s*([^,]+),([^,]+)%s*$")
    if scategory and smember then
      local category = tonumber(scategory)
      local member = tonumber(smember)
      if category and member then
        local ok_cat_src, cat_src = pcall(system.getSource, {category = category, member = member})
        if ok_cat_src and cat_src then
          return cat_src
        end
      end
    end

    local numeric_string = normalized:match("^%s*(%-?%d+)%s*$")
    if numeric_string then
      local numeric_id = tonumber(numeric_string)
      if numeric_id then
        local ok_num_src, num_src = pcall(system.getSource, numeric_id)
        if ok_num_src and num_src then
          return num_src
        end
      end
    end

    local ok_label, label_source = pcall(system.getSource, normalized)
    if ok_label and label_source then
      return label_source
    end

    local hex = normalized:match("^Source:%s*0x([0-9a-fA-F]+)$")
    if hex then
      local numeric_id = tonumber(hex, 16)
      if numeric_id then
        local ok_hex_src, hex_src = pcall(system.getSource, numeric_id)
        if ok_hex_src and hex_src then
          return hex_src
        end
      end
    end
  end

  local ok_src, src = pcall(system.getSource, value)
  if ok_src and src then
    return src
  end

  if type(value) == "string" then
    local trimmed = normalize_switch_label(value):gsub("^%s+", ""):gsub("%s+$", "")
    local base = nil
    if trimmed:find("↑", 1, true) or trimmed:find("↓", 1, true) or trimmed:find("-", 1, true) then
      local candidate = trimmed:gsub("↑", ""):gsub("↓", ""):gsub("%-", "")
      candidate = candidate:gsub("^%s+", ""):gsub("%s+$", "")
      if candidate:match("^[%a][%w_]*$") then
        base = candidate
      end
    end
    if base then
      local ok_base, src_base = pcall(system.getSource, base)
      if ok_base and src_base then
        return src_base
      end
    end
  end

  return nil
end

local function source_from_config(cfg)
  if type(cfg) ~= "table" then
    return nil
  end
  if cfg.switch ~= nil and cfg.switch ~= "" then
    local source = source_from_value(cfg.switch)
    if source then
      return source
    end
  end
  return nil
end

local function picker_value_from_storage(path)
  local value = tostring(path or ""):gsub("\\", "/")
  if value == "" then
    return ""
  end

  local prefix_scripts = USER_AUDIO_DIR .. "/"
  local prefix_legacy = "/scripts/FlightAnnouncer.user/audio/"

  if value:sub(1, #prefix_scripts) == prefix_scripts then
    value = value:sub(#prefix_scripts + 1)
  elseif value:sub(1, #prefix_legacy) == prefix_legacy then
    value = value:sub(#prefix_legacy + 1)
  end

  value = value:gsub("%.wav$", "")
  return value
end

local function normalize_wav_path(path)
  if path == nil then
    return ""
  end

  local value = tostring(path):gsub("\\", "/")
  if value == "" then
    return ""
  end

  local normalized = value

  if value:sub(1, 8) == "SCRIPTS:" then
    normalized = value
  elseif value:sub(1, 9) == "/scripts/" then
    normalized = "SCRIPTS:/" .. value:sub(10)
  elseif value:sub(1, 1) == "/" then
    normalized = value
  else
    normalized = USER_AUDIO_DIR .. "/" .. value
  end

  local tail = normalized:match("([^/]+)$") or ""
  if tail ~= "" and not tail:find("%.") then
    normalized = normalized .. ".wav"
  end

  return normalized
end

local function as_legacy_scripts_path(path)
  if path:sub(1, 8) == "SCRIPTS:" then
    local suffix = path:sub(9)
    if suffix:sub(1, 1) ~= "/" then
      suffix = "/" .. suffix
    end
    return "/scripts" .. suffix
  end
  return path
end

local function safe_source_value(source_ref)
  if source_ref and type(source_ref.value) == "function" then
    local ok_direct, direct_value = pcall(source_ref.value, source_ref)
    if ok_direct then
      return direct_value
    end
  end

  local src = source_from_value(source_ref)
  if not src or type(src.value) ~= "function" then
    return nil
  end
  local ok_val, value = pcall(src.value, src)
  if not ok_val then
    return nil
  end
  return value
end

function M.new()
  local translations = {
    en = load_translation_pack("en"),
    de = load_translation_pack("de"),
  }

  local state = {
    available_configs = {},
    active_config_index = 1,
    active_config_name = nil,
    active_config_data = nil,
    current_wav_index = 1,
    is_switch_pressed = false,
    selected_wav_index = 1,
    is_building_form = false,
    form_built = false,
    pending_rebuild = false,
    language = normalize_language(detect_system_locale()),
    last_message = "",
  }

  local ctx = {
    constants = {
      SWITCH_THRESHOLD = SWITCH_THRESHOLD,
      DEBUG_LOG_PATH = DEBUG_LOG_PATH,
      APP_STATE_PATH = APP_STATE_PATH,
      SWITCH_STATE_PATH = SWITCH_STATE_PATH,
      USER_AUDIO_DIR = USER_AUDIO_DIR,
    },
    config = {
      dir = "SCRIPTS:/FlightAnnouncer.user",
    },
    state = state,
    log_line = log_line,
    file_exists = file_exists,
    load_tool_icon = load_tool_icon,
    normalize_cfg = normalize_cfg,
    sanitize_config_name = sanitize_config_name,
    source_to_string = source_to_string,
    source_to_storage = source_to_storage,
    is_volatile_source_string = is_volatile_source_string,
    normalize_switch_label = normalize_switch_label,
    source_from_value = source_from_value,
    source_from_config = source_from_config,
    picker_value_from_storage = picker_value_from_storage,
    normalize_wav_path = normalize_wav_path,
    as_legacy_scripts_path = as_legacy_scripts_path,
    safe_source_value = safe_source_value,
  }

  function ctx.apply_system_language()
    state.language = normalize_language(detect_system_locale())
    return state.language
  end

  function ctx.t(key, params)
    return translate(state, translations, key, params)
  end

  return ctx
end

return M
