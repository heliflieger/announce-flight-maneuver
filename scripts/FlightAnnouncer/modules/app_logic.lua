-- Flight Announcer
-- Author: info
-- License: See LICENSE file (c) 2026

local M = {}

function M.new(ctx, store)
  local state = ctx.state
  local constants = ctx.constants

  local api = {}

  local function tr(key, params)
    if type(ctx.t) == "function" then
      return ctx.t(key, params)
    end
    return tostring(key)
  end

  local function mark_config_choices_dirty()
    state.config_choices_dirty = true
  end

  local function get_switch_parse_cache(cfg)
    local switch_raw = tostring(cfg.switch or "")
    if state.cached_switch_raw == switch_raw then
      return state.cached_switch_text, state.cached_switch_direction, state.cached_switch_base, state.cached_switch_base_source
    end

    local switch_text = ctx.normalize_switch_label(switch_raw)

    local direction = nil
    if switch_text:find("↑", 1, true) then
      direction = "↑"
    elseif switch_text:find("↓", 1, true) then
      direction = "↓"
    elseif switch_text:find("-", 1, true) then
      direction = "-"
    end

    local base = nil
    if direction then
      local candidate = switch_text:gsub("↑", ""):gsub("↓", ""):gsub("%-", "")
      candidate = candidate:gsub("^%s+", ""):gsub("%s+$", "")
      if candidate:match("^[%a][%w_]*$") then
        base = candidate
      end
    end

    local base_source = nil
    if base then
      base_source = ctx.source_from_value(base)
    end

    state.cached_switch_raw = switch_raw
    state.cached_switch_text = switch_text
    state.cached_switch_direction = direction
    state.cached_switch_base = base
    state.cached_switch_base_source = base_source
    return switch_text, direction, base, base_source
  end

  function api.active_cfg()
    if not state.active_config_data then
      state.active_config_data = ctx.normalize_cfg({})
    end
    return state.active_config_data
  end

  function api.active_wavs()
    local cfg = api.active_cfg()
    if type(cfg.wav_files) ~= "table" then
      cfg.wav_files = {}
    end
    return cfg.wav_files
  end

  function api.config_choices()
    if not state.config_choices_dirty and type(state.config_choices_cache) == "table" and #state.config_choices_cache > 0 then
      return state.config_choices_cache
    end

    local choices = {}
    for i, name in ipairs(state.available_configs) do
      choices[#choices + 1] = {name, i}
    end
    if #choices == 0 then
      choices[1] = {"default", 1}
    end
    state.config_choices_cache = choices
    state.config_choices_dirty = false
    return choices
  end

  function api.activate_set_by_name(name)
    local filename = ctx.sanitize_config_name(name)
    if filename == "" then
      return
    end

    state.active_config_name = filename
    if store.exists(filename) then
      state.available_configs = store.getAvailable()
      mark_config_choices_dirty()
      local target_index = 1
      for i, set_name in ipairs(state.available_configs) do
        if set_name == filename then
          target_index = i
          break
        end
      end
      api.select_config(target_index)
      return
    end

    state.active_config_data = ctx.normalize_cfg({name = name})
    if state.global_switch ~= nil and state.global_switch ~= "" then
      state.active_config_data.switch = state.global_switch
    end
    state.active_switch_source = ctx.source_from_value(state.active_config_data.switch)
    state.last_message = tr("msg_new_set", {name = filename})
    state.selected_wav_index = 1
    state.current_wav_index = 1
    state.is_switch_pressed = false
  end

  function api.select_config(index)
    if #state.available_configs == 0 then
      state.active_config_index = 1
      state.active_config_name = ctx.sanitize_config_name(state.active_config_name or "default")
      state.active_config_data = store.load(state.active_config_name)
      if not state.active_config_data and state.active_config_name ~= "default" then
        state.active_config_name = "default"
        state.active_config_data = store.load("default")
      end
      if not state.active_config_data then
        state.active_config_data = ctx.normalize_cfg({name = state.active_config_name})
      end
      if ctx.is_volatile_source_string and ctx.is_volatile_source_string(state.active_config_data.switch) then
        state.active_config_data.switch = ""
      end
      if type(state.active_config_data.switch) == "string" then
        state.active_config_data.switch = ctx.normalize_switch_label(state.active_config_data.switch)
      end
      if type(state.active_config_data.wav_files) == "table" then
        for i = 1, #state.active_config_data.wav_files do
          state.active_config_data.wav_files[i] = ctx.normalize_wav_path(state.active_config_data.wav_files[i])
        end
      end
      if state.global_switch ~= nil and state.global_switch ~= "" then
        state.active_config_data.switch = state.global_switch
      elseif state.active_config_data.switch ~= nil and state.active_config_data.switch ~= "" then
        state.global_switch = state.active_config_data.switch
      end

      state.active_switch_source = ctx.source_from_config(state.active_config_data)
      return
    end

    if index < 1 then
      index = #state.available_configs
    elseif index > #state.available_configs then
      index = 1
    end

    state.active_config_index = index
    state.active_config_name = ctx.sanitize_config_name(state.available_configs[index])
    state.active_config_data = store.load(state.active_config_name)
    if not state.active_config_data then
      state.active_config_data = ctx.normalize_cfg({name = state.active_config_name})
      state.last_message = tr("msg_load_failed_defaults")
    else
      state.last_message = tr("msg_loaded", {name = state.active_config_name})
    end

    if ctx.is_volatile_source_string and ctx.is_volatile_source_string(state.active_config_data.switch) then
      state.active_config_data.switch = ""
    end
    if type(state.active_config_data.switch) == "string" then
      state.active_config_data.switch = ctx.normalize_switch_label(state.active_config_data.switch)
    end
    if type(state.active_config_data.wav_files) == "table" then
      for i = 1, #state.active_config_data.wav_files do
        state.active_config_data.wav_files[i] = ctx.normalize_wav_path(state.active_config_data.wav_files[i])
      end
    end

    if state.global_switch ~= nil and state.global_switch ~= "" then
      state.active_config_data.switch = state.global_switch
    elseif state.active_config_data.switch ~= nil and state.active_config_data.switch ~= "" then
      state.global_switch = state.active_config_data.switch
    end

    state.active_switch_source = ctx.source_from_config(state.active_config_data)

    state.selected_wav_index = 1
    state.current_wav_index = 1
    state.is_switch_pressed = false
    store.save_active_state(state.active_config_name)
  end

  function api.reload_configs()
    local previous_name = state.active_config_name
    state.available_configs = store.getAvailable()
    mark_config_choices_dirty()

    if #state.available_configs == 0 then
      local preferred = ctx.sanitize_config_name(previous_name or state.active_config_name or "default")
      if store.exists(preferred) then
        state.available_configs = {preferred}
        mark_config_choices_dirty()
      elseif store.exists("default") then
        state.available_configs = {"default"}
        mark_config_choices_dirty()
      end
    end

    if #state.available_configs == 0 then
      api.select_config(1)
      return
    end

    local keep_index = 1
    if previous_name then
      for i, name in ipairs(state.available_configs) do
        if name == previous_name then
          keep_index = i
          break
        end
      end
    end

    api.select_config(keep_index)
  end

  function api.add_wav_entry()
    local wavs = api.active_wavs()
    wavs[#wavs + 1] = ""
    state.selected_wav_index = #wavs
    state.last_message = tr("msg_wav_entry_added")
  end

  function api.remove_empty_wav_slots()
    local wavs = api.active_wavs()
    local removed = 0

    for i = #wavs, 1, -1 do
      local text = tostring(wavs[i] or ""):gsub("\\", "/")
      text = text:gsub("^%s+", ""):gsub("%s+$", "")
      local is_empty_slot = (
        text == ""
        or text == constants.USER_AUDIO_DIR
        or text == (constants.USER_AUDIO_DIR .. "/")
        or text == "/scripts/FlightAnnouncer.user/audio"
        or text == "/scripts/FlightAnnouncer.user/audio/"
      )
      if is_empty_slot then
        table.remove(wavs, i)
        removed = removed + 1
      end
    end

    if #wavs == 0 then
      state.selected_wav_index = 1
    elseif state.selected_wav_index < 1 then
      state.selected_wav_index = 1
    elseif state.selected_wav_index > #wavs then
      state.selected_wav_index = #wavs
    end

    if removed > 0 then
      state.last_message = tr("msg_empty_slots_removed", {count = tostring(removed)})
    else
      state.last_message = tr("msg_no_empty_slots_found")
    end
  end

  function api.remove_wav_at(index)
    local wavs = api.active_wavs()
    if #wavs == 0 then
      state.last_message = tr("msg_no_wav_entry_to_remove")
      return
    end

    if index < 1 or index > #wavs then
      state.last_message = tr("msg_invalid_wav_index")
      return
    end

    table.remove(wavs, index)
    if state.selected_wav_index > #wavs then
      state.selected_wav_index = #wavs
    end
    if state.selected_wav_index < 1 then
      state.selected_wav_index = 1
    end
    state.last_message = tr("msg_wav_entry_removed")
  end

  function api.swap_wav_at(index, delta)
    local wavs = api.active_wavs()
    if #wavs < 2 then
      state.last_message = tr("msg_need_two_wav_entries")
      return
    end

    local from = index
    if from < 1 or from > #wavs then
      state.last_message = tr("msg_invalid_wav_index")
      return
    end

    local to = from + delta
    if to < 1 or to > #wavs then
      state.last_message = tr("msg_cannot_move_further")
      return
    end
    wavs[from], wavs[to] = wavs[to], wavs[from]
    state.selected_wav_index = to
    state.last_message = tr("msg_wav_moved")
  end

  function api.duplicate_wav_at(index)
    local wavs = api.active_wavs()
    if index < 1 or index > #wavs then
      state.last_message = tr("msg_invalid_wav_index")
      return
    end

    table.insert(wavs, index + 1, wavs[index])
    state.selected_wav_index = index + 1
    state.last_message = tr("msg_wav_duplicated")
  end

  function api.save_current()
    local cfg = api.active_cfg()
    local name = ctx.sanitize_config_name(cfg.name or state.active_config_name)
    if not name or name == "" then
      name = "default"
    end
    state.active_config_name = name

    if state.active_switch_source then
      state.global_switch = ctx.source_to_storage(state.active_switch_source)
    elseif cfg.switch ~= nil and cfg.switch ~= "" then
      local resolved = ctx.source_from_value(cfg.switch)
      state.global_switch = ctx.source_to_storage(resolved)
    end
    cfg.switch = state.global_switch

    local ok, err = store.save(name, cfg)
    if ok then
      state.last_message = tr("msg_saved", {name = name})
        store.save_active_state(name)
        store.save_global_switch(state.global_switch)
        state.available_configs = store.getAvailable()
        mark_config_choices_dirty()
        for i, set_name in ipairs(state.available_configs) do
          if set_name == name then
            state.active_config_index = i
            break
          end
        end
    else
      state.last_message = tr("msg_save_failed", {error = tostring(err)})
    end
  end

  function api.update_global_switch(new_source)
    state.active_switch_source = new_source
    state.global_switch = ctx.source_to_storage(new_source)
    local cfg = api.active_cfg()
    cfg.switch = state.global_switch
      store.save_active_state(state.active_config_name or "default")
      store.save_global_switch(state.global_switch)
    end

  function api.set_global_switch(new_value)
    local resolved = ctx.source_from_value(new_value)
    if resolved then
      return api.update_global_switch(resolved)
    end

    state.active_switch_source = nil
    state.global_switch = ctx.source_to_storage(new_value)
    local cfg = api.active_cfg()
    cfg.switch = state.global_switch
    store.save_active_state(state.active_config_name or "default")
    store.save_global_switch(state.global_switch)
  end

    function api.delete_active_set()
      local current_name = ctx.sanitize_config_name(state.active_config_name or "")
      if current_name == "" then
        state.last_message = tr("msg_no_set_active")
        return
      end

      local ok, err = store.delete(current_name)
      if not ok then
        state.last_message = tr("msg_delete_failed", {error = tostring(err)})
        return
      end

      state.last_message = tr("msg_set_deleted", {name = current_name})
      state.available_configs = store.getAvailable()
      mark_config_choices_dirty()
      if #state.available_configs == 0 then
        store.ensureDefault()
        state.available_configs = store.getAvailable()
        mark_config_choices_dirty()
      end

      api.select_config(1)
  end

  function api.background()
    local cfg = state.active_config_data
    if not cfg then
      return
    end

    if not cfg.switch then
      return
    end

    if not cfg.wav_files or #cfg.wav_files == 0 then
      return
    end

    local switch_text, switch_direction, switch_base, switch_base_source = get_switch_parse_cache(cfg)

    local switch_ref = state.active_switch_source or ctx.source_from_config(cfg) or cfg.switch
    local switch_value = ctx.safe_source_value(switch_ref)
    local is_active = nil

    if switch_value ~= nil then
      if switch_direction == "↑" then
        is_active = switch_value > constants.SWITCH_THRESHOLD
      elseif switch_direction == "↓" then
        is_active = switch_value < -constants.SWITCH_THRESHOLD
      elseif switch_direction == "-" then
        is_active = math.abs(switch_value) <= constants.SWITCH_THRESHOLD
      else
        is_active = switch_value > 0
      end
    else
      if switch_text ~= "" and switch_base and switch_direction then
          local base_value = ctx.safe_source_value(switch_base_source)
          if base_value ~= nil then
            if switch_direction == "↑" then
              is_active = base_value > constants.SWITCH_THRESHOLD
            elseif switch_direction == "↓" then
              is_active = base_value < -constants.SWITCH_THRESHOLD
            elseif switch_direction == "-" then
              is_active = math.abs(base_value) <= constants.SWITCH_THRESHOLD
            end
          end
      end

      if is_active == nil then
        return
      end
    end

    if is_active and not state.is_switch_pressed then
      state.is_switch_pressed = true
      local file_to_play = ctx.normalize_wav_path(cfg.wav_files[state.current_wav_index])
      if file_to_play and file_to_play ~= "" then
        local played = false
        if system and type(system.playFile) == "function" then
          local ok_call, result = pcall(system.playFile, file_to_play)
          played = ok_call and true or false
        end
        if (not played) and general and type(general.playFile) == "function" then
          local legacy = ctx.as_legacy_scripts_path(file_to_play)
          local ok_legacy = pcall(general.playFile, legacy, 0)
          if not ok_legacy then
            local ok_direct = pcall(general.playFile, file_to_play, 0)
          end
        end
      end
      state.current_wav_index = state.current_wav_index + 1
      if state.current_wav_index > #cfg.wav_files then
        state.current_wav_index = 1
      end
    elseif (not is_active) and state.is_switch_pressed then
      state.is_switch_pressed = false
    end
  end

  return api
end

return M
