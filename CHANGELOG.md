# Changelog

## v0.2

New Features:

- Added support for coroutine mode.

  Example:

  ```lua
  local done = false
  coroutine.wrap(function()
    local issues, err = rissue.get_issues(
      "https://github.com/flamfrosticboio/rissue.lua.git",
      { github = { max_items = 1 } }
    )
    assert(issues, err)
    --- ... do things with issues
    done = true
  end)()
  require("rissue.utils.process").wait(function()
    return done
  end, 5 * 60 * 1000) -- 5 minutes in milliseconds
  ```

- `utils/process`
  - Added `Process:is_running()` which checks if the process is currently running.
  - Improved debugging by changing log levels on certain statements.

- `Github`
  - Improve error logging
  - Improve how many items are fetched on a single page fetch.

Full changelog: [https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2](https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2)

## v0.1

Initial commit.
