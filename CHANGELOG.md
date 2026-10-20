# Changelog

## v0.3.0

**Features:**

- Auto enable logging on process's stdout and stderr when trace is enabled in
  log level.
- `utils/log`
  - Regular printing functions such as `log.info()`, `log.warn()` and etc.
    can now take multiple parameters.
  - New function: `log.get_log_level()` to get current log level.
  - `log.log()` and `rissue.logger_func` can now take context. This affects
    setting up custom loggers where you can read the context of the log passed.

    `rissue.logger_func`: `fun(msg: string, level: rissue.log.level, info?: rissue.logger.log_info)`

    This changes enables fine adjustment to the message output. Example:

    ```lua
    log.set_logger(function(msg, level, info)
        if info and info.context then
            msg = "[" .. info.context .. "] " .. msg
        end
        vim.notify(msg, level)
    end)
    ```

**Changes:**

- Accessing `log_level` (now called `_level`) and `_logger` are tagged protected.

**Breaking Changes:**

- Removed `log_func`. Write a manual implementation instead.

## v0.2.1

**Improvements:**

- Reduce logging overhead on process's stdout and stderr.

**Fixes:**

- Fix logging on `utils.process` where in using `opts.print_output = true` on
  `process.run()` and `process.run_co()` would print out `info` instead of `trace`

**Documentation:**

- Fix some documentation on:
  - `rissue.get_merge_requests()`

Full changelog: [https://github.com/flamfrosticboio/rissue.lua/compare/v0.2.0...v0.2.1](https://github.com/flamfrosticboio/rissue.lua/compare/v0.2.0...v0.2.1)

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

- Integrate logging setup to `rissue.setup()`

- `utils/process`
  - Added `Process:is_running()` which checks if the process is currently running.
  - Improved debugging by changing log levels on certain statements.

- `utils/log` [Breaking Changes]
  - Add setup.
  - Separate logging with timestamp and error level into its own function
    (as builtin logger) [#27](https://github.com/flamfrosticboio/rissue.lua/issues/27).

    When setting logger with `log.set_logger()` or `log.setup()`, it no longer
    gives you the timestamp and log level prefixes in the message.

    ```lua
    log.set_logger(function(msg, _level) print(msg) end)
    --- previously
    log.warn("my message") -- prints "[<timestamp>][ Warn]: my message"
    --- now
    log.warn("my message") -- prints "my message" without the timestamp
    ```

  - Add `colors` to print output using ansi characters.

- `Github`
  - Improve error logging
  - Improve how many items are fetched on a single page fetch.

Full changelog: [https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2](https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2.0)

## v0.1

Initial commit.
