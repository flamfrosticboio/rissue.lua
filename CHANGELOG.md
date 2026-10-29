# Changelog

## v0.3.0

**Features:**

- Use new async model that is used for rissue.

  - Refactored all async related code in rissue to use the new async model.

- [utils/process]: Add auto enabling on logging on process's stdout and stderr
  when `trace` is enabled in log level.

- [utils/log]
  - Regular printing functions such as `log.info()`, `log.warn()` and etc.
    can now take multiple parameters.

  - New function: `log.get_log_level()` to get current log level.

  - `log.log()` and `rissue.logger_func` can now take context. This affects
    setting up custom loggers where you can read the context of the log passed.

    `rissue.logger_func`: `fun(msg: string, level: rissue.log.level, info?: rissue.logger.log_info)`

    This changes enables fine adjustment to the message output. Example:

    ```lua
    local log = require('rissue.utils.log')
    log.set_logger(function(msg, level, info)
        if info and info.context then
            msg = "[" .. info.context .. "] " .. msg
        end
        vim.notify(msg, level)
    end)
    ```

- [provider]: Upgrade specifications where getting issues and merge requests
  calls the callback builder function provided. This allows for showing partial
  results while the items are still fetching.

  ```lua
  --- module `rissue.get`
  --- from:
  get.issues(a, info, opts)
  get.merge_requests(a, info, opts)
  --- to:
  get.issues(a, info, opts, function(issue) ... end)
  get.merge_requests(a, info, opts, function(pr) ... end)
  ```

  Example use case (folke/snacks picker):

  ```lua
  --- inside snacks picker's finder
  --- wrapped with async.run() and info and opts are provided
  get.issues(a, info, opts, function(issue)
    --- callback from snacks picker's callback
    cb({ text = issue.body, item = issue })
  end)
  ```

  - [Github]: updated specifications to conform with this new change.

- [utils/table_op]:
  - New function: `table_op.appender()`.

    Example Usage:

    ```lua
    local tbl = {}
    local pusher = table_op.appender(tbl)

    pusher(1)
    pusher(2)
    pusher(3)
    --- table contains { 1, 2, 3 }
    ```

**Changes:**

- [utils/log] Accessing `log_level` (now called `_level`) and `_logger` are
  tagged protected.

- [Github]:
  - Updated logging to be more clear and simpler.

- [specifications/providers]: Simplify versioning system.

  Instead of using `version: string` and `version_code: integer`, it will use
  `version: {major: integer, minor: integer, patch: integer}` instead.

  ```lua
  --- from
  {
    ...
    version = "1.0",
    version_code = 1000,
  }
  --- to
  {
    version = { major = 1, minor = 0, patch = 0 }
  }

  - [Github]: updated specifications to conform with this new change.
  ```

**Bug Fixes:**

- [utils/process, utils/async]: Fix unpack is unavailable on other lua versions.

- [utils/curl]: Fix constant variable mutation errors when using lua5.5

- [utils/process]: Fixed running status is still true when process
  has exited during the `on_exit` event.

**Breaking Changes:**

- [utils/log]: Removed `log_func`. Write a manual implementation instead.

- [utils/process]: Removed `process.run()` and `process.run_co()`.
  Use `process.run_async()` instead.

- [provider]: `Provider.get_issues()` and `Provider.get_merge_requests()` will
  now take a fourth parameter `cb: fun(item: T)` where `T` is `rissue.issue` or
  `rissue.pr`. The return type is updated from
  `rissue.issue[]? results, string? err_msg` to `string? err_msg`

- [specifications/providers]: The versioning system for providers uses
  `version: {major: integer, minor: integer, patch: integer}` instead of
  `version: string` and `version_code: integer`. Any existing providers using the
  old versioning system will not work anymore.

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
