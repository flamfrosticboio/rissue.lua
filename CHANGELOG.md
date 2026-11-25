# Changelog

## v0.3.0

**Features:**

- Use new async model that is used for rissue.

  - Refactored all async related code in rissue to use the new async model.

- Check curl version in the background during `setup` and log a warning when
  curl cannot be run or is incompatible.

- [utils/process]:
  - Add auto enabling on logging on process's stdout and stderr when `trace` is
    enabled in log level.

  - Add new option `newline_on_multiline_output` on `Process.get_last_stdout()`
    and `Process.get_last_stderr()`. This change also updates how to pass
    options to these functions.

    ```lua
    --- previously
    process:get_last_stdout(true) -- strip lines when passed true
    --- now
    process:get_last_stdout({
      strip_new_lines = true,
      newline_on_multiline_output = true
    })
    ```

- [utils/log]
  - Refactored the logging library where it introduces `rissue.mod.logger` and
    `rissue.Logger`.

    With `require('rissue.utils.log').new()`, you can create a scoped
    `rissue.Logger` where it can take:
    - context: `rissue.log.log_info` (passed to the logger)
    - logger: `rissue.logger_func`
    - log_level: `rissue.log.level`

    With log information, you can print additional texts to logging to make
    debugging easier.

    Example:

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

  - Regular printing functions such as `log.info()`, `log.warn()` and etc. can
    now take multiple parameters.

  - New functions:
    - `log.get_log_level()` to get current log level.

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

  - Add `table_op.tbl_keys()` to list the keys of a table.

- [utils/curl]:
  - Add `is_version_compatible` to check that installed curl is at least 7.83.0
    and below 9.0.0.

  - Add `rissue.curl.Error` with `exitcode`, `msg` (from stderr) and
    `server_msg` (from stdout). `server_msg` is `nil` when stdout is empty.

  - Use `exitcode = -1` for internal errors not coming from curl, including
    `--dump-header` file errors.
  - Fall back to "curl failed (exit code N)" in `msg` when stderr is empty.
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

  - Trim surrounding whitespace from stdout and stderr.
  - Validate `opts.data_type` in `construct` and list valid values in the error
    message.
  - Validate `opts.data` in `construct`: it must be a string or table, and table
    keys must be strings.
  - Accept `nil` `opts` in `request`.

- [utils/curl]:
  - Add new options: `outfile` and `retry_when`

    The `outfile` option is a `-o <file>` in the hood, but when using this
    option, it makes the return's contents to empty string because the file is
    not outputted to stdout.

    Notes: it also passes `--create-dirs` and `--remove-on-error` flags when
    used.

    The `retry_when` option is built-in to curl where it attempts to retry when
    if fails to fetch. The retries are controlled by `retries` and `retry_delay`
    option.

    Possible values of `retry_when` are: `false` | `"all"` | `"connrefused"`

    When it is `false`, it will not retry on any error.

    When it is `all`, it will retry on every error, including `opts.fail_fast`

    When it is `connrefused`, it will retry only when the connection refused to
    connect.

  - Add `rissue.curl.Error` with `exitcode`, `msg` (from stderr) and
    `server_msg` (from stdout).

  - Use `exitcode = -1` for internal errors not coming from curl, including
    `--dump-header` file errors.

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

  - Trim surrounding `whitespaces` from stdout and stderr with `strings.trim`.

- [utils/assert_op]: Refactor `check_structure` (now called `table_expects`) to
  use matchers for support for literals and more complicated checking.

- New utils module: `strings`

  This new module contains the following functions:
  - `strings.trim()`: Trims `whitespaces` fast.
  - `strings.trim_newlines()`: Trims `newlines` fast.
  - `strings.truncate()`: Truncates a string safely on utf-8
  - `strings.represent_value()`: Wraps strings in double quotes and uses
    `tostring` for other values.

- New Gitlab module. You can now query gitlab.com and self-hosted gitlab
  instances for issues and merge requests

- [utils/json]:
  - Add new field "loaded" that shows the currently loaded json backend.

- New utils module: "deduplicator"

  This new module returns a function that deduplicates results based on id.

  Example:

  ```lua
  -- Not the exact implementation with gitlab
  local function construct_merge_requests(item) return item end
  local function get_id(item) return item.id end
  local function cb(item) print(item.name) end
  local cb = deduplicator(cb, construct_merge_requests, get_id),

  cb({ id = 1, name = "Hello" }) -- prints 'Hello'
  cb({ id = 2, name = "Hi" }) -- prints 'Hi'
  cb({ id = 1, name = "Hello" }) -- prints nothing
  ```

- [config]:
  - Reject providers whose `version` is incompatible with
    `EXTENSION_FORMAT_VERSION` (1.0.0). The error names the provider, the
    required version and the current version.

- [utils/versions]:
  - Return `?` from `represent()` when the number cannot be decoded.

**Changes:**

- [utils/log] Accessing `log_level` (now called `_level`) and `_logger` are
  tagged protected.

