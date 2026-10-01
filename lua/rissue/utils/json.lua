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

---@diagnostic disable: undefined-global, inject-field

---@alias rissue.json.Loaders "dkjson" | "cjson" | "rapidjson" | "vim.json"

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
---@field prefer fun(loader: rissue.json.Loaders)

local log = require("rissue.utils.log")
local table_op = require("rissue.utils.table_op")

local prefer_loader = nil

local function has_module(mod)
  local ok = pcall(require, mod)
  return ok
end

---@param tbl rissue.Json
local function load_vim(tbl)
  log.debug("Using vim as json backend")
  log.debug(
    "vim version: "
      .. vim.version().major
      .. "."
      .. vim.version().minor
      .. "."
      .. vim.version().patch
  )

  tbl.null_type = vim.NIL
  tbl.encode = function(items)
    local ok, err_or_result = pcall(vim.json.encode, items)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.decode = function(raw)
    local ok, err_or_result = pcall(vim.json.decode, raw)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.empty_object = function()
    return vim.empty_dict()
  end
  tbl.empty_array = function()
    return {}
  end
end

---@param tbl rissue.Json
local function load_cjson(tbl)
  log.debug("Using cjson as json backend")
  local mod = require("cjson")
  log.debug("cjson version: " .. mod._VERSION)

  if not mod.empty_array then
    error(
      "Missing implementation: cjson.empty_array. Switch to openresty implementation!"
    )
  end

  tbl.null_type = mod.null
  tbl.encode = function(obj)
    local ok, err_or_result = pcall(mod.encode, obj)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.decode = function(str)
    local ok, err_or_result = pcall(mod.decode, str)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.empty_object = function()
    return {}
  end
  tbl.empty_array = function()
    return mod.empty_array
  end
end

---@param tbl rissue.Json
local function load_rapidjson(tbl)
  log.debug("Using rapidjson as json backend")
  local mod = require("rapidjson")
  log.debug("rapidjson version: " .. (mod._VERSION or "unknown"))

  tbl.null_type = mod.null
  tbl.encode = function(obj)
    local ok, err_or_result = pcall(mod.encode, obj)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.decode = function(str)
    local ok, err_or_result = pcall(mod.decode, str)
    if not ok then
      return nil, err_or_result
    end
    return err_or_result
  end
  tbl.empty_object = function()
    return mod.object()
  end
  tbl.empty_array = function()
    return mod.array()
  end
end

---@param tbl rissue.Json
local function load_dkjson(tbl)
  log.debug("Using dkjson as json backend")
  local mod = require("dkjson")
  log.debug("dkjson version: " .. mod.version)
  tbl.null_type = mod.null
  tbl.encode = function(obj)
    local ok, str_or_err = pcall(mod.encode, obj)
    if not ok then
      return nil, str_or_err
    end
    if not str_or_err then
      return nil, "encode failed"
    end
    return str_or_err
  end
  tbl.decode = function(str)
    local obj, pos, err = mod.decode(str)
    if err then
      return nil, err .. " at position " .. pos
    end
    return obj
  end
  tbl.empty_array = function()
    return setmetatable({}, { __jsontype = "array" })
  end
  tbl.empty_object = function()
    return setmetatable({}, { __jsontype = "object" })
  end
end

---@class __rissue.json.PreferOrderItem
---@field name rissue.json.Loaders
---@field condition fun(): boolean
---@field loader fun(tbl: rissue.Json)

---@type __rissue.json.PreferOrderItem[]
local prefer_order = {
  {
    name = "vim.json",
    condition = function()
      return vim
    end,
    loader = load_vim,
  },
  {
    name = "rapidjson",
    condition = function()
      return has_module("rapidjson")
    end,
    loader = load_rapidjson,
  },
  {
    name = "cjson",
    condition = function()
      return has_module("cjson")
    end,
    loader = load_cjson,
  },
  {
    name = "dkjson",
    condition = function()
      return has_module("dkjson")
    end,
    loader = load_dkjson,
  },
}

---@param tbl rissue.Json
local function load(tbl)
  if prefer_loader then
    ---@type __rissue.json.PreferOrderItem?
    local config = table_op.find(prefer_order, function(v)
      return v.name == prefer_loader
    end)
    if config and config.condition() then
      local ok, err = pcall(config.loader, tbl)
      if ok then
        -- exit early since we are done
        return
      else
        log.warn(
          ("Error when loading json backend '%s': %s"):format(config.name, err)
        )
      end
    end
  end

  for _, config in ipairs(prefer_order) do
    if config.condition() then
      local ok, err = pcall(config.loader, tbl)
      if ok then
        -- exit early since we are done
        return
      else
        log.warn(
          ("Error when loading json backend '%s': %s"):format(config.name, err)
        )
      end
    end
  end

  error("No compatible json backend is installed")
end

---@type rissue.Json
---@diagnostic disable-next-line: missing-fields
return setmetatable({
  prefer = function(loader)
    prefer_loader = loader
  end,
} --[[@as rissue.Json]], {
  __index = function(tbl, key)
    load(tbl)
    setmetatable(tbl, nil)
    return tbl[key]
  end,
})
