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

-- Adjust this to wherever the module lives
local deduplicator = require("rissue.utils.deduplicator")

describe("utils.deduplicator", function()
  local outputs, constructed

  local function make(accessor)
    outputs, constructed = {}, {}
    return deduplicator(function(item)
      table.insert(outputs, item)
    end, function(res)
      table.insert(constructed, res)
      return { wrapped = res }
    end, accessor)
  end

  local by_id = function(res)
    return res.id
  end

  it("outputs the constructed item on first occurrence", function()
    local cb = make(by_id)
    cb({ id = 1 })
    assert.are.same({ { wrapped = { id = 1 } } }, outputs)
  end)

  it("outputs distinct ids in order", function()
    local cb = make(by_id)
    cb({ id = 1 })
    cb({ id = 2 })
    cb({ id = 3 })
    assert.are.equal(3, #outputs)
    assert.are.same({ 1, 2, 3 }, {
      outputs[1].wrapped.id,
      outputs[2].wrapped.id,
      outputs[3].wrapped.id,
    })
  end)

  it("drops items with a duplicate id", function()
    local cb = make(by_id)
    cb({ id = "a", n = 1 })
    cb({ id = "a", n = 2 })
    assert.are.equal(1, #outputs)
    assert.are.equal(1, outputs[1].wrapped.n) -- first one wins
  end)

  it("does not call constructor for duplicates", function()
    local cb = make(by_id)
    cb({ id = 1 })
    cb({ id = 1 })
    assert.are.equal(1, #constructed)
  end)

  it("skips items whose id is nil and does not call constructor", function()
    local cb = make(by_id)
    cb({})
    cb({ id = nil })
    assert.are.equal(0, #outputs)
    assert.are.equal(0, #constructed)
  end)

  it("does not mark nil ids as seen", function()
    local cb = make(by_id)
    cb({})
    cb({ id = 1 })
    assert.are.equal(1, #outputs)
  end)

  it("passes the raw result to the accessor", function()
    local received
    local cb = make(function(res)
      received = res
      return res.id
    end)
    local res = { id = 1 }
    cb(res)
    assert.are.equal(res, received)
  end)

  it("passes the raw result to the constructor", function()
    local cb = make(by_id)
    local res = { id = 1 }
    cb(res)
    assert.are.equal(res, constructed[1])
  end)

  it("treats 0 and empty string as valid ids", function()
    local cb = make(by_id)
    cb({ id = 0 })
    cb({ id = 0 })
    cb({ id = "" })
    cb({ id = "" })
    assert.are.equal(2, #outputs)
  end)

  it("treats number 1 and string '1' as different ids", function()
    local cb = make(by_id)
    cb({ id = 1 })
    cb({ id = "1" })
    assert.are.equal(2, #outputs)
  end)

  it("keeps state independent between deduplicators", function()
    local out1, out2 = {}, {}
    local noop = function(x)
      return x
    end
    local cb1 = deduplicator(function(i)
      table.insert(out1, i)
    end, noop, by_id)
    local cb2 = deduplicator(function(i)
      table.insert(out2, i)
    end, noop, by_id)

    cb1({ id = 1 })
    cb2({ id = 1 })
    cb1({ id = 1 })

    assert.are.equal(1, #out1)
    assert.are.equal(1, #out2)
  end)
end)
