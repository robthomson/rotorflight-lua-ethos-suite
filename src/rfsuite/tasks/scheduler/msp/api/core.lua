--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local utils = rfsuite.utils
local math_min = math.min
local math_floor = math.floor
local table_insert = table.insert
local string_format = string.format
local type = type
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local error = error

local core = {}

local mspHelper = rfsuite.tasks.msp.mspHelper
local callback  = rfsuite.tasks.callback

-- Schedule a callback to run next wakeup
function core.scheduleWakeup(func)
    if callback and callback.now then
        callback.now(func)
    else
        utils.log("ERROR: callback.now() is missing!", "info")
    end
end

-- Type size lookup
------------------------------------------------------------

local TYPE_SIZES = {
    U8=1, S8=1, U16=2, S16=2, U24=3, S24=3, U32=4, S32=4,
    U40=5, S40=5, U48=6, S48=6, U56=7, S56=7, U64=8, S64=8,
    U72=9, S72=9, U80=10, S80=10, U88=11, S88=11,
    U96=12, S96=12, U104=13, S104=13, U112=14, S112=14,
    U120=15, S120=15, U128=16, S128=16, U256=32, S256=32
}

local function get_type_size(data_type)
    if data_type == nil then return TYPE_SIZES end
    return TYPE_SIZES[data_type] or 1
end

-- Full MSP data parsing (supports chunked mode)
------------------------------------------------------------

function core.parseMSPData(API_NAME, buf, structure, processed, other, options)
    -- Normalize options
    if type(options) == "function" then
        -- Default to direct parsing (no deferred callback queue churn).
        -- APIs can still force chunked mode via options={chunked=true,...}.
        options = {chunked = false, completionCallback = options}
    elseif type(options) ~= "table" then
        options = {}
    end

    local keepBuffers = false
    local apidata = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata
    if apidata then
        apidata._lastReadMode = apidata._lastReadMode or {}
        apidata._lastReadMode[API_NAME] = "parsed"
    end

    local chunked            = (options.chunked == true)
    local fieldsPerTick      = options.fieldsPerTick or 10
    local completionCallback = options.completionCallback

    ------------------------------------------------------------
    -- Chunked parsing (spread across wakeups)
    ------------------------------------------------------------
    if chunked then
        local state = {
            index = 1,
            parsedData = {},
            positionmap = keepBuffers and {} or nil,
            processed = processed or {},
            other = other or {},
            currentByte = 1,
            fieldsPerTick = fieldsPerTick,
            completionCallback = completionCallback
        }

        local function processNextChunk()
            local processedFields = 0

            while state.index <= #structure and processedFields < fieldsPerTick do
                local field = structure[state.index]
                state.index = state.index + 1

                if field.apiVersion and utils.apiVersionCompare("<", field.apiVersion) then goto continue end

                local readFunction = mspHelper["read" .. field.type]
                if not readFunction then
                    utils.log("Error: Unknown type " .. field.type, "debug")
                    return
                end

                local data = readFunction(buf, field.byteorder or "little")
                state.parsedData[field.field] = data

                local size = get_type_size(field.type)
                local startByte = state.currentByte
                local endByte = startByte + size - 1

                if keepBuffers then
                    state.positionmap[field.field] = {start = startByte, size = size}
                end
                state.currentByte = endByte + 1

                processedFields = processedFields + 1
                ::continue::
            end

            utils.log("[" .. API_NAME .. "] Processed chunk", "debug")

            if state.index > #structure then
                -- All fields parsed
                local final = {
                    parsed = state.parsedData,
                    buffer = nil,
                    structure = structure,
                    positionmap = nil,
                    processed = state.processed,
                    other = state.other,
                    receivedBytesCount = math_floor((buf.offset or 1) - 1)
                }
                if completionCallback then completionCallback(final) end
            else
                core.scheduleWakeup(processNextChunk)
            end
        end

        processNextChunk()
        return nil
    end

    ------------------------------------------------------------
    -- Non-chunked: parse everything now
    ------------------------------------------------------------

    local parsedData = {}
    buf.offset = 1

    local typeSizes = get_type_size()
    local position_map = keepBuffers and {} or nil
    local current_byte = 1

    for _, field in ipairs(structure) do
        if field.apiVersion and utils.apiVersionCompare("<", field.apiVersion) then goto continue end

        local readFunction = mspHelper["read" .. field.type]
        if not readFunction then
            utils.log("Error: Unknown type " .. field.type, "debug")
            return nil
        end

        local data = readFunction(buf, field.byteorder or "little")
        parsedData[field.field] = data

        local size = typeSizes[field.type]
        if keepBuffers then
            position_map[field.field] = {start = current_byte, size = size}
        end
        current_byte = current_byte + size

        ::continue::
    end

    local final = {
        parsed = parsedData,
        buffer = nil,
        structure = structure,
        positionmap = nil,
        processed = processed,
        other = other,
        receivedBytesCount = math_floor(buf.offset - 1)
    }

    completionCallback(final)
