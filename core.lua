-- RothInfoStrings runtime owner for Retail 12.1.
-- Event-driven display with access-first value handling and on-demand addon-memory profiling.

local ADDON = ...
RothInfoStringsDB = type(RothInfoStringsDB) == "table" and RothInfoStringsDB or {}

local DB_VERSION = 2
local defaults = {
  version = DB_VERSION,
  enabled = true,
  locked = true,
  scale = 1.0,
  pos = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -170 },
  attachToMinimap = true,
  minimapPoint = "TOPRIGHT",
  minimapRelPoint = "BOTTOMRIGHT",
  minimapX = 0,
  minimapY = -6,
  ctrlAltDrag = true,
  showZone = true,
  showCoords = true,
  showPerf = true,
  showMail = true,
  showXPRep = true,
  showMem = true,
  perfInterval = 2.0,
  coordInterval = 0.5,
}

local VALID_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true,
  LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local DB
local anchor, zoneLine, perfLine, progressLine
local perfTicker, coordTicker
local moving = false
local initialized = false
local pendingRefresh = false
local memoryTotal
local memorySampleTime

local function CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end

local function SafeBoolean(value)
  if not CanAccess(value) or type(value) ~= "boolean" then return nil end
  return value
end

local function SafeNumber(value)
  if not CanAccess(value) or type(value) ~= "number" or value ~= value then return nil end
  return value
end

local function SafeString(value)
  if not CanAccess(value) or type(value) ~= "string" then return nil end
  return value
end

local function SafeTable(value)
  if not CanAccess(value) or type(value) ~= "table" then return nil end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret == true then return nil end
  end
  return value
end

local function InCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, value = pcall(InCombatLockdown)
  return ok and SafeBoolean(value) == true
end

local function CanUseObject(object)
  if not CanAccess(object) then return false end
  local objectType = type(object)
  if objectType ~= "table" and objectType ~= "userdata" then return false end

  local okAccessMethod, accessMethod = pcall(function() return object.CanBeAccessedInContext end)
  if not okAccessMethod then return false end
  if type(accessMethod) == "function" then
    local ok, accessible = pcall(accessMethod, object)
    if not ok or SafeBoolean(accessible) ~= true then return false end
  end

  local okForbiddenMethod, forbiddenMethod = pcall(function() return object.IsForbidden end)
  if not okForbiddenMethod then return false end
  if type(forbiddenMethod) == "function" then
    local ok, forbidden = pcall(forbiddenMethod, object)
    if not ok or SafeBoolean(forbidden) ~= false then return false end
  end
  return true
end

local function MergeDefaults(target, source)
  if type(target) ~= "table" then target = {} end
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = MergeDefaults(target[key], value)
    elseif type(target[key]) ~= type(value) then
      target[key] = value
    end
  end
  return target
end

local function ClampNumber(value, fallback, minimum, maximum)
  value = SafeNumber(value)
  if value == nil then return fallback end
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function SafePoint(value, fallback)
  value = SafeString(value)
  return value and VALID_POINTS[value] and value or fallback
end

