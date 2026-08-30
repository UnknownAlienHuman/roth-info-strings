local combat = false
local memoryUpdates = 0
local gcCalls = 0
local eventFrame
local tickers = {}
local chat = {}
local xpCalls = 0
local mapMode = "secret-position"
local reputationMode = "secret-table"

local SECRET = setmetatable({}, {
  __tostring = function() error("secret stringified") end,
  __eq = function() error("secret compared") end,
  __lt = function() error("secret compared") end,
  __le = function() error("secret compared") end,
  __index = function() error("secret indexed") end,
})

local function assertEq(actual, expected, message)
  if actual ~= expected then error((message or "assert") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function assertNear(actual, expected, message)
  if type(actual) ~= "number" or math.abs(actual - expected) > 0.001 then
    error((message or "assert") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local realCollect = collectgarbage
collectgarbage = function(command)
  if command == "collect" then gcCalls = gcCalls + 1 end
  return 0
end

local function newObject(objectType, parent)
  local object = {
    objectType = objectType or "Frame", parent = parent, point = "CENTER", relativeTo = parent,
    relativePoint = "CENTER", x = 0, y = 0, scale = 1, shown = true, scripts = {}, events = {},
  }
  function object:CanBeAccessedInContext() return true end
  function object:IsForbidden() return false end
  function object:SetSize(w, h) self.width, self.height = w, h end
  function object:ClearAllPoints() self.point = nil end
  function object:SetPoint(point, relativeTo, relativePoint, x, y)
    self.point, self.relativeTo, self.relativePoint, self.x, self.y = point, relativeTo, relativePoint, x or 0, y or 0
  end
  function object:GetPoint() return self.point, self.relativeTo, self.relativePoint, self.x, self.y end
  function object:SetScale(value) self.scale = value end
  function object:SetMovable(value) self.movable = value end
  function object:SetClampedToScreen(value) self.clamped = value end
  function object:RegisterForDrag(...) self.drag = { ... } end
  function object:EnableMouse(value) self.mouse = value end
  function object:SetShown(value) self.shown = value == true end
  function object:IsShown() return self.shown end
  function object:Show() self.shown = true end
  function object:Hide() self.shown = false end
  function object:SetScript(name, callback) self.scripts[name] = callback end
  function object:StartMoving() self.moving = true end
  function object:StopMovingOrSizing() self.moving = false end
  function object:RegisterEvent(event) self.events[event] = true end
  function object:CreateTexture()
    local texture = newObject("Texture", self)
    function texture:SetAllPoints(value) self.allPoints = value end
    function texture:SetColorTexture(...) self.color = { ... } end
    function texture:SetAlpha(value) self.alpha = value end
    return texture
  end
  function object:CreateFontString()
    local font = newObject("FontString", self)
    function font:SetText(text) self.text = text end
    return font
  end
  return object
end

function canaccessvalue(value) return not rawequal(value, SECRET) end
function issecretvalue(value) return rawequal(value, SECRET) end
function issecrettable(value) return rawequal(value, SECRET) end
function InCombatLockdown() return combat end
function GetTime() return 100 end
function GetMinimapZoneText() return SECRET end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, SECRET, SECRET end
function IsXPUserDisabled() return false end
function UnitLevel() return SECRET end
function GetMaxPlayerLevel() return 80 end
function UnitXP() xpCalls = xpCalls + 1; return 1 end
function UnitXPMax() xpCalls = xpCalls + 1; return 10 end
function HasNewMail() return SECRET end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) chat[#chat + 1] = message end }
UIParent = newObject("Frame")
Minimap = newObject("Frame", UIParent)
SlashCmdList = {}
Settings = nil
EventUtil = nil

C_Map = {
  GetBestMapForUnit = function()
    if mapMode == "secret-map" then return SECRET end
    return 1
  end,
  GetPlayerMapPosition = function()
    if mapMode == "secret-position" then return SECRET end
    local position = newObject("Vector2D")
    function position:GetXY() return 0.42, 0.63 end
    return position
  end,
}
C_Reputation = {
  GetWatchedFactionData = function()
    if reputationMode == "secret-table" then return SECRET end
    return { name = SECRET, reactionText = SECRET, reaction = SECRET }
  end,
}
C_AddOns = {
  UpdateAddOnMemoryUsage = function() memoryUpdates = memoryUpdates + 1 end,
  GetNumAddOns = function() return 2 end,
  GetAddOnMemoryUsage = function(index) return index * 100 end,
  GetAddOnInfo = function(index) return "Addon" .. index end,
}
C_Timer = {
  NewTicker = function(interval, callback)
    local ticker = { interval = interval, callback = callback, cancelled = false }
    function ticker:Cancel() self.cancelled = true end
    tickers[#tickers + 1] = ticker
    return ticker
  end,
}
GameTooltip = {
  SetOwner=function() end, ClearLines=function() end, AddLine=function() end,
  AddDoubleLine=function() end, Show=function() end, Hide=function() end,
}

function CreateFrame(_, name, parent)
  local frame = newObject("Frame", parent or UIParent)
  if not eventFrame then eventFrame = frame end
  if name then _G[name] = frame end
  return frame
end

RothInfoStringsDB = {
  enabled = true, locked = true, scale = 9,
  pos = { point = "BROKEN", relPoint = SECRET, x = 9999, y = -9999 },
  attachToMinimap = false,
  minimapPoint = "BROKEN", minimapRelPoint = "BROKEN",
  showZone = true, showCoords = true, showPerf = true, showMail = true,
  showXPRep = true, showMem = true,
}

assert(loadfile("core.lua"))("RothInfoStrings")
local runtime = assert(_G.RothInfoStrings_Runtime)
local onEvent = assert(eventFrame.scripts.OnEvent)

local secretLoadOK, secretLoadError = pcall(onEvent, eventFrame, "ADDON_LOADED", SECRET)
assertEq(secretLoadOK, true, "secret addon name escaped boundary: " .. tostring(secretLoadError))
onEvent(eventFrame, "ADDON_LOADED", "RothInfoStrings")
onEvent(eventFrame, "PLAYER_LOGIN")

local db = runtime.GetDB()
assertEq(db.version, 2, "schema version")
assertNear(db.scale, 2.0, "scale clamp")
assertEq(db.pos.point, "TOPRIGHT", "point sanitize")
assertEq(db.pos.relPoint, "TOPRIGHT", "relative point sanitize")
assertEq(db.pos.x, 4000, "x clamp")
assertEq(db.pos.y, -4000, "y clamp")
assertEq(db.minimapPoint, "TOPRIGHT", "minimap point sanitize")
assertEq(db.minimapRelPoint, "BOTTOMRIGHT", "minimap relative point sanitize")

assertEq(memoryUpdates, 0, "login memory scan must be absent")
assertEq(runtime.SafeText(SECRET, "SV"), "SV", "secret formatting")
assertEq(runtime.FormatMemory(SECRET), "?", "secret memory formatting")
assertEq(#tickers, 1, "only performance ticker should run while stationary")
tickers[1].callback()
assertEq(memoryUpdates, 0, "performance ticker sampled memory")
assertEq(xpCalls, 0, "XP APIs reached after inaccessible level")

local updateFactionOK, updateFactionError = pcall(onEvent, eventFrame, "UPDATE_FACTION")
assertEq(updateFactionOK, true, "secret reputation table escaped: " .. tostring(updateFactionError))
mapMode = "ordinary"
reputationMode = "secret-fields"
local zoneOK, zoneError = pcall(onEvent, eventFrame, "ZONE_CHANGED")
assertEq(zoneOK, true, "coordinate refresh failed: " .. tostring(zoneError))
onEvent(eventFrame, "UPDATE_FACTION")
assertEq(xpCalls, 0, "XP APIs reached after secret level on reputation refresh")

local total = runtime.SampleMemory(false)
assertEq(total, 300, "manual memory sample total")
assertEq(memoryUpdates, 1, "memory sampling must be explicit")

local anchor = assert(runtime.GetAnchor())
local oldScale = anchor.scale
RothInfoStringsDB.scale = 1.5
combat = true
_G.RothInfoStrings_Refresh()
assertEq(anchor.scale, oldScale, "refresh mutated UI in combat")
anchor.scripts.OnMouseDown(anchor, "LeftButton")
assertEq(gcCalls, 0, "garbage collection ran in combat")
combat = false
onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assertNear(anchor.scale, 1.5, "deferred scale did not apply")
anchor.scripts.OnMouseDown(anchor, "LeftButton")
assertEq(gcCalls, 1, "explicit out-of-combat GC did not run")
assertEq(memoryUpdates, 2, "explicit click did not sample memory")

local beforeMoving = #tickers
onEvent(eventFrame, "PLAYER_STARTED_MOVING")
assertEq(#tickers, beforeMoving + 1, "coordinate ticker missing while moving")
local coordinateTicker = tickers[#tickers]
onEvent(eventFrame, "PLAYER_STOPPED_MOVING")
assertEq(coordinateTicker.cancelled, true, "coordinate ticker not cancelled")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local content = handle:read("*a")
  handle:close()
  return content
end
local runtimeText = read("core.lua")
for _, forbidden in ipairs({ "OnUpdate", "RothLib", "Info.xml", "InterfaceOptions_AddCategory", "COMBAT_LOG_EVENT_UNFILTERED" }) do
  assert(not runtimeText:find(forbidden, 1, true), "forbidden token: " .. forbidden)
end
assert(runtimeText:find("SampleMemory", 1, true), "on-demand memory owner missing")
assert(runtimeText:find("SafeTable", 1, true), "safe table boundary missing")

collectgarbage = realCollect
print("PASS: inaccessible values fail closed, anchors sanitize, memory/GC are explicit, and refresh defers in combat")
