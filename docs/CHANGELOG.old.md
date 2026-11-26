# Changelog

## v0.3.0

**⚠️ BREAKING CHANGES:**

- [utils]:
  - [log]:
    - Remove `log_func`. Write a manual implementation instead.

  - [process]:
    - Remove `process.run()` and `process.run_co()`. Use `process.run_async()`
      instead.

  - [assert_op]:
    - Replace `assert_op.check_structure()` with `assert_op.table_expects()`,
      which takes a different structure built on matchers.

      ```lua
      local obj_to_compare = {} -- the table object to compare
      local structure = {
        name = "hello", -- a literal
        full_name = assert_op.matchers.is_string(), -- any string
        --- see `assert_op.matchers` for everything you can match.
      }
      assert_op.table_expects(obj_to_compare, structure, name)
      ```

      See
      [base (b875e7c)](https://github.com/flamfrosticboio/rissue.lua/pull/73/changes/b875e7cd6c1fbf1ebd6c873d5b7a887edbaabf6f)
      and
      [is_integer (b50445b)](https://github.com/flamfrosticboio/rissue.lua/commit/b50445b809fb677f62be6ec2fa92c573dd33ad12).

  - [curl]:
    - Rename `rissue.utils.curl.Opts`, `Result`, `Method`, `Formats`, `DataType`
      and `AuthMethod` to `rissue.curl.*`.

    - Remove `exitcode` and `err` fields from `rissue.curl.Result`. `content`
      now holds trimmed stdout.

    - `raw`, `request` and `post` now return `rissue.curl.Error` instead of a
      string on failure. A nonzero curl exit code now returns an error instead
      of a result.

      ```lua
      --- previously
      local res, err = curl.request(async, url, opts)
      if not res then
        log.error(err) -- err is a string
      elseif res.exitcode ~= 0 then
        log.error(res.err)
      end
      --- now
      local res, err = curl.request(async, url, opts)
      if not res then
        log.error(err.msg) -- err is `rissue.curl.Error`
      end
      ```

    - `construct` now returns `nil, err_msg` on invalid options instead of
      raising with `error()`. `request` wraps that message in a
      `rissue.curl.Error` with `exitcode = -1`.

      ```lua
      --- previously
      local ok, args = pcall(curl.construct, url, opts)
      --- now
      local args, err = curl.construct(url, opts)
      ```

- [provider]:
  - `Provider.get_issues()` and `Provider.get_merge_requests()` now take a
    fourth parameter `cb: fun(item: T)`, where `T` is `rissue.issue` or
    `rissue.pr`. The return type changes from
    `rissue.issue[]? results, string? err_msg` to `string? err_msg`.

- [specifications/providers]:
  - Replace `version: string` and `version_code: integer` with
    `version: {major: integer, minor: integer, patch: integer}`. Providers using
    the old versioning no longer work.

    ```lua
    --- previously
    {
      version = "1.0",
      version_code = 1000,
    }
    --- now
    {
      version = { major = 1, minor = 0, patch = 0 },
    }
    ```

- [config]:
  - `config.endpoint_shortcuts` now takes a list of `rissue.EndpointShortcut`
    instead of a table.

  - `rissue.EndpointShortcut` now requires the `name: rissue.ProviderName`
    field.

  - `config.providers` is empty until `config.setup()` runs. Built-in providers
    are loaded during setup instead of on require.

    ```lua
    --- previously
    local config = require("rissue.config")
    config.providers.github -- available right after require
    --- now
    local config = require("rissue.config")
    config.setup()
    config.providers.github -- available only after setup
    ```

- [docs]:
  - Rename types to better reflect their use:
    - `rissue.pr` -> `rissue.MergeRequest`
    - `rissue.issue` -> `rissue.Issue`
    - `rissue.item.base` -> `rissue.CommonItem`
    - `rissue.pr.State` -> `rissue.mr.State`
    - `rissue.label` -> `rissue.Label`
    - `rissue.user` -> `rissue.User`
    - `rissue.logger` -> `rissue.Logger`
    - `rissue.log.level.named` -> `rissue.log.named_level`
    - `rissue.utils.CmdResult` -> `rissue.utils.process.Result`
    - `rissue.utils.CommandOpts` -> `rissue.utils.process.Opts`
    - `rissue.utils.run.Opts` -> `rissue.utils.run_process.Opts`

**✨ New Features:**

- [core]:
  - Use the new async model. All async code in rissue is refactored to use it.

  - Check the curl version in the background during `setup` and log a warning
    when curl cannot be run or is incompatible.

- [gitlab]:
  - Add a Gitlab module to query issues and merge requests from gitlab.com and
    self-hosted Gitlab instances.

- [github]:
  - Update specifications for the new callback-based `get` API and the new
    versioning system.

  - Improve pattern detection when checking Github support for a given url.

- [provider]:
  - Call the provided callback builder function from `get.issues` and
    `get.merge_requests`, so partial results can be shown while items are still
    being fetched.

    ```lua
    --- module `rissue.get`
    --- previously
    get.issues(a, info, opts)
    get.merge_requests(a, info, opts)
    --- now
    get.issues(a, info, opts, function(issue) ... end)
    get.merge_requests(a, info, opts, function(pr) ... end)
    ```

    Example (folke/snacks picker):

    ```lua
    --- inside snacks picker's finder, wrapped with async.run()
    get.issues(a, info, opts, function(issue)
      cb({ text = issue.body, item = issue })
    end)
    ```

- [config]:
  - Reject providers whose `version` is incompatible with
    `EXTENSION_FORMAT_VERSION` (1.0.0). The error names the provider, the
    required version and the current version.

  - Report built-in provider load failures from `config.setup` as `[bug]` errors
    instead of failing on require.

  - Prefix additional provider errors with `failed to load '<path>'`. Spec
    errors now read `Not a provider spec: ...` instead of
    `Module at '<path>' is not a provider spec: ...`.

- [utils]:
  - [process]:
    - Enable logging of stdout and stderr automatically when the log level is
      `trace`.

    - Add the `newline_on_multiline_output` option to
      `Process.get_last_stdout()` and `Process.get_last_stderr()`. Options are
      now passed as a table.

      ```lua
      --- previously
      process:get_last_stdout(true) -- strip lines when passed true
      --- now
      process:get_last_stdout({
        strip_new_lines = true,
        newline_on_multiline_output = true,
      })
      ```

  - [log]:
    - Refactor the logging library, introducing `rissue.mod.logger` and
      `rissue.Logger`.

    - Add `require('rissue.utils.log').new()` to create a scoped
      `rissue.Logger`. It accepts:
      - `context`: `rissue.log.log_info`, passed to the logger.
      - `logger`: `rissue.logger_func`.
      - `log_level`: `rissue.log.level`.

      ```lua
      local log = require('rissue.utils.log')
      local scoped_log = log.new({
        context = "MyScopedLogger",
        logger = function(msg, level, info)
          print(string.format("[%s][lvl:%s] %s", info.context, level, msg))
        end
      })

      -- prints: "[MyScopedLogger][lvl:2] Hello World!"
      scoped_log.info("Hello World!")
      ```

    - Allow `log.info()`, `log.warn()` and the other print functions to take
      multiple parameters.

    - Add `log.get_log_level()` to get the current log level.

  - [table_op]:
    - Add `table_op.appender()`.

      ```lua
      local tbl = {}
      local pusher = table_op.appender(tbl)

      pusher(1)
      pusher(2)
      pusher(3)
      --- tbl is now { 1, 2, 3 }
      ```

    - Add `table_op.tbl_keys()` to list the keys of a table.

  - [curl]:
    - Add `is_version_compatible` to check that the installed curl is at least
      7.83.0 and below 9.0.0.

    - Add `rissue.curl.Error` with `exitcode`, `msg` (from stderr) and
      `server_msg` (from stdout). `server_msg` is `nil` when stdout is empty.

    - Use `exitcode = -1` for internal errors not coming from curl, including
      `--dump-header` file errors.

    - Fall back to `curl failed (exit code N)` in `msg` when stderr is empty.

    - Collapse consecutive duplicate stderr lines in `msg`.

      ```txt
      --- previously
      a
      a
      a
      b
      --- now
      a (3x)
      b
      ```

    - Trim surrounding whitespace from stdout and stderr with `strings.trim`.

    - Validate `opts.data_type` in `construct` and list the valid values in the
      error message.

    - Validate `opts.data` in `construct`: it must be a string or a table, and
      table keys must be strings.

    - Accept `nil` `opts` in `request`.

    - Add the `outfile` option, which passes `-o <file>` to curl along with
      `--create-dirs` and `--remove-on-error`. The returned content is an empty
      string, since nothing is written to stdout.

    - Add the `retry_when` option, which uses curl's built-in retry and is
      controlled by `retries` and `retry_delay`. Possible values:
      - `false`: never retry.
      - `"all"`: retry on every error, including `opts.fail_fast`.
      - `"connrefused"`: retry only when the connection is refused.

  - [json]:
    - Add the `loaded` field, which shows the currently loaded json backend.

    - Improve error reporting.

  - [versions]:
    - Return `?` from `represent()` when the number cannot be decoded.

  - [assert_op]:
    - Support literals and more complex checks in `table_expects` through
      matchers.

  - [strings] (new module):
    - Add `strings.trim()` to trim whitespace quickly.

    - Add `strings.trim_newlines()` to trim newlines quickly.

    - Add `strings.truncate()` to truncate a string safely on utf-8.

    - Add `strings.represent_value()` to wrap strings in double quotes and use
      `tostring` for other values.

  - deduplicator (new module):
    - Return a function that deduplicates results by id.

      ```lua
      -- Not the exact implementation with gitlab
      local function construct_merge_requests(item) return item end
      local function get_id(item) return item.id end
      local function cb(item) print(item.name) end
      local cb = deduplicator(cb, construct_merge_requests, get_id)

      cb({ id = 1, name = "Hello" }) -- prints 'Hello'
      cb({ id = 2, name = "Hi" })    -- prints 'Hi'
      cb({ id = 1, name = "Hello" }) -- prints nothing
      ```

**🐛 Bug Fixes:**

- [utils]:
  - [process]:
    - Fix `unpack` being unavailable on other Lua versions.

    - Fix the running status staying `true` when the process exits during the
      `on_exit` event.

    - Read stdout and stderr pipes until EOF, then force-close them after a
      100ms grace period, so the last output is no longer lost on exit.

  - [async]:
    - Fix `unpack` being unavailable on other Lua versions.

  - [curl]:
    - Fix constant variable mutation errors on Lua 5.5.

    - Fix the tmpfile not being deleted on curl error when using
      `opts.include_result_headers`.

    - Reject string `data` for `form_string` instead of the stale
      `form_literal`.

- [config]:
  - Fix additional providers getting wrong checks
    ([#72](https://github.com/flamfrosticboio/rissue.lua/issues/72)).

- [provider]:
  - Scope opts properly by provider name
    ([#76](https://github.com/flamfrosticboio/rissue.lua/issues/76)).

**♻️ Changes:**

- [utils]:
  - [log]:
    - Rename `log_level` to `_level` and tag it and `_logger` as protected.

  - [table_op]:
    - Rename `table_op.set_into_list()` (now deprecated) to
      `table_op.tbl_values()`

- [github]:
  - Make logging clearer and simpler.

Full changelog:
[https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2](https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2.0)

## v0.2.1

**Improvements:**

- Reduce logging overhead on process's stdout and stderr.

**Fixes:**

- Fix logging on `utils.process` where in using `opts.print_output = true` on
  `process.run()` and `process.run_co()` would print out `info` instead of
  `trace`

**Documentation:**

- Fix some documentation on:
  - `rissue.get_merge_requests()`

Full changelog:
[https://github.com/flamfrosticboio/rissue.lua/compare/v0.2.0...v0.2.1](https://github.com/flamfrosticboio/rissue.lua/compare/v0.2.0...v0.2.1)

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
  - Added `Process:is_running()` which checks if the process is currently
    running.
  - Improved debugging by changing log levels on certain statements.

- `utils/log` [Breaking Changes]
  - Add setup.
  - Separate logging with timestamp and error level into its own function (as
    builtin logger)
    [#27](https://github.com/flamfrosticboio/rissue.lua/issues/27).

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

Full changelog:
[https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2](https://github.com/flamfrosticboio/rissue.lua/compare/v0.1...v0.2.0)

## v0.1

Initial commit.