local function SanitizeDB()
  DB = MergeDefaults(SafeTable(RothInfoStringsDB) or {}, defaults)
  RothInfoStringsDB = DB

  DB.version = DB_VERSION
  for _, key in ipairs({
    "enabled", "locked", "attachToMinimap", "ctrlAltDrag", "showZone",
    "showCoords", "showPerf", "showMail", "showXPRep", "showMem",
  }) do
    local defaultValue = defaults[key]
    local value = SafeBoolean(DB[key])
    DB[key] = value == nil and defaultValue or value
  end

  DB.scale = ClampNumber(DB.scale, defaults.scale, 0.6, 2.0)
  DB.perfInterval = ClampNumber(DB.perfInterval, defaults.perfInterval, 0.5, 10.0)
  DB.coordInterval = ClampNumber(DB.coordInterval, defaults.coordInterval, 0.1, 2.0)
  DB.minimapX = math.floor(ClampNumber(DB.minimapX, defaults.minimapX, -1000, 1000) + 0.5)
  DB.minimapY = math.floor(ClampNumber(DB.minimapY, defaults.minimapY, -1000, 1000) + 0.5)
  DB.minimapPoint = SafePoint(DB.minimapPoint, defaults.minimapPoint)
  DB.minimapRelPoint = SafePoint(DB.minimapRelPoint, defaults.minimapRelPoint)

  DB.pos = SafeTable(DB.pos) or {}
  DB.pos.point = SafePoint(DB.pos.point, defaults.pos.point)
  DB.pos.relPoint = SafePoint(DB.pos.relPoint, defaults.pos.relPoint)
  DB.pos.x = math.floor(ClampNumber(DB.pos.x, defaults.pos.x, -4000, 4000) + 0.5)
  DB.pos.y = math.floor(ClampNumber(DB.pos.y, defaults.pos.y, -4000, 4000) + 0.5)

  if DB.pos.point == "BOTTOMRIGHT" and DB.pos.relPoint == "BOTTOMRIGHT"
    and DB.pos.x == -90 and DB.pos.y == 90 then
    DB.attachToMinimap = true
  end

  DB.pendingRefresh = nil
  DB.memoryTotal = nil
  return DB
end

local function SafeText(value, fallback)
  local text = SafeString(value)
  if text then return text end
  local number = SafeNumber(value)
  if number ~= nil then return tostring(number) end
  return fallback or ""
end

local function FormatMemory(kilobytes)
  kilobytes = SafeNumber(kilobytes)
  if kilobytes == nil or kilobytes < 0 then return "?" end
  if kilobytes >= 1024 then return string.format("%.1f MB", kilobytes / 1024) end
  return string.format("%.0f KB", kilobytes)
end

local function StopTicker(ticker)
  if ticker and type(ticker.Cancel) == "function" then pcall(ticker.Cancel, ticker) end
end

local function StopTickers()
  StopTicker(perfTicker)
  StopTicker(coordTicker)
  perfTicker, coordTicker = nil, nil
end

local function ApplyAnchor()
  if not anchor then return false end
  if InCombat() then pendingRefresh = true return false end

  anchor:ClearAllPoints()
  if DB.attachToMinimap and CanUseObject(_G.Minimap) then
    anchor:SetPoint(DB.minimapPoint, _G.Minimap, DB.minimapRelPoint, DB.minimapX, DB.minimapY)
  else
    anchor:SetPoint(DB.pos.point, UIParent, DB.pos.relPoint, DB.pos.x, DB.pos.y)
  end
  anchor:SetScale(DB.scale)
  return true
end

local function ApplyLockState()
  if not anchor then return end
  anchor:SetMovable(true)
  anchor:EnableMouse((not DB.locked) or DB.showMem)
  if anchor.hint then anchor.hint:SetAlpha(DB.locked and 0 or 0.15) end
end

local function GetZoneText()
  if not DB.showZone or type(GetMinimapZoneText) ~= "function" then return "" end
  local ok, zone = pcall(GetMinimapZoneText)
  return ok and SafeString(zone) or ""
end

local function GetCoordinatesText()
  if not DB.showCoords or not C_Map then return nil end
  if type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then return nil end

  local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = okMap and SafeNumber(mapID) or nil
  if mapID == nil then return nil end

  local okPosition, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not okPosition or not CanUseObject(position) then return nil end
  local okMethod, getXY = pcall(function() return position.GetXY end)
  if not okMethod or type(getXY) ~= "function" then return nil end
  local ok, x, y = pcall(getXY, position)
  x, y = ok and SafeNumber(x) or nil, ok and SafeNumber(y) or nil
  if not x or not y or x <= 0 or y <= 0 then return nil end

  return string.format("%02d/%02d", math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5))
end

local function UpdateZoneAndCoordinates()
  if not zoneLine then return end
  local zone = GetZoneText()
  local coordinates = GetCoordinatesText()
  if coordinates then
    zoneLine:SetText(string.format("%s |cff9C907D[%s]|r", zone, coordinates))
  else
    zoneLine:SetText(zone)
  end
end

