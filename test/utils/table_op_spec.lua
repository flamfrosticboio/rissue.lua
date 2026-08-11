-- RIssue - Abstract implementation for getting issues and merge requests from git providers
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

local table_op = require("rissue.utils.table_op")

describe("`force_extend()`", function()
  it("extends", function()
    local t = table_op.force_deep_extend({ hello = "welcome" }, { hello = "hola" })
    assert.equal("hola", t.hello)
  end)

  it("extends deeply", function()
    local t1 = { x = { y = true, w = { u = "help", msg = "ok", write = 1 } } }
    local t = table_op.force_deep_extend({ z = true, x = false }, t1)
    assert.same({
      z = true,
      x = { y = true, w = { u = "help", msg = "ok", write = 1 } },
    }, t)

    -- write to the inner table to see if it has been written shallowly
    t1.x.welcome = true

    -- check if the shallow pointer table was not affected
    assert.same({
      z = true,
      x = { y = true, w = { u = "help", msg = "ok", write = 1 } },
    }, t)
  end)

  it("list gets shallow copy", function()
    local t1 = { x = { 1, 2, 3 } }
    local t = table_op.force_deep_extend({ y = true }, t1)

    -- should expect equal pointers
    assert.equal(t1.x, t.x)

    -- should expect different pointers
    local t2 = { 1, 2, 3 }
    assert.are_not.equal(t2, t.x)
  end)

  it("force overwrites", function()
    local t = table_op.force_deep_extend({ x = false }, { x = true })
    assert.is_true(t.x)
  end)
end)

describe("`is_list()`", function()
  it("correct", function()
    local l = { 1, 2, 3, 4, 5 }
    assert.is_true(table_op.is_list(l))
    local t = { x = true, 2, 3, 4, 5 }
    assert.is_false(table_op.is_list(t))
  end)
end)
