-- User-facing ESC forward-programming error text.

if package.loaded["rfsuite.app.esc_error"] then
  return package.loaded["rfsuite.app.esc_error"]
end

local esc_error = {}

local ERR_NO_RESPONSE = "@i18n(app.modules.esc_tools.error_no_response)@"
local ERR_CHECK_POWER = "@i18n(app.modules.esc_tools.error_check_power)@"
local ERR_BUSY = "@i18n(app.modules.esc_tools.error_busy)@"
local ERR_FAILED = "@i18n(app.modules.esc_tools.error_failed)@"
local ERR_DETAIL = "@i18n(app.modules.esc_tools.error_detail)@"
local ERR_BACK = "@i18n(app.modules.esc_tools.error_back)@"
local ERR_WRONG_ESC = "@i18n(app.modules.esc_tools.error_wrong_esc)@"
local ERR_CHOOSE_ESC = "@i18n(app.modules.esc_tools.error_choose_esc)@"

local function cleanReason(reason)
  if type(reason) ~= "string" then return nil end
  if reason == "" or reason == "true" or reason == "false" then return nil end
  return reason
end

function esc_error.lines(reason)
  if type(reason) == "table" and reason.kind == "signature" then
    return ERR_WRONG_ESC, ERR_CHOOSE_ESC, ERR_BACK
  end

  if reason == true or reason == "max_retries" or reason == "timeout" then
    return ERR_NO_RESPONSE, ERR_CHECK_POWER, ERR_BACK
  end
  if reason == "queue_full" then
    return ERR_BUSY, ERR_BACK
  end

  local detail = cleanReason(reason)
  if detail then
    return ERR_FAILED, ERR_DETAIL .. detail, ERR_BACK
  end
  return ERR_FAILED, ERR_CHECK_POWER, ERR_BACK
end

local function fullLineRect(slots)
  local slot = slots and slots[1] or {}
  local width = nil
  if lcd and lcd.getWindowSize then
    width = lcd.getWindowSize()
  end
  return {
    x = 0,
    y = slot.y or 0,
    w = width or slot.w or 0,
    h = slot.h or 0,
  }
end

function esc_error.addTextLine(text)
  local line = form.addLine("")
  local slots = form.getFieldSlots(line, {0})
  form.addStaticText(line, fullLineRect(slots), text, LEFT)
end

function esc_error.addLines(reason)
  local line1, line2, line3 = esc_error.lines(reason)
  esc_error.addTextLine(line1)
  if line2 then esc_error.addTextLine(line2) end
  if line3 then esc_error.addTextLine(line3) end
end

package.loaded["rfsuite.app.esc_error"] = esc_error
return esc_error
