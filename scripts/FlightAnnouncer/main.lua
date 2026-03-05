-- Flight Announcer
-- Author: info
-- License: See LICENSE file (c) 2026
-- Version: 0.5.0

local function load_module(name)
  local candidates = {
    "SCRIPTS:/FlightAnnouncer/modules/" .. name .. ".lua",
    "SCRIPTS:/tools/FlightAnnouncer/modules/" .. name .. ".lua",
    "modules/" .. name .. ".lua",
  }

  local first_error = nil
  for _, path in ipairs(candidates) do
    local chunk, err = loadfile(path)
    if chunk then
      local ok, mod = pcall(chunk)
      if ok and type(mod) == "table" then
        return mod
      end
      if not ok and not first_error then
        first_error = mod
      end
    elseif err and not first_error then
      first_error = err
    end
  end

  error("Failed to load module '" .. tostring(name) .. "': " .. tostring(first_error))
end

local Common = load_module("common")
local ConfigStore = load_module("config_store")
local AppLogic = load_module("app_logic")
local UiForm = load_module("ui_form")

local ctx = Common.new()
local store = ConfigStore.new(ctx)
local app = AppLogic.new(ctx, store)
local ui = UiForm.new(ctx, app)
local bg_task_index = nil

local icon = ctx.load_tool_icon()

local function bootstrap_runtime()
  if ctx.state.runtime_bootstrapped then
    return
  end

  if type(ctx.apply_system_language) == "function" then
    ctx.apply_system_language()
  end

  store.ensureDir()
  store.ensureDefault()

  local remembered = store.load_active_state()
  if remembered and remembered ~= "" then
    ctx.state.active_config_name = remembered
  end

  local global_switch = store.load_global_switch()
  if global_switch ~= nil and global_switch ~= "" then
    app.set_global_switch(global_switch)
  end

  app.reload_configs()
  ctx.state.runtime_bootstrapped = true
end

local function create()
  ctx.log_line("create called")
  ctx.state.form_built = false
  bootstrap_runtime()
  ui.rebuild_form()
  return ctx.state
end

local function wakeup(widget)
  app.background()
  ui.process_pending_rebuild()
  if not ctx.state.form_built and form and type(form.clear) == "function" then
    ui.rebuild_form()
  end
end

local function bg_init()
  ctx.log_line("bg init")
  bootstrap_runtime()
end

local function bg_event()
end

local function bg_wakeup()
  if not ctx.state.runtime_bootstrapped then
    bootstrap_runtime()
  end
  app.background()
end

function destroy()
  ctx.log_line("destroy called")
end

local function tool_name()
  return "Flight Announcer"
end

function init()
  ctx.log_line("init called")
  local ok, err = pcall(system.registerSystemTool, {
    name = tool_name,
    icon = icon,
    create = create,
    wakeup = wakeup,
    close = destroy
  })

  if ok then
    ctx.log_line("registerSystemTool ok")
  else
    ctx.log_line("registerSystemTool failed: " .. tostring(err))
  end

  if system and type(system.registerTask) == "function" then
    local task_ok, task_idx = pcall(system.registerTask, {
      name = tool_name() .. " [Background]",
      key = "fa_bg",
      init = bg_init,
      wakeup = bg_wakeup,
      event = bg_event
    })

    if task_ok then
      bg_task_index = task_idx
      ctx.log_line("registerTask ok")
    else
      ctx.log_line("registerTask failed: " .. tostring(task_idx))
    end
  else
    ctx.log_line("registerTask not available")
  end
end

function background()
  app.background()
end

return {init = init, background = background, destroy = destroy}