local function SampleMemory(includeRows)
  if not C_AddOns then return nil, nil end
  if type(C_AddOns.UpdateAddOnMemoryUsage) == "function" then pcall(C_AddOns.UpdateAddOnMemoryUsage) end

  local count
  if type(C_AddOns.GetNumAddOns) == "function" then
    local ok, value = pcall(C_AddOns.GetNumAddOns)
    count = ok and SafeNumber(value) or nil
  end
  if count == nil then return nil, nil end
  count = math.max(0, math.floor(count))

  local total = 0
  local rows = includeRows and {} or nil
  for index = 1, count do
    local memory
    if type(C_AddOns.GetAddOnMemoryUsage) == "function" then
      local ok, value = pcall(C_AddOns.GetAddOnMemoryUsage, index)
      memory = ok and SafeNumber(value) or nil
    end
    if memory and memory >= 0 then
      total = total + memory
      if rows then
        local name
        if type(C_AddOns.GetAddOnInfo) == "function" then
          local ok, value = pcall(C_AddOns.GetAddOnInfo, index)
          name = ok and SafeString(value) or nil
        end
        rows[#rows + 1] = { name = name or "Unknown", memory = memory }
      end
    end
  end

  memoryTotal = total
  if type(GetTime) == "function" then
    local ok, value = pcall(GetTime)
    memorySampleTime = ok and SafeNumber(value) or nil
  end
  return total, rows
end

local function UpdatePerformance()
  if not perfLine then return end
  if not DB.showPerf then perfLine:SetText("") return end

  local fps
  if type(GetFramerate) == "function" then
    local ok, value = pcall(GetFramerate)
    fps = ok and SafeNumber(value) or nil
  end

  local homeMS, worldMS
  if type(GetNetStats) == "function" then
    local ok, _, _, home, world = pcall(GetNetStats)
    if ok then homeMS, worldMS = SafeNumber(home), SafeNumber(world) end
  end

  local fpsText = fps and tostring(math.floor(fps + 0.5)) or "SV"
  local homeText = homeMS and tostring(math.floor(homeMS + 0.5)) or "SV"
  local worldText = worldMS and tostring(math.floor(worldMS + 0.5)) or "SV"
  local memoryText = ""
  if DB.showMem then
    memoryText = memoryTotal and ("  |cff00ccff" .. FormatMemory(memoryTotal) .. "|r")
      or "  |cff888888mem on hover|r"
  end
  perfLine:SetText(string.format("%sms/%sms  %sfps%s", homeText, worldText, fpsText, memoryText))
end

local function GetXPText()
  if not DB.showXPRep then return "" end

  if type(IsXPUserDisabled) == "function" then
    local ok, value = pcall(IsXPUserDisabled)
    local disabled = ok and SafeBoolean(value) or nil
    if disabled == nil or disabled then return "" end
  end

  local level, maximumLevel
  if type(UnitLevel) == "function" then
    local ok, value = pcall(UnitLevel, "player")
    level = ok and SafeNumber(value) or nil
  end
  if type(GetMaxPlayerLevel) == "function" then
    local ok, value = pcall(GetMaxPlayerLevel)
    maximumLevel = ok and SafeNumber(value) or nil
  end
  maximumLevel = maximumLevel or 80
  if level == nil or level >= maximumLevel then return "" end

  local current, maximum
  if type(UnitXP) == "function" then
    local ok, value = pcall(UnitXP, "player")
    current = ok and SafeNumber(value) or nil
  end
  if type(UnitXPMax) == "function" then
    local ok, value = pcall(UnitXPMax, "player")
    maximum = ok and SafeNumber(value) or nil
  end
  if current == nil or maximum == nil or maximum <= 0 then return "" end
  return string.format("XP: %.0f/%.0f", current, maximum)
end

local function GetReputationText()
  if not DB.showXPRep or not C_Reputation or type(C_Reputation.GetWatchedFactionData) ~= "function" then return "" end

  local ok, value = pcall(C_Reputation.GetWatchedFactionData)
  local data = ok and SafeTable(value) or nil
  if not data then return "" end

  local name = SafeString(data.name) or "Reputation"
  local reactionText = SafeString(data.reactionText)
  local reaction = SafeNumber(data.reaction)
  if not reactionText and reaction then
    local key = "FACTION_STANDING_LABEL" .. tostring(math.floor(reaction))
    reactionText = SafeString(_G[key])
  end

  if reactionText then return "REP: " .. name .. " " .. reactionText end
  return "REP: " .. name
end

local function UpdateProgress()
  if not progressLine then return end
  local parts = {}

  if DB.showMail and type(HasNewMail) == "function" then
    local ok, value = pcall(HasNewMail)
    local hasMail = ok and SafeBoolean(value) or nil
    if hasMail then parts[#parts + 1] = "|cffff66ccMAIL|r" end
  end

  local xp = GetXPText()
  if xp ~= "" then
    parts[#parts + 1] = xp
  else
    local reputation = GetReputationText()
    if reputation ~= "" then parts[#parts + 1] = reputation end
  end
  progressLine:SetText(table.concat(parts, "  "))
end

local function ShowMemoryTooltip(owner)
  if not DB.showMem or not GameTooltip or InCombat() then return end
  local total, rows = SampleMemory(true)
  if total == nil or not rows then return end
  table.sort(rows, function(a, b) return a.memory > b.memory end)

  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("AddOn Memory Usage", 1, 1, 1)
  for index = 1, math.min(#rows, 25) do
    local row = rows[index]
    local red = row.memory > 10000
    GameTooltip:AddDoubleLine(row.name, FormatMemory(row.memory), 1, 1, 1, 1, red and 0.2 or 1, red and 0.2 or 1)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("Total", FormatMemory(total), 0.5, 0.5, 1, 0.5, 0.5, 1)
  GameTooltip:AddLine("Click to run garbage collection", 0.6, 0.6, 0.6)
  GameTooltip:Show()
  UpdatePerformance()
end

local function StartPerfTicker()
  StopTicker(perfTicker)
  perfTicker = nil
  if not DB.enabled or not DB.showPerf or not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
  perfTicker = C_Timer.NewTicker(DB.perfInterval, function()
    if anchor and anchor:IsShown() then UpdatePerformance() end
  end)
end

local function StartCoordTicker()
  StopTicker(coordTicker)
  coordTicker = nil
  if not DB.enabled or not DB.showCoords or not moving or not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
  coordTicker = C_Timer.NewTicker(DB.coordInterval, function()
    if anchor and anchor:IsShown() then UpdateZoneAndCoordinates() end
  end)
end

local function CreateUI()
  if anchor then return end
  anchor = CreateFrame("Frame", "RothInfoStringsAnchor", UIParent)
  anchor:SetSize(180, 46)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  anchor:RegisterForDrag("LeftButton")

  local hint = anchor:CreateTexture(nil, "BACKGROUND")
  hint:SetAllPoints(anchor)
  hint:SetColorTexture(0, 0, 0, 0)
  anchor.hint = hint

  zoneLine = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  perfLine = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  progressLine = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  zoneLine:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
  perfLine:SetPoint("TOPRIGHT", zoneLine, "BOTTOMRIGHT", 0, -2)
  progressLine:SetPoint("TOPRIGHT", perfLine, "BOTTOMRIGHT", 0, -4)

  anchor:SetScript("OnDragStart", function(self)
    if DB.locked or InCombat() then return end
    if type(IsAltKeyDown) == "function" and not IsAltKeyDown() then return end
    if DB.ctrlAltDrag and type(IsControlKeyDown) == "function" and not IsControlKeyDown() then return end
    self:StartMoving()
  end)

  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    point, relativePoint = SafeString(point), SafeString(relativePoint)
    x, y = SafeNumber(x), SafeNumber(y)
    if point and VALID_POINTS[point] and relativePoint and VALID_POINTS[relativePoint] and x and y then
      DB.pos.point, DB.pos.relPoint = point, relativePoint
      DB.pos.x, DB.pos.y = math.floor(x + 0.5), math.floor(y + 0.5)
      DB.attachToMinimap = false
    end
  end)

  anchor:SetScript("OnEnter", ShowMemoryTooltip)
  anchor:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  anchor:SetScript("OnMouseDown", function(self, button)
    if InCombat() then return end
    if DB.showMem and button == "LeftButton" and (type(IsAltKeyDown) ~= "function" or not IsAltKeyDown()) then
      collectgarbage("collect")
      ShowMemoryTooltip(self)
    end
  end)
end

local function Refresh()
  if not initialized then return end
  SanitizeDB()
  if InCombat() then pendingRefresh = true return end

  pendingRefresh = false
  ApplyAnchor()
  ApplyLockState()
  anchor:SetShown(DB.enabled)
  StopTickers()
  if DB.enabled then
    UpdateZoneAndCoordinates()
    UpdatePerformance()
    UpdateProgress()
    StartPerfTicker()
    StartCoordTicker()
  end
end

local function ResetPosition()
  DB.attachToMinimap = true
  DB.pos = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -170 }
  DB.minimapPoint, DB.minimapRelPoint, DB.minimapX, DB.minimapY = "TOPRIGHT", "BOTTOMRIGHT", 0, -6
  Refresh()
end

local function Print(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(message) else print(message) end
end

local function Slash(message)
  message = SafeString(message)
  message = message and message:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  if not DB then SanitizeDB() end

  if message == "unlock" then
    DB.locked = false; Refresh(); Print("|cff00ff00RothInfoStrings|r unlocked (ALT-drag; CTRL+ALT when required).")
  elseif message == "lock" then
    DB.locked = true; Refresh(); Print("|cff00ff00RothInfoStrings|r locked.")
  elseif message == "toggle" then
    DB.enabled = not DB.enabled; Refresh(); Print("|cff00ff00RothInfoStrings|r " .. (DB.enabled and "enabled" or "disabled"))
  elseif message == "reset" then
    ResetPosition(); Print("|cff00ff00RothInfoStrings|r position reset.")
  elseif message == "memory" then
    if anchor then ShowMemoryTooltip(anchor) end
  elseif message == "config" and _G.RothInfoStrings_SettingsCategoryID and Settings then
    Settings.OpenToCategory(_G.RothInfoStrings_SettingsCategoryID)
  else
    Print("|cff00ff00RothInfoStrings|r commands: /ris lock | unlock | toggle | reset | memory | config")
  end
end

SLASH_ROTHIS1 = "/ris"
SlashCmdList.ROTHIS = Slash

local EventFrame = CreateFrame("Frame")
for _, event in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
  "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_XP_UPDATE",
  "PLAYER_LEVEL_UP", "UPDATE_FACTION", "UPDATE_PENDING_MAIL", "PLAYER_STARTED_MOVING",
  "PLAYER_STOPPED_MOVING",
}) do
  EventFrame:RegisterEvent(event)
end

EventFrame:SetScript("OnEvent", function(_, event, argument)
  if event == "ADDON_LOADED" then
    local name = SafeString(argument)
    if name == ADDON then SanitizeDB() end
    return
  end

  if event == "PLAYER_LOGIN" then
    if not DB then SanitizeDB() end
    CreateUI()
    initialized = true
    Refresh()
    return
  end
  if not initialized then return end

  if event == "PLAYER_REGEN_ENABLED" then
    if pendingRefresh then Refresh() end
  elseif event == "PLAYER_STARTED_MOVING" then
    moving = true
    StartCoordTicker()
  elseif event == "PLAYER_STOPPED_MOVING" then
    moving = false
    StopTicker(coordTicker)
    coordTicker = nil
    UpdateZoneAndCoordinates()
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP"
    or event == "UPDATE_FACTION" or event == "UPDATE_PENDING_MAIL" then
    UpdateProgress()
  elseif event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED", 1, true) then
    UpdateZoneAndCoordinates()
  end
end)

_G.RothInfoStrings_Refresh = Refresh
_G.RothInfoStrings_Runtime = {
  Refresh = Refresh,
  SampleMemory = SampleMemory,
  SafeText = SafeText,
  FormatMemory = FormatMemory,
  GetMemorySampleTime = function() return memorySampleTime end,
  GetDB = function() return DB end,
  GetAnchor = function() return anchor end,
}
