-- Flight Announcer
-- Author: info
-- License: See LICENSE file (c) 2026

local M = {}

function M.new(ctx, app)
  local state = ctx.state
  local constants = ctx.constants
  local rebuild_form

  local function tr(key, params)
    if type(ctx.t) == "function" then
      return ctx.t(key, params)
    end
    return tostring(key)
  end

  local function run_then_rebuild(action)
    action()
    rebuild_form()
    return true
  end

  local function run_then_schedule_rebuild(action)
    action()
    state.pending_rebuild = true
    return true
  end

  rebuild_form = function()
    if state.is_building_form then
      return
    end
    if not form or type(form.clear) ~= "function" then
      return
    end

    state.is_building_form = true
    form.clear()

    local line

    line = form.addLine(tr("ui_active_set"))
    local set_slots = form.getFieldSlots(line, {200, 0})
    form.addChoiceField(line, set_slots[1], app.config_choices(), function()
      return state.active_config_index
    end, function(newValue)
      return run_then_rebuild(function()
        app.select_config(newValue)
      end)
    end)
    form.addTextButton(line, set_slots[2], tr("ui_delete"), function()
      if type(form.openDialog) == "function" then
        form.openDialog({
          title = tr("dialog_delete_set_title"),
          message = tr("dialog_delete_set_message"),
          buttons = {
            {
              label = tr("ui_yes"),
              action = function()
                return run_then_rebuild(app.delete_active_set)
              end
            },
            {
              label = tr("ui_no"),
              action = function()
                return true
              end
            }
          },
          closeWhenClickOutside = true
        })
        return true
      end

      return run_then_rebuild(app.delete_active_set)
    end)

    line = form.addLine(tr("ui_name"))
    form.addTextField(line, nil, function()
      local cfg = app.active_cfg()
      return cfg.name
    end, function(newValue)
      local cfg = app.active_cfg()
      cfg.name = newValue
    end)

    line = form.addLine(tr("ui_trigger"))
    form.addSwitchField(line, nil, function()
      local cfg = app.active_cfg()
      local saved_switch = ctx.normalize_switch_label(tostring(cfg.switch or ""))
      local resolved = state.active_switch_source
      if not resolved then
        resolved = ctx.source_from_config(cfg)
      end
      if resolved then
        return resolved
      end
      if saved_switch ~= "" then
        local base = saved_switch:gsub("↑", ""):gsub("↓", ""):gsub("%-", "")
        base = base:gsub("^%s+", ""):gsub("%s+$", "")
        if base ~= "" then
          return ctx.source_from_value(base)
        end
      end
      return nil
    end, function(newValue)
      app.update_global_switch(newValue)
      local switch_label = ctx.normalize_switch_label(ctx.source_to_string(newValue))
      state.last_message = tr("msg_trigger", {value = tostring(switch_label)})
    end)

    line = form.addLine(tr("ui_save"))
    form.addTextButton(line, nil, tr("ui_save"), function()
      return run_then_rebuild(app.save_current)
    end)

    local panel = form.addExpansionPanel(tr("ui_wav_sequence"))

    line = panel:addLine(tr("ui_wav_folder"))
    form.addStaticText(line, nil, constants.USER_AUDIO_DIR)

    line = panel:addLine(tr("ui_wav_add"))
    local add_slots = form.getFieldSlots(line, {0, 0})
    form.addTextButton(line, add_slots[1], tr("ui_add_empty_slot"), function()
      return run_then_rebuild(app.add_wav_entry)
    end)
    form.addTextButton(line, add_slots[2], tr("ui_remove_empty_slots"), function()
      return run_then_rebuild(app.remove_empty_wav_slots)
    end)

    local wav_entries = app.active_wavs()
    for i = 1, #wav_entries do
      local row_index = i
      line = panel:addLine("WAV " .. tostring(row_index))
      local slots = form.getFieldSlots(line, {0, 140})

      form.addFileField(line, slots[1], constants.USER_AUDIO_DIR, "audio", function()
        local current_wavs = app.active_wavs()
        return ctx.picker_value_from_storage(current_wavs[row_index] or "")
      end, function(newValue)
        local current_wavs = app.active_wavs()
        while #current_wavs < row_index do
          current_wavs[#current_wavs + 1] = ""
        end
        current_wavs[row_index] = ctx.normalize_wav_path(newValue)
        state.selected_wav_index = row_index
      end)

      form.addTextButton(line, slots[2], tr("ui_menu"), function()
        local current_wavs = app.active_wavs()
        if row_index < 1 or row_index > #current_wavs then
          state.last_message = tr("msg_invalid_wav_index")
          return true
        end

        if type(form.openDialog) ~= "function" then
          state.last_message = tr("msg_action_dialog_unavailable")
          return true
        end

        local dialog_width = 520
        if lcd and type(lcd.getWindowSize) == "function" then
          local w = lcd.getWindowSize()
          if type(w) == "number" and w > 0 then
            dialog_width = math.max(420, math.floor(w * 0.95))
          end
        end

        form.openDialog({
          title = tr("ui_wav_actions_title", {index = tostring(row_index)}),
          message = tr("ui_action"),
          width = dialog_width,
          buttons = {
            {
              label = tr("ui_up"),
              action = function()
                return run_then_schedule_rebuild(function()
                  app.swap_wav_at(row_index, -1)
                end)
              end
            },
            {
              label = tr("ui_down"),
              action = function()
                return run_then_schedule_rebuild(function()
                  app.swap_wav_at(row_index, 1)
                end)
              end
            },
            {
              label = tr("ui_dup"),
              action = function()
                return run_then_schedule_rebuild(function()
                  app.duplicate_wav_at(row_index)
                end)
              end
            },
            {
              label = tr("ui_delete"),
              action = function()
                return run_then_schedule_rebuild(function()
                  app.remove_wav_at(row_index)
                end)
              end
            }
          },
          closeWhenClickOutside = true
        })
        return true
      end)
    end

    line = form.addLine(tr("ui_reload"))
    form.addTextButton(line, nil, tr("ui_reload"), function()
      return run_then_rebuild(app.reload_configs)
    end)

    line = form.addLine(tr("ui_status"))
    local wav_count = #app.active_wavs()
    form.addStaticText(line, nil, (state.last_message or "") .. " | WAV: " .. tostring(wav_count))

    state.form_built = true
    state.is_building_form = false
  end

  local function process_pending_rebuild()
    if not state.pending_rebuild then
      return false
    end
    state.pending_rebuild = false
    rebuild_form()
    return true
  end

  return {
    rebuild_form = rebuild_form,
    process_pending_rebuild = process_pending_rebuild
  }
end

return M
