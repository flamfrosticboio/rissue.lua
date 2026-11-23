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

---@diagnostic disable: redundant-parameter

local log = require("rissue.utils.log")

local MODULE = "rissue.utils.json" -- adjust to your path

local BACKENDS = { "vim.json", "rapidjson", "cjson", "dkjson" }

--- fresh, unloaded module each time
local function fresh()
  package.loaded[MODULE] = nil
  return require(MODULE)
end

---@return rissue.Json?
local function backend(name)
  local json = fresh()
  json.prefer(name)
  local _ = json.encode -- forces the load
  if json.loaded ~= name then
    return nil
  end
  return json
end

local function compact(s)
  return (s:gsub("%s+", ""))
end

---@param loader string
---@param tags string?
local function test_json(loader, tags)
  describe(
    string.format("%s #json_%s %s", loader, loader, tags or ""),
    function()
      local _json_loader = backend(loader)

      before_each(function()
        _json_loader = backend(loader)
      end)

      ---@param desc string
      ---@param fn fun()
      local function case(desc, fn)
        if _json_loader then
          it(desc, function()
            fn(_json_loader)
          end)
        else
          pending(desc .. " (" .. loader .. " not available)", fn)
        end
      end

      ---@diagnostic disable: need-check-nil

      case("round-trips a table", function(json)
        local s, err = json.encode({ a = 1, b = { true, false } })
        assert.is_nil(err)
        local obj = json.decode(s)
        assert.equal(1, obj.a)
        assert.same({ true, false }, obj.b)
      end)

      case("decodes false as a value, not an error", function(json)
        local v, err = json.decode("false")
        assert.is_false(v)
        assert.is_nil(err)
      end)

      case("returns nil, err on invalid json", function(json)
        local v, err = json.decode("{")
        assert.is_nil(v)
        assert.is_string(err)
      end)

      case("returns nil, err on non-string input", function(json)
        local ok, v, err = pcall(json.decode, nil)
        assert.is_true(ok)
        assert.is_nil(v)
        assert.is_string(err)
      end)

      case("returns nil, err for unencodable values", function(json)
        local ok, v, err = pcall(json.encode, { f = function() end })
        assert.is_true(ok)
        assert.is_nil(v)
        assert.is_string(err)
      end)

      case("returns nil, err for reference cycles", function(json)
        local t = {}
        t.self = t
        local ok, v, err = pcall(json.encode, t)
        assert.is_true(ok)
        assert.is_nil(v)
        assert.is_string(err)
      end)

      case("decodes null to json.null", function(json)
        local obj = json.decode('{"a":null}')
        assert.equal(json.null, obj.a)
      end)

      case("encodes json.null as null", function(json)
        assert.equal("[null]", compact(json.encode({ json.null })))
      end)

      case("encodes empty_array as []", function(json)
        assert.equal("[]", compact(json.encode(json.empty_array())))
      end)

      case("encodes empty_object as {}", function(json)
        assert.equal("{}", compact(json.encode(json.empty_object())))
      end)

      case("keeps nested empty containers distinct", function(json)
        local s = compact(json.encode({
          arr = json.empty_array(),
          obj = json.empty_object(),
        }))
        assert.truthy(s:find('"arr":[]', 1, true))
        assert.truthy(s:find('"obj":{}', 1, true))
      end)

      case("rejects trailing garbage", function(json)
        local v, err = json.decode("{} x")
        assert.is_nil(v)
        assert.is_string(err)
      end)

      ---@diagnostic enable: need-check-nil
    end
  )
end

describe("json", function()
  describe("lazy loading", function()
    it("is unloaded until a field is accessed", function()
      local json = fresh()
      assert.is_nil(json.loaded)
      assert.is_not_nil(getmetatable(json))
    end)

    it("loads on first access and removes the metatable", function()
      local json = fresh()
      local _ = json.encode
      assert.is_string(json.loaded)
      assert.is_nil(getmetatable(json))
      assert.is_nil(rawget(json, "__preferred_loader"))
    end)

    it("does not load when reading `loaded` or calling prefer", function()
      local json = fresh()
      json.prefer("dkjson")
      assert.is_nil(json.loaded)
    end)

    it("falls back when the preferred backend is unknown", function()
      local json = fresh()
      json.prefer("nonexistent")
      local _ = json.encode
      assert.is_string(json.loaded)
    end)

    it("ignores prefer after loading", function()
      local json = fresh()
      local encode = json.encode
      local first = json.loaded

      local other
      for _, name in ipairs(BACKENDS) do
        if name ~= first then
          other = name
          break
        end
      end

      json.prefer(other)
      assert.equal(first, json.loaded)
      assert.equal(encode, json.encode)
      assert.is_nil(rawget(json, "__preferred_loader"))
    end)
  end)

  for _, name in ipairs(BACKENDS) do
    test_json(name, name == "vim.json" and "#vim" or nil)
  end

  lazy_teardown(function()
    -- selene: allow(global_usage)
    if not rawget(_G, "vim") then
      log.info(" ========== For vim tests, run with 'mise test-vim' ==========")
    end
  end)
end)