- [Github]:
  - Updated logging to be more clear and simpler.

  - Improved pattern detection when checking github support on provided url.

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

- [config]:
  - Change endpoint_shortcuts to a list, so multiple shortcuts can point to the
    same git provider.

  - Report built-in provider load failures from `config.setup` as `[bug]` errors
    instead of failing on require.

  - Prefix additional provider errors with `failed to load '<path>'`. Spec
    errors now read `Not a provider spec: ...` instead of
    `Module at '<path>' is not a provider spec: ...`.

- [utils/curl]:
  - Set `server_msg` to `nil` when stdout is empty instead of `""`.

- [utils/json]:
  - Improved error reporting.

**Bug Fixes:**

- [utils/process, utils/async]: Fix unpack is unavailable on other lua versions.

- [utils/curl]:
  - Fix constant variable mutation errors when using lua5.5

  - Fix tmpfile not deleted on curl error when using
    `opts.include_result_headers`.

  - Reject string `data` for `form_string` instead of stale `form_literal`.

- [utils/process]: Fixed running status is still true when process has exited
  during the `on_exit` event.

- [config]: fix additional providers getting wrong checks
  [#72](https://github.com/flamfrosticboio/rissue.lua/issues/72)

- [provider]: scope opts properly by provider name
  [#76](https://github.com/flamfrosticboio/rissue.lua/issues/76)

- [utils/process]:
  - Read stdout and stderr pipes until EOF, then force-close them after a 100ms
    grace period, so the last output is no longer lost when the process exits.

**Breaking Changes:**

- [utils/log]: Removed `log_func`. Write a manual implementation instead.

- [utils/process]: Removed `process.run()` and `process.run_co()`. Use
  `process.run_async()` instead.

- [provider]: `Provider.get_issues()` and `Provider.get_merge_requests()` will
  now take a fourth parameter `cb: fun(item: T)` where `T` is `rissue.issue` or
  `rissue.pr`. The return type is updated from
  `rissue.issue[]? results, string? err_msg` to `string? err_msg`

- [specifications/providers]: The versioning system for providers uses
  `version: {major: integer, minor: integer, patch: integer}` instead of
  `version: string` and `version_code: integer`. Any existing providers using
  the old versioning system will not work anymore.

- [utils/assert_op]: `assert_op.check_structure()` is now migrated to
  `assert_op.table_expects()` which has a different structure. See more on these
  commits:
  - [base (b875e7c)](https://github.com/flamfrosticboio/rissue.lua/pull/73/changes/b875e7cd6c1fbf1ebd6c873d5b7a887edbaabf6f).
  - [is_integer (b50445b)](https://github.com/flamfrosticboio/rissue.lua/commit/b50445b809fb677f62be6ec2fa92c573dd33ad12)

  New Usage Example:

  ```lua
  local obj_to_compare = {} -- the table object to compare
  local structure = {
    name = "hello", -- a literal
    full_name = assert_op.matchers.is_string() -- or any type which is a string
    --- see more on assert_op.matchers to see how much you can do.
  }
  assert_op.check_structure(obj_to_compare, structure, name)
  ```

- [utils/curl]:
  - Rename `rissue.utils.curl.Result` to `rissue.curl.Result`.

  - Remove `exitcode` and `err` fields from `rissue.curl.Result`. Errors are now
    reported through the new `rissue.curl.Error`.

  - `raw`, `request` and `post` now return `rissue.curl.Error` instead of a
    string on error. A nonzero curl exit code now returns an error instead of a
    result.

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

- [config]:
  - `config.endpoint_shortcuts` now takes a list of `rissue.EndpointShortcut`
    rather than a table.
  - `rissue.EndpointShortcut` requires the `name: rissue.ProviderName` field.

  - `config.providers` is now empty until `config.setup` runs. Built-in
    providers are loaded during setup instead of on require.

    ```lua
    --- previously
    local config = require("rissue.config")
    config.providers.github -- available right after require
    --- now
    local config = require("rissue.config")
    config.setup()
    config.providers.github -- available only after setup
    ```

- [docs]: Type names are updated to reflect to its use case better.
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

- [utils/curl]:
  - Rename `rissue.utils.curl.Opts`, `Result`, `Method`, `Formats`, `DataType`
    and `AuthMethod` to `rissue.curl.*`.
  - Remove `exitcode` and `err` fields from `rissue.curl.Result`. `content` now
    holds trimmed stdout.
  - `raw`, `request` and `post` now return `rissue.curl.Error` instead of a
    string on error. A nonzero curl exit code now returns an error instead of a
    result.

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

- `construct` now returns `nil, err_msg` on invalid options instead of raising
  with `error()`. `request` wraps that message in a `rissue.curl.Error` with
  `exitcode = -1`.

  ```lua
  --- previously
  local ok, args = pcall(curl.construct, url, opts)
  --- now
  local args, err = curl.construct(url, opts)
  ```

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
