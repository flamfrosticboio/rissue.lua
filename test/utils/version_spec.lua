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

local versions = require("rissue.utils.versions")

describe("versions", function()
  it("is_compatible ok on major", function()
    assert.is_true(
      versions.is_compatible(
        { major = 1, minor = 0, patch = 0 },
        { major = 1, minor = 10, patch = 0 }
      )
    )

    assert.is_false(
      versions.is_compatible(
        { major = 1, minor = 0, patch = 0 },
        { major = 0, minor = 10, patch = 0 }
      )
    )
  end)

  it("is_compatible ok on minor", function()
    --- minor checking should trigger on major is equal

    assert.is_true(
      versions.is_compatible(
        { major = 1, minor = 0, patch = 0 },
        { major = 1, minor = 10, patch = 0 }
      )
    )

    assert.is_false(
      versions.is_compatible(
        { major = 1, minor = 10, patch = 0 },
        { major = 1, minor = 0, patch = 0 }
      )
    )
  end)

  it("represent ok", function()
    assert.same(
      "1.20.189",
      versions.represent({ major = 1, minor = 20, patch = 189 })
    )
  end)
end)
