-- RIssue - Plugin for getting issues and merge requests from git providers
-- Copyright (C) 2026  flamfrosticboio
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

--- Varies based on the json provider.
--- Nvim compatible

---@alias rissue.json.Backends
---| "dkjson" # require('dkjson') (installed via luarocks or drop in)
---| "cjson" # require('cjson') (installed via luarocks)
---| "rapidjson" # require('rapidjson') (installed via luarocks)
---| "vim.json" # vim.json (inside neovim runtime)

---@class rissue.Json
--- Second return is the error message
---@field encode fun(items: any): string|nil, string?
--- Second return is the error message
---@field decode fun(raw: string): any|nil, string?
---@field null any
--- Returns an empty table with specific markers or custom lightuserdata that when encoded,
--- it would return exactly a dict in json `{}`
---@field empty_object fun(): any
--- Returns an empty table with specific markers or custom lightuserdata that when encoded,
--- it would return exactly an array in json `[]`
---@field empty_array fun(): any

---@class rissue.mod.Json: rissue.Json
--- Set the preferred json loader to use. If that loader fails, it switches to the
--- available ones.
---@field prefer fun(loader: rissue.json.Backends)
--- The loaded json backend. nil means it has not been loaded
---@field loaded string?

---@alias __rissue.Json.loader fun(): rissue.Json?

local log = require("rissue.utils.log")
local table_op = require("rissue.utils.table_op")

---@type __rissue.Json.loader
local function load_vim()
  -- selene: allow(global_usage)
  local vim = rawget(_G, "vim")
  if not vim or not vim.json then
    return
  end

  log.debug("Using vim as json backend")
  ---@diagnostic disable-next-line: no-unknown
  local vim_version = vim.version()
  log.debug(
    "vim version: "
      .. vim_version.major
      .. "."
      .. vim_version.minor
      .. "."
      .. vim_version.patch
  )

  ---@type rissue.Json
  return {
    null = vim.NIL,
    encode = function(items)
      local ok, err_or_result = pcall(vim.json.encode, items)
      if not ok then
        return nil, err_or_result
      end
      return err_or_result
    end,
    decode = function(raw)
      local ok, err_or_result = pcall(vim.json.decode, raw)
      if not ok then
        return nil, err_or_result
      end
      return err_or_result
    end,
    empty_object = function()
      return vim.empty_dict()
    end,
    empty_array = function()
      return {} --- verified to be [] on nvim v0.12.6
    end,
  }
end

---@type __rissue.Json.loader
local function load_cjson()
  ---@type boolean, cjson?
  local mod_ok, mod = pcall(require, "cjson")
  if not mod_ok or not mod then
    return
  end

  if not mod.empty_array then
    log.warn(
      "Missing implementation: cjson.empty_array. Switch to openresty implementation!"
    )
    return
  end

  log.debug("Using cjson as json backend")
  log.debug("cjson version: " .. mod._VERSION)

  ---@type rissue.Json
  return {
    null = mod.null,
    encode = function(obj)
      local ok, err_or_result = pcall(mod.encode, obj)
      if not ok then
        return nil, err_or_result
      end
      return err_or_result
    end,
    decode = function(raw)
      local ok, err_or_result = pcall(mod.decode, raw)
      if not ok then
        return nil, err_or_result
      end
      return err_or_result
    end,
    empty_object = function()
      return {}
    end,
    empty_array = function()
      return mod.empty_array
    end,
  }
end

---@type __rissue.Json.loader
local function load_rapidjson()
  local mod_ok, mod = pcall(require, "rapidjson")
  if not mod_ok or not mod then
    return
  end

  log.debug("Using rapidjson as json backend")
  log.debug("rapidjson version: " .. (mod._VERSION or "unknown"))

  ---@type rissue.Json
  return {
    null = mod.null,
    encode = function(obj)
      local ok, value, err = pcall(mod.encode, obj)
      if not ok then
        return nil, value -- thrown error, message is in the 2nd slot
      end
      if value == nil then
        return nil, err or "encode failed"
      end
      return value
    end,
    decode = function(raw)
      local ok, value, err = pcall(mod.decode, raw)
      if not ok then
        return nil, value -- thrown error, message is in the 2nd slot
      end
      if value == nil then
        return nil, err or "decode failed"
      end
      return value
    end,
    empty_object = function()
      return mod.object()
    end,
    empty_array = function()
      return mod.array()
    end,
  }