end

------------------------------------------------------------
-- Structure analysis helpers
------------------------------------------------------------

-- Completion / error handler helpers
------------------------------------------------------------

function core.createHandlers()
    local completeHandler = nil
    local privateErrorHandler = nil

    return {
        setCompleteHandler = function(fn)
            if type(fn) == "function" then completeHandler = fn
            else error("Complete handler requires function") end
        end,
        setErrorHandler = function(fn)
            if type(fn) == "function" then privateErrorHandler = fn
            else error("Error handler requires function") end
        end,
        getCompleteHandler = function() return completeHandler end,
        getErrorHandler = function() return privateErrorHandler end
    }
end

------------------------------------------------------------
-- Payload builders
------------------------------------------------------------

local DEFAULT_WRITE_BUILD_FIELDS_PER_TICK = 6

local function buildActualFieldMap()
    local actual_fields = {}
    local page = rfsuite.app and rfsuite.app.Page
    local apidata = page and page.apidata
    local formdata = apidata and apidata.formdata
    local fields = formdata and formdata.fields
    if type(fields) ~= "table" then
        return actual_fields
    end

    for _, field in ipairs(fields) do
        if field.apikey then
            actual_fields[field.apikey] = field
        end
    end

    return actual_fields
end

local function syncUiMetadata(field_def, actual, includeDecimals)
    if not actual then return end

    field_def.scale = field_def.scale or actual.scale
    field_def.mult = field_def.mult or actual.mult
    field_def.step = field_def.step or actual.step
    field_def.min = field_def.min or actual.min
    field_def.max = field_def.max or actual.max
    if includeDecimals then
        field_def.decimals = field_def.decimals or actual.decimals
    end
end

local function resolveScaledWriteValue(payload, field_def, actual)
    local value = payload[field_def.field] or field_def.default or 0
    local scale = field_def.scale or 1

    if not actual and field_def.decimals then
        scale = scale / utils.decimalInc(field_def.decimals)
    end

    return math_floor(value * scale + 0.5)
end

local function appendEncodedField(byte_stream, tmp, field_def, value)
    local writeFunction = mspHelper["write" .. field_def.type]
    if not writeFunction then
        return nil, "Unknown type " .. tostring(field_def.type)
    end

    for i = 1, #tmp do
        tmp[i] = nil
    end

    if field_def.byteorder then
        writeFunction(tmp, value, field_def.byteorder)
    else
        writeFunction(tmp, value)
    end

    for i = 1, #tmp do
        table_insert(byte_stream, tmp[i])
    end

    return true
end

