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

local assert_op = require("rissue.utils.assert_op")

describe("`check_structure()`", function()
  it("simple", function()
    local test_a = { a = "hello", b = 20, c = true }
    ---@type rissue.utils.check_structure.Structure
    local structure_a = { a = "string", b = "number", c = "boolean" }
    local res = assert_op.check_structure(
      "rissue._tests.stub",
      test_a,
      structure_a,
      "simple"
    )

    assert.is_true(res)

    ---@type rissue.utils.check_structure.Structure
    local structure_b = { a = "string", b = "string", c = "boolean" }
    res = assert_op.check_structure(
      "rissue._tests.stub",
      test_a,
      structure_b,
      "simple"
    )
    assert.is_false(res)
  end)

  it("list", function()
    local test = { a = "hello", b = 20, c = true }
    local test2 = { a = 2, b = 20, c = false }
    ---@type rissue.utils.check_structure.Structure
    local structure = {
      a = { "string", "number", "boolean" },
      b = "number",
      c = "boolean",
    }

    assert.is_true(
      assert_op.check_structure("rissue._tests.stub", test, structure, "list")
    )
    assert.is_true(
      assert_op.check_structure("rissue._tests.stub", test2, structure, "list")
    )

    ---@type rissue.utils.check_structure.Structure
    local structure_false = {
      a = { "boolean", "number" },
      b = "number",
      c = "boolean",
    }

    assert.is_false(
      assert_op.check_structure(
        "rissue._tests.stub",
        test,
        structure_false,
        "list"
      )
    )
  end)

  it("complex", function()
    local test = { a = { b = "hello", c = { d = false } } }

    ---@type rissue.utils.check_structure.Structure
    local structure = { a = { b = "string", c = { d = "boolean" } } }

    assert.is_true(
      assert_op.check_structure(
        "rissue._tests.stub",
        test,
        structure,
        "complex"
      )
    )

    ---@type rissue.utils.check_structure.Structure
    local structure_false = { a = { b = "string", c = { d = "number" } } }
    assert.is_false(
      assert_op.check_structure(
        "rissue._tests.stub",
        test,
        structure_false,
        "complex"
      )
    )
  end)

  it("compound", function()
    local test = { a = { b = "hello", c = { d = true } } }
    ---@type rissue.utils.check_structure.Structure
    local structure_a = {
      a = { b = "string", c = { d = { "boolean", "string" } } },
    }

    ---@type rissue.utils.check_structure.Structure
    local structure_false = {
      a = {
        b = "string",
        c = { d = { "string", "number" } },
      },
    }

    assert.is_true(
      assert_op.check_structure(
        "rissue._tests.stub",
        test,
        structure_a,
        "compound"
      )
    )
    assert.is_false(
      assert_op.check_structure(
        "rissue._tests.stub",
        test,
        structure_false,
        "compound"
      )
    )
  end)
end)
