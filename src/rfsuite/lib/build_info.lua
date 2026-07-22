-- Runtime-visible suite build identity.
--
-- bin/package/build_package.py rewrites only the suffix field in staged
-- builds, so release and commit artifacts can display their exact build.

local build_info = {}

build_info.version = {major = 2, minor = 3, revision = 1, suffix = ""}

local function baseVersion(v)
  return string.format("%d.%d.%d", tonumber(v.major) or 0, tonumber(v.minor) or 0, tonumber(v.revision) or 0)
end

function build_info.versionString()
  local v = build_info.version
  local base = baseVersion(v)
  local suffix = v.suffix
  if suffix and suffix ~= "" and suffix ~= base then
    return base .. "-" .. tostring(suffix)
  end
  return base
end

function build_info.displayName()
  return "RFSUITE " .. build_info.versionString()
end

return build_info