local function normalizeWriteBuildOptions(options)
    if type(options) == "table" then
        local completionCallback = options._writeBuildCompletionCallback or options.completionCallback
        local fieldsPerTick = tonumber(options.writeBuildFieldsPerTick or options.fieldsPerTick)
        if fieldsPerTick == nil or fieldsPerTick < 1 then
            fieldsPerTick = DEFAULT_WRITE_BUILD_FIELDS_PER_TICK
        else
            fieldsPerTick = math_floor(fieldsPerTick)
        end

        return {
            noDelta = options.rebuildOnWrite == true or options.noDelta == true,
            completionCallback = completionCallback,
            fieldsPerTick = fieldsPerTick
        }
    end

    return {
        noDelta = (options == true),
        completionCallback = nil,
        fieldsPerTick = DEFAULT_WRITE_BUILD_FIELDS_PER_TICK
    }
end

local function finalizeChunkedBuild(state, payload, err)
    local done = state and state.completionCallback
    if not done then return end
    state.completionCallback = nil
    done(payload, err)
end

local processNextFullBuildChunk

function core.buildFullPayloadChunked(apiname, payload, api_structure, options, completionCallback)
    if type(completionCallback) ~= "function" then
        return false, "completion_callback_missing"
    end

    local opts = normalizeWriteBuildOptions(options)
    local buildState = {
        apiname = apiname,
        payload = payload,
        api_structure = api_structure,
        index = 1,
        byte_stream = {},
        actual_fields = buildActualFieldMap(),
        tmp = {},
        fieldsPerTick = opts.fieldsPerTick,
        completionCallback = completionCallback
    }

    buildState.step = function()
        processNextFullBuildChunk(buildState)
    end

    core.scheduleWakeup(buildState.step)
    return true
end

processNextFullBuildChunk = function(state)
    local processedFields = 0
    local api_structure = state.api_structure
    local payload = state.payload
    local actual_fields = state.actual_fields
    local byte_stream = state.byte_stream
    local tmp = state.tmp

    while state.index <= #api_structure and processedFields < state.fieldsPerTick do
        local field_def = api_structure[state.index]
        state.index = state.index + 1

        local name = field_def.field
        local actual = actual_fields[name]
        syncUiMetadata(field_def, actual, true)

        local value = resolveScaledWriteValue(payload, field_def, actual)
        local ok, err = appendEncodedField(byte_stream, tmp, field_def, value)
        if not ok then
            finalizeChunkedBuild(state, nil, err)
            return
        end

        processedFields = processedFields + 1
        utils.log(string_format("[buildFullPayloadChunked] Wrote field '%s' = %d", name, value), "debug")
    end

    if state.index > #api_structure then
        finalizeChunkedBuild(state, byte_stream)
        return
    end

    core.scheduleWakeup(state.step)
end

-- Choose full vs delta payload based on available previous data
function core.buildWritePayload(apiname, payload, api_structure, options)
    if not rfsuite.app.Page then
        utils.log("[buildWritePayload] No page context", "info")
        -- tasks have no UI context; always build a full payload
        return core.buildFullPayload(apiname, payload, api_structure)
    end

    local buildOptions = normalizeWriteBuildOptions(options)

    local apidata = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata

    if apidata then
        apidata._lastWriteMode = apidata._lastWriteMode or {}
        apidata._lastWriteMode[apiname] = (buildOptions.completionCallback and buildOptions.noDelta == true) and "rebuild-chunked" or "full"
    end

    if buildOptions.completionCallback and buildOptions.noDelta == true then
        local ok, err = core.buildFullPayloadChunked(apiname, payload, api_structure, buildOptions, buildOptions.completionCallback)
        if not ok then
            return nil, err or "build_payload_failed"
        end
        return nil, "pending"
    end

    return core.buildFullPayload(apiname, payload, api_structure)
end

