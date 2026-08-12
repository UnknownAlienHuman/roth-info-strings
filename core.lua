-- RothInfoStrings: rebuilt from Galaxy module with Midnight-safe rules.
-- Goals:
--  * no polling loops / no heavy scans while idle
--  * avoid arithmetic/comparisons on possibly-secret values (use issecretvalue gate)
--  * show Blizzard-provided values, minimal formatting

local ADDON = ...
RothInfoStringsDB = RothInfoStringsDB or {}

local DB
local defaults = {
  enabled = true,     -- ON by default
  locked  = true,
  scale   = 1.0,
  pos = { point="TOPRIGHT", relPoint="TOPRIGHT", x=-20, y=-170 },
  attachToMinimap = true,
  minimapPoint = 'TOPRIGHT',
  minimapRelPoint = 'BOTTOMRIGHT',
  minimapX = 0,
  minimapY = -6,
  ctrlAltDrag = true,

  showZone   = true,
  showCoords = true,
  showPerf   = true,
  showMail   = true,
  showXPRep  = true,
  showMem    = true,

  perfInterval = 2.0, -- seconds
  coordInterval = 0.5, -- seconds while moving only
}

local function CopyDefaults(dst, src)
  for k,v in pairs(src) do
    if type(v) == "table" then
      dst[k] = dst[k] or {}
      CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function isSecret(val)
  return (type(issecretvalue) == "function") and issecretvalue(val) or false
end

local function SafeToString(val)
  if val == nil then return "" end
  if isSecret(val) then return "SV" end
  return tostring(val)
end

local function FormatMem(kb)
  if not kb then return "0kb" end
  if kb > 1024 then
    return string.format("%.1fmb", kb/1024)
  else
    return string.format("%.0fkb", kb)
  end
end

-- UI
local anchor, fs1, fs2, fs3
local perfTicker, coordTicker
local lastZoneText = nil
local memTotal = 0
local memTimer = 0
local lowFpsDuration = 0 -- Counter for critical FPS duration

local function ApplyAnchor()
if not anchor then return end
anchor:ClearAllPoints()
-- Default: stick under Minimap like old Galaxy layout.
if DB.attachToMinimap and _G.Minimap then
  anchor:SetPoint(DB.minimapPoint or "TOPRIGHT", _G.Minimap, DB.minimapRelPoint or "BOTTOMRIGHT", DB.minimapX or 0, DB.minimapY or -6)
else
  anchor:SetPoint(DB.pos.point, UIParent, DB.pos.relPoint, DB.pos.x, DB.pos.y)
end
anchor:SetScale(DB.scale or 1.0)
end

local function SetLocked(lock)
  DB.locked = lock and true or false
  if not anchor then return end
  -- Enable mouse if unlocked (for drag) OR if we need tooltip (showMem)
  anchor:EnableMouse((not DB.locked) or DB.showMem)
  anchor:SetMovable(true) -- required for StartMoving
  if anchor.hint then
    anchor.hint:SetAlpha(DB.locked and 0 or 0.15)
  end
end

local function GetCoordsText()
  if not DB.showCoords then return nil end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if not x or not y or x == 0 or y == 0 then return nil end
  -- x/y are normal numbers here (not secret)
  return string.format("%02d/%02d", x*100, y*100)
end

local function UpdateZone()
  if not fs1 or not DB.showZone then
    if fs1 then fs1:SetText("") end
    return
  end
  local z = GetMinimapZoneText() or ""
  if z == lastZoneText then return end
  lastZoneText = z
  fs1:SetText(z)
end

local function UpdateCoords()
  if not fs1 or not DB.showZone then return end
  local z = GetMinimapZoneText() or ""
  local c = GetCoordsText()
  if c then
    fs1:SetText(string.format("%s |cff9C907D[%s]|r", z, c))
  else
    fs1:SetText(z)
  end
end

