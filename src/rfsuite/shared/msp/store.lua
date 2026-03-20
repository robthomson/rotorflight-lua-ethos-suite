--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local STORE_SINGLETON_KEY = "rfsuite.shared.msp.store"

if package.loaded[STORE_SINGLETON_KEY] then
    return package.loaded[STORE_SINGLETON_KEY]
end

local store = {
    page = {},
    retained = {}
}

local function ensureBucket(bucket)
    bucket.values = bucket.values or {}
    bucket.structure = bucket.structure or {}
    bucket.receivedBytesCount = bucket.receivedBytesCount or {}
    bucket.receivedBytes = bucket.receivedBytes or {}
    bucket.positionmap = bucket.positionmap or {}
    bucket.other = bucket.other or {}
    bucket._lastReadMode = bucket._lastReadMode or {}
    bucket._lastWriteMode = bucket._lastWriteMode or {}
    return bucket
end

local function resetBucket(bucket)
    local key

    bucket = ensureBucket(bucket)

    for key in pairs(bucket.values) do bucket.values[key] = nil end
    for key in pairs(bucket.structure) do bucket.structure[key] = nil end
    for key in pairs(bucket.receivedBytesCount) do bucket.receivedBytesCount[key] = nil end
    for key in pairs(bucket.receivedBytes) do bucket.receivedBytes[key] = nil end
    for key in pairs(bucket.positionmap) do bucket.positionmap[key] = nil end
    for key in pairs(bucket.other) do bucket.other[key] = nil end
    for key in pairs(bucket._lastReadMode) do bucket._lastReadMode[key] = nil end
    for key in pairs(bucket._lastWriteMode) do bucket._lastWriteMode[key] = nil end

    return bucket
end

function store.getPage()
    return ensureBucket(store.page)
end

function store.getRetained()
    return ensureBucket(store.retained)
end

function store.resetPage()
    return resetBucket(store.page)
end

function store.resetRetained()
    return resetBucket(store.retained)
end

function store.resetAll()
    store.resetPage()
    store.resetRetained()
    return store
end

package.loaded[STORE_SINGLETON_KEY] = store

return store