-- Build delta payload (patch only changed bytes)
function core.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    local byte_stream = {}

    -- Clone previous data for patching
    for i = 1, receivedBytesCount or 0 do
        byte_stream[i] = receivedBytes and receivedBytes[i] or 0
    end

    -- Determine which fields are editable
    local editableFields = {}
    for idx, formField in ipairs(rfsuite.app.formFields) do
        local pageField = rfsuite.app.Page.apidata.formdata.fields[idx]
        if pageField and pageField.apikey then
            local key = pageField.apikey:match("([^%-]+)%-%>") or pageField.apikey
            editableFields[key] = true
        end
    end

    -- Build lookup of actual UI fields
    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if field.api and not field.apikey then
                local mspapi, apikey = string.match(field.api, "([^:]+):(.+)")
                for i, api in ipairs(rfsuite.app.Page.apidata.api) do
                    if api == mspapi then mspapi = i; break end
                end
                field.apikey = apikey
                field.mspapi = mspapi
                utils.log("[buildDeltaPayload] Converted API field", "info")
            end

            if field.apikey then actual_fields[field.apikey] = field end
        end
    end

    -- Patch only changed values
    for _, field_def in ipairs(api_structure) do
        local name = field_def.field

        -- Skip non-editable
        if not editableFields[name] then goto continue end

        -- Sync field constraints if UI-side defines them
        local actual_field = actual_fields[name]
        if actual_field then
            field_def.scale  = field_def.scale  or actual_field.scale
            field_def.mult   = field_def.mult   or actual_field.mult
            field_def.step   = field_def.step   or actual_field.step
            field_def.min    = field_def.min    or actual_field.min
            field_def.max    = field_def.max    or actual_field.max
        end

        -- Apply scale and quantization
        local value = payload[name] or field_def.default or 0
        local scale = field_def.scale or 1
        value = math_floor(value * scale + 0.5)

        -- Write into temporary buffer
        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then error("Unknown type " .. field_def.type) end

        local tmp = {}
        if field_def.byteorder then writeFunction(tmp, value, field_def.byteorder)
        else writeFunction(tmp, value) end

        -- Patch into correct positions
        local pm = positionmap[name]
        if type(pm) == "table" and pm.start and pm.size then
            local maxBytes = math_min(pm.size, #tmp)
            for i = 1, maxBytes do
                local pos = pm.start + i - 1
                if pos <= receivedBytesCount then byte_stream[pos] = tmp[i] end
            end
        elseif pm then
            for idx, pos in ipairs(pm) do
                if pos <= receivedBytesCount then byte_stream[pos] = tmp[idx] end
            end
        end

        ::continue::
    end

    return byte_stream
end

-- Build complete payload from scratch
function core.buildFullPayload(apiname, payload, api_structure)
    local byte_stream = {}
    utils.log("[buildFullPayload] Rebuilding entire payload", "debug")

    local actual_fields = buildActualFieldMap()
    local tmp = {}

    for _, field_def in ipairs(api_structure) do
        local name = field_def.field

        local actual = actual_fields[name]
        syncUiMetadata(field_def, actual, true)

        local value = resolveScaledWriteValue(payload, field_def, actual)

        local ok, err = appendEncodedField(byte_stream, tmp, field_def, value)
        if not ok then error(err) end

        utils.log(string_format("[buildFullPayload] Wrote field '%s' = %d", name, value), "debug")
    end

    return byte_stream
end

------------------------------------------------------------
-- Structure preparation (filter + minBytes + sim response)
------------------------------------------------------------

function core.prepareStructureData(structure)
    local filtered = {}
    local minBytes = 0
    local simResponse = {}

    for _, param in ipairs(structure) do
        -- Skip if API version doesn't match
        if param.apiVersion and utils.apiVersionCompare("<", param.apiVersion) then goto continue end

        table_insert(filtered, param)

        if param.mandatory ~= false then
            minBytes = minBytes + get_type_size(param.type)
        end

        if param.simResponse then
            for _, v in ipairs(param.simResponse) do table_insert(simResponse, v) end
        else
            for i = 1, get_type_size(param.type) do table_insert(simResponse, 0) end
        end

        ::continue::
    end

    return filtered, minBytes, simResponse
end

function core.filterByApiVersion(structure)
    local filtered = core.prepareStructureData(structure)
    return filtered
end

function core.calculateMinBytes(structure)
    local _, minBytes = core.prepareStructureData(structure)
    return minBytes
end

function core.buildSimResponse(structure)
    local _, _, simResponse = core.prepareStructureData(structure)
    return simResponse
end

return core