local function UpdateMemTotal()
  if C_AddOns and C_AddOns.UpdateAddOnMemoryUsage then
    C_AddOns.UpdateAddOnMemoryUsage()
  end

  local total = 0
  local numAddons = (C_AddOns and C_AddOns.GetNumAddOns) and C_AddOns.GetNumAddOns() or 0

  for i=1, numAddons do
    local mem = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) and C_AddOns.GetAddOnMemoryUsage(i) or 0
    total = total + mem
  end
  memTotal = total
end

local function StopTickers()
  if perfTicker then perfTicker:Cancel(); perfTicker=nil end
  if coordTicker then coordTicker:Cancel(); coordTicker=nil end
end

local function UpdatePerf()
  if not fs2 or not DB.showPerf then
    if fs2 then fs2:SetText("") end
    return
  end

  local fps = math.floor((GetFramerate() or 0) + 0.5)

  -- PROTECTION: Critical Low FPS (< 10)
  if fps < 10 then
    lowFpsDuration = lowFpsDuration + (DB.perfInterval or 2.0)
    if lowFpsDuration >= 5 then
      -- Emergency Shutdown
      StopTickers()
      if anchor then anchor:Hide() end
      print("|cffff0000RothInfoStrings:|r Emergency Shutdown due to critical FPS (<10). Type |cff00ff00/ris toggle|r to re-enable.")
      return
    end
  else
    lowFpsDuration = 0
  end

  -- PROTECTION: Low FPS (< 30) -> Disable Memory Scan
  local isLowFps = (fps < 30)
  local memText = ""

  if DB.showMem then
    if isLowFps then
      -- Lightweight mode: do NOT call UpdateAddOnMemoryUsage
      memText = "  |cff888888(Mem Paused)|r"
    else
      -- Normal mode
      memTimer = memTimer + 1
      if memTimer >= 5 then
        UpdateMemTotal()
        memTimer = 0
      end
      memText = "  |cff00ccff" .. FormatMem(memTotal) .. "|r"
    end
  end

  local _, _, homeMS, worldMS = GetNetStats()
  local fpsColor = isLowFps and "|cffff0000" or "|cffffffff"

  local text = string.format("%sms/%sms  %s%sfps|r%s",
    SafeToString(homeMS),
    SafeToString(worldMS),
    fpsColor,
    SafeToString(fps),
    memText
  )

  fs2:SetText(text)
end

local function GetXPText()
  if not DB.showXPRep then return "" end
  if IsXPUserDisabled and IsXPUserDisabled() then return "" end
  local lvl = UnitLevel("player")
  if isSecret(lvl) then return "" end

  local maxLvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80
  if lvl and lvl >= maxLvl then return "" end

  local cur = UnitXP("player")
  local max = UnitXPMax("player")
  if isSecret(cur) or isSecret(max) then return "XP: SV" end
  if not cur or not max or max == 0 then return "" end

  return "XP: "..SafeToString(cur).."/"..SafeToString(max)
end

local function GetRepText()
  if not DB.showXPRep then return "" end
  if not C_Reputation or not C_Reputation.GetWatchedFactionData then return "" end
  local f = C_Reputation.GetWatchedFactionData()
  if not f then return "" end

  -- Use Blizzard-provided descriptive fields; avoid derived math.
  local name = f.name or "Reputation"
  local reactionText = f.reactionText or (f.reaction and _G["FACTION_STANDING_LABEL"..SafeToString(f.reaction)]) or ""
  if reactionText == nil then reactionText = "" end
  return "REP: "..name.." "..tostring(reactionText)
end