end

---@type __rissue.Json.loader
local function load_dkjson()
  local mod_ok, mod = pcall(require, "dkjson") ---@type boolean, dkjson?
  if not mod_ok or not mod then
    return
  end

  log.debug("Using dkjson as json backend")
  log.debug("dkjson version: " .. mod.version)

  ---@type rissue.Json
  return {
    null = mod.null,
    encode = function(obj)
      local ok, str = pcall(mod.encode, obj)
      if not ok then
        return nil, tostring(str) -- thrown error message
      end
      return tostring(str)
    end,
    decode = function(raw)
      local ok, obj, pos, err = pcall(mod.decode, raw, 1, mod.null)
      if not ok then
        return nil, tostring(obj)
      end
      if err then
        return nil, err .. " at position " .. tostring(pos)
      end
      if raw:find("%S", pos) then
        return nil, "trailing characters at position " .. tostring(pos)
      end
      return obj
    end,
    empty_array = function()
      return setmetatable({}, { __jsontype = "array" })
    end,
    empty_object = function()
      return setmetatable({}, { __jsontype = "object" })
    end,
  }
end

---@class __rissue.json.BackendInfo
---@field name rissue.json.Backends
---@field loader __rissue.Json.loader

---@type __rissue.json.BackendInfo[]
local prefer_order = {
  {
    name = "vim.json",
    loader = load_vim,
  },
  {
    name = "rapidjson",
    loader = load_rapidjson,
  },
  {
    name = "cjson",
    loader = load_cjson,
  },
  {
    name = "dkjson",
    loader = load_dkjson,
  },
}

---@class __rissue.Json.Backend
---@field name string
---@field module rissue.Json

---@param config __rissue.json.BackendInfo
---@return __rissue.Json.Backend?
local function try_load(config)
  local ok, err_or_json = pcall(config.loader)
  if not ok then
    log.error(
      ("Error when loading json backend '%s': %s"):format(
        config.name,
        tostring(err_or_json)
      )
    )
    return
  end

  if err_or_json == nil then
    log.debug(("json backend '%s' not available"):format(config.name))
    return
  end
  if type(err_or_json) ~= "table" then
    log.error("bug: loader did not return a table")
    return
  end

  ---@type __rissue.Json.Backend
  return { name = config.name, module = err_or_json }
end

---@param preferred_loader rissue.json.Backends?
---@return __rissue.Json.Backend?
local function load_json(preferred_loader)
  if preferred_loader then
    local config = table_op.find(prefer_order, function(v)
      return v.name == preferred_loader
    end)
    if config then
      local backend = try_load(config)
      if backend then
        return backend
      end
    else
      log.warn("unknown json backend: " .. tostring(preferred_loader))
    end
  end

  for _, config in ipairs(prefer_order) do
    if config.name ~= preferred_loader then
      local backend = try_load(config)
      if backend then
        return backend
      end
    end
  end
end

---@type rissue.mod.Json
---@diagnostic disable-next-line: missing-fields
local mod = {}

mod.prefer = function(loader)
  if rawget(mod, "loaded") then
    log.warn("json backend already loaded")
    return
  end
  rawset(mod, "__preferred_loader", loader)
end

return setmetatable(mod, {
  __index = function(tbl, key)
    if key == "loaded" then
      --- __index will be dereferenced when loaded
      return nil
    end

    local loader = load_json(rawget(tbl, "__preferred_loader"))
    if not loader then
      error("No compatible json backend found", 2)
    end

    ---@diagnostic disable-next-line: no-unknown
    for k, v in pairs(loader.module) do
      rawset(tbl, k, v)
    end
    rawset(tbl, "loaded", loader.name)
    rawset(tbl, "__preferred_loader", nil)
    setmetatable(tbl, nil) --- do not remove!
    return tbl[key]
  end,
})
