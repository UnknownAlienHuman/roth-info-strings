-- RothInfoStrings Settings owner for Retail 12.1.
local ADDON = ...
if ADDON ~= "RothInfoStrings" then return end

local registered = false

local function Refresh()
  if type(_G.RothInfoStrings_Refresh) == "function" then
    _G.RothInfoStrings_Refresh()
  end
end

local function RegisterSettings()
  if registered or not Settings or not Settings.RegisterVerticalLayoutCategory then return false end
  registered = true

  local category = Settings.RegisterVerticalLayoutCategory("RothInfoStrings")
  _G.RothInfoStrings_SettingsCategoryID = category:GetID()

  local function AddCheckbox(variable, key, label, defaultValue, tooltip)
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      key,
      RothInfoStringsDB,
      Settings.VarType.Boolean,
      label,
      defaultValue
    )
    setting:SetValueChangedCallback(function() Refresh() end)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
  end

  AddCheckbox("ROTH_INFO_ENABLED", "enabled", "Enabled", true, "Show the information strings.")
  AddCheckbox("ROTH_INFO_LOCKED", "locked", "Locked", true, "Disable dragging while locked.")
  AddCheckbox("ROTH_INFO_CTRL_ALT_DRAG", "ctrlAltDrag", "Require CTRL+ALT to drag", true, "When unlocked, require CTRL+ALT instead of ALT alone.")
  AddCheckbox("ROTH_INFO_ATTACH_MINIMAP", "attachToMinimap", "Attach under Minimap", true, "Anchor the block to the Minimap instead of its saved UIParent position.")
  AddCheckbox("ROTH_INFO_SHOW_ZONE", "showZone", "Show zone", true)
  AddCheckbox("ROTH_INFO_SHOW_COORDS", "showCoords", "Show coordinates", true)
  AddCheckbox("ROTH_INFO_SHOW_PERF", "showPerf", "Show FPS and latency", true)
  AddCheckbox("ROTH_INFO_SHOW_MAIL", "showMail", "Show new-mail indicator", true)
  AddCheckbox("ROTH_INFO_SHOW_XP_REP", "showXPRep", "Show XP or watched reputation", true)
  AddCheckbox("ROTH_INFO_SHOW_MEM", "showMem", "Enable memory tooltip", true, "Addon memory is sampled only when the block is hovered or /ris memory is used.")

  local scaleSetting = Settings.RegisterAddOnSetting(
    category,
    "ROTH_INFO_SCALE",
    "scale",
    RothInfoStringsDB,
    Settings.VarType.Number,
    "Scale",
    1.0
  )
  scaleSetting:SetValueChangedCallback(function() Refresh() end)
  local sliderOptions = Settings.CreateSliderOptions(0.6, 2.0, 0.05)
  Settings.CreateSlider(category, scaleSetting, sliderOptions, "Scale the complete information block.")

  Settings.RegisterAddOnCategory(category)
  return true
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded(ADDON, RegisterSettings)
else
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function(self)
    if RegisterSettings() then self:UnregisterAllEvents() end
  end)
end
