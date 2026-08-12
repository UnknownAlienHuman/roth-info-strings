-- RothInfoStrings Settings UI (no Ace)
local ADDON = ...
if ADDON ~= "RothInfoStrings" then return end

local function DB() return RothInfoStringsDB end
local function Refresh()
  if _G.RothInfoStrings_Refresh then _G.RothInfoStrings_Refresh() end
end

local function MakeCheck(parent, label, tooltip, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  cb.tooltipText = tooltip
  cb:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
  cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
  return cb
end

local function MakeSlider(parent, label, minV, maxV, step, get, set)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:SetWidth(260)
  _G[s:GetName().."Text"]:SetText(label)
  _G[s:GetName().."Low"]:SetText(tostring(minV))
  _G[s:GetName().."High"]:SetText(tostring(maxV))
  s:SetScript("OnShow", function(self) self:SetValue(get()) end)
  s:SetScript("OnValueChanged", function(self, v) set(v) end)
  return s
end

local panel = CreateFrame("Frame")
panel.name = "RothInfoStrings"

panel:SetScript("OnShow", function(self)
  if self._built then return end
  self._built = true

  local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("RothInfoStrings")

  local enabled = MakeCheck(self, "Enabled", nil,
    function() return DB().enabled ~= false end,
    function(v) DB().enabled = v and true or false; Refresh() end)
  enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -12)

  local unlocked = MakeCheck(self, "Unlocked (allow drag)", "Drag with ALT by default; CTRL+ALT if 'Require CTRL+ALT' is enabled.",
    function() return DB().locked == false end,
    function(v) if SlashCmdList and SlashCmdList.ROTHIS then SlashCmdList.ROTHIS(v and "unlock" or "lock") end end)
  unlocked:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -6)

  local req = MakeCheck(self, "Require CTRL+ALT for drag", nil,
    function() return DB().ctrlAltDrag ~= false end,
    function(v) DB().ctrlAltDrag = v and true or false end)
  req:SetPoint("TOPLEFT", unlocked, "BOTTOMLEFT", 0, -6)

  local attach = MakeCheck(self, "Attach under Minimap", nil,
    function() return DB().attachToMinimap ~= false end,
    function(v) DB().attachToMinimap = v and true or false; Refresh() end)
  attach:SetPoint("TOPLEFT", req, "BOTTOMLEFT", 0, -6)

  local showMem = MakeCheck(self, "Show Memory Usage", "Shows total addon memory usage and enables tooltip with details.",
    function() return DB().showMem ~= false end,
    function(v) DB().showMem = v and true or false; Refresh() end)
  showMem:SetPoint("TOPLEFT", attach, "BOTTOMLEFT", 0, -6)

  local scale = MakeSlider(self, "Scale", 0.6, 2.0, 0.05,
    function() return tonumber(DB().scale) or 1.0 end,
    function(v) DB().scale = v; if _G.RothInfoStringsAnchor then _G.RothInfoStringsAnchor:SetScale(v) end end)
  scale:SetPoint("TOPLEFT", showMem, "BOTTOMLEFT", 0, -18)

  local reset = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  reset:SetSize(160, 22)
  reset:SetText("Reset / Dock Minimap")
  reset:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -16)
  reset:SetScript("OnClick", function()
    if SlashCmdList and SlashCmdList.ROTHIS then SlashCmdList.ROTHIS("reset") end
    Refresh()
  end)
end)

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
else
  InterfaceOptions_AddCategory(panel)
end