local function UpdateProgress()
  if not fs3 then return end

  local parts = {}

  if DB.showMail and HasNewMail and HasNewMail() then
    parts[#parts+1] = "|cffff66ccMAIL|r"
  end

  local xp = GetXPText()
  if xp ~= "" then
    parts[#parts+1] = xp
  else
    local rep = GetRepText()
    if rep ~= "" then parts[#parts+1] = rep end
  end

  fs3:SetText(table.concat(parts, "  "))
end

local function ShowTooltip(self)
  if not DB.showMem then return end
  -- Don't show tooltip if we are in Low FPS mode (implied by not updating mem)
  local fps = GetFramerate() or 60
  if fps < 30 then return end

  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("AddOn Memory Usage", 1, 1, 1)

  if C_AddOns and C_AddOns.UpdateAddOnMemoryUsage then
    C_AddOns.UpdateAddOnMemoryUsage() -- Fresh update for tooltip
  end

  local addons = {}
  local total = 0
  local numAddons = (C_AddOns and C_AddOns.GetNumAddOns) and C_AddOns.GetNumAddOns() or 0

  for i=1, numAddons do
      local mem = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) and C_AddOns.GetAddOnMemoryUsage(i) or 0
      total = total + mem
      local name = (C_AddOns and C_AddOns.GetAddOnInfo) and C_AddOns.GetAddOnInfo(i) or "Unknown"
      table.insert(addons, {name = name, mem = mem})
  end
  memTotal = total -- Sync total

  table.sort(addons, function(a,b) return a.mem > b.mem end)

  for i=1, math.min(#addons, 25) do
      local color = (addons[i].mem > 10000) and {1, 0.2, 0.2} or {1, 1, 1}
      GameTooltip:AddDoubleLine(addons[i].name, FormatMem(addons[i].mem), 1,1,1, color[1], color[2], color[3])
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("Total", FormatMem(total), 0.5, 0.5, 1, 0.5, 0.5, 1)
  GameTooltip:AddLine("Click to Garbage Collect", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Move/drag
local function CreateUI()
  anchor = CreateFrame("Frame", "RothInfoStringsAnchor", UIParent)
  anchor:SetSize(160, 42) -- mouse/drag area
  ApplyAnchor()

  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)

  -- Drag hint background (only visible when unlocked)
  local hint = anchor:CreateTexture(nil, "BACKGROUND")
  hint:SetAllPoints(anchor)
  hint:SetColorTexture(0, 0, 0, 0.0)
  anchor.hint = hint

  fs1 = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs2 = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs3 = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

  fs1:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
  fs2:SetPoint("TOPRIGHT", fs1, "BOTTOMRIGHT", 0, -2)
  fs3:SetPoint("TOPRIGHT", fs2, "BOTTOMRIGHT", 0, -4)

  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function(self)
    if DB.locked then return end
    if not IsAltKeyDown() then return end
    if DB.ctrlAltDrag and not IsControlKeyDown() then return end
    self:StartMoving()
  end)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    DB.pos.point, DB.pos.relPoint, DB.pos.x, DB.pos.y = p or "CENTER", rp or "CENTER", math.floor((x or 0)+0.5), math.floor((y or 0)+0.5)
    DB.attachToMinimap = false
  end)

  anchor:SetScript("OnEnter", ShowTooltip)
  anchor:SetScript("OnLeave", function() GameTooltip:Hide() end)
  anchor:SetScript("OnMouseDown", function(self, button)
      if DB.showMem and button == "LeftButton" and not IsAltKeyDown() then
          collectgarbage("collect")
          UpdateMemTotal()
          UpdatePerf()
          ShowTooltip(self)
      end
  end)

  SetLocked(DB.locked)
  if anchor.hint then anchor.hint:SetAlpha(DB.locked and 0 or 0.15) end

  anchor:SetShown(DB.enabled)
end

local function StartPerfTicker()
  if not DB.showPerf then return end
  if perfTicker then perfTicker:Cancel() end
  perfTicker = C_Timer.NewTicker(DB.perfInterval or 2.0, function()
    if anchor and anchor:IsShown() then
      UpdatePerf()
    end
  end)
end

local function StartCoordTicker()
  if not DB.showCoords then return end
  if coordTicker then coordTicker:Cancel() end
  coordTicker = C_Timer.NewTicker(DB.coordInterval or 0.25, function()
    if anchor and anchor:IsShown() then
      UpdateCoords()
    end
  end)
end

local function Slash(msg)
  msg = (msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if msg == "unlock" then
    SetLocked(false)
    print("|cff00ff00RothInfoStrings|r unlocked (ALT-drag, optional CTRL+ALT).")
  elseif msg == "lock" then
    SetLocked(true)
    print("|cff00ff00RothInfoStrings|r locked.")
  elseif msg == "toggle" then
    DB.enabled = not DB.enabled
    anchor:SetShown(DB.enabled)
    if DB.enabled then
        lowFpsDuration = 0 -- Reset protection on manual toggle
        StartPerfTicker()
        if not coordTicker then UpdateCoords() end
    else
        StopTickers()
    end
    print("|cff00ff00RothInfoStrings|r "..(DB.enabled and "enabled" or "disabled"))
  elseif msg == "reset" then
    DB.attachToMinimap = true
    DB.pos = { point="TOPRIGHT", relPoint="TOPRIGHT", x=-20, y=-170 }
    DB.minimapPoint, DB.minimapRelPoint, DB.minimapX, DB.minimapY = "TOPRIGHT", "BOTTOMRIGHT", 0, -6
    ApplyAnchor()
    print("|cff00ff00RothInfoStrings|r position reset.")
  else
    print("|cff00ff00RothInfoStrings|r commands: /ris lock | unlock | toggle | reset")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("UPDATE_FACTION")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("PLAYER_STARTED_MOVING")
f:RegisterEvent("PLAYER_STOPPED_MOVING")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    DB = RothInfoStringsDB
    CopyDefaults(DB, defaults)
    -- Migrate: old default position was BOTTOMRIGHT (-90,90); restore Minimap attach.
    if DB.pos and DB.pos.point == 'BOTTOMRIGHT' and DB.pos.relPoint == 'BOTTOMRIGHT' and DB.pos.x == -90 and DB.pos.y == 90 then
      DB.attachToMinimap = true
    end

    return
  end

  if event == "PLAYER_LOGIN" then
    if not DB then
      DB = RothInfoStringsDB
      CopyDefaults(DB, defaults)
    -- Migrate: old default position was BOTTOMRIGHT (-90,90); restore Minimap attach.
    if DB.pos and DB.pos.point == 'BOTTOMRIGHT' and DB.pos.relPoint == 'BOTTOMRIGHT' and DB.pos.x == -90 and DB.pos.y == 90 then
      DB.attachToMinimap = true
    end

    end
    CreateUI()
    UpdateZone()
    UpdateMemTotal() -- Initial mem
    UpdatePerf()
    UpdateProgress()
    StopTickers()
    StartPerfTicker()

    SLASH_ROTHIS1 = "/ris"
    SlashCmdList.ROTHIS = Slash

    return
  end

  if not DB or not anchor then return end

  if event:find("ZONE_CHANGED") or event == "PLAYER_ENTERING_WORLD" then
    UpdateZone()
    if not coordTicker then UpdateCoords() end
  end

  if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_FACTION" or event == "UPDATE_PENDING_MAIL" then
    UpdateProgress()
  end

  if event == "PLAYER_STARTED_MOVING" then
    StartCoordTicker()
  elseif event == "PLAYER_STOPPED_MOVING" then
    if coordTicker then coordTicker:Cancel(); coordTicker=nil end
    UpdateCoords()
  end
end)

-- Expose a tiny refresh hook for the Settings panel (safe: no extra polling)
_G.RothInfoStrings_Refresh = function()
  if not RothInfoStringsDB or not _G.RothInfoStringsAnchor then return end
  local DB = RothInfoStringsDB
  local a = _G.RothInfoStringsAnchor
  a:ClearAllPoints()
  if DB.attachToMinimap and _G.Minimap then
    a:SetPoint(DB.minimapPoint or "TOPRIGHT", _G.Minimap, DB.minimapRelPoint or "BOTTOMRIGHT", DB.minimapX or 0, DB.minimapY or -6)
  else
    local p = DB.pos or { point="CENTER", relPoint="CENTER", x=0, y=0 }
    a:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
  end
  a:SetScale(DB.scale or 1.0)
  a:SetShown(DB.enabled ~= false)
  SetLocked(DB.locked) -- Update mouse enable state
end
