# Logging

Its possible to setup logger in multiple ways:

- With `rissue.setup()`: Pass the options under `log`

  Example:

  ```lua
  rissue.setup({
      log = {
          log_level = 3, -- log.levels.warn
      }
  })
  ```

- With `log.setup()`: Pass the options directly

  Example:

  ```lua
  log.setup({
    log_level = log.levels.warn,
  })
  ```

- Manually (not recommended)

  Example:

  ```lua
  log.set_log_level(log.levels.warn)
  log.set_log_level("warn")
  log.set_logger(function(msg, level, info)
    print(level, info.context, ":", msg)
  end)
  ```

## Usage

To use this logger, you have multiple ways depending on use case:

### Calling predefined functions directly

`log.warn()`, `log.info()`, `log.error()`, `log.trace()`, `log.debug()` all take
multiple arguments where each argument is converted into string. They are each
combined with a space in between.

Example:

```lua
local name = "yourname"
log.info("My name is", name)
--- outputs "My name is yourname"
```

### Calling `log.log()`

`log.log(msg: string, level: rissue.log.level)` is a function that takes two
arguments only and does not respect the current log level (combine it with
`log.level_enabled()`).

This is used when your logging statements needs expensive computation but not
necessary use it when that log level is not enabled.

Example:

```lua
if log.level_enabled(log.levels.trace) then
    local debug_statement = expensive_computation(data)
    log.log(debug_statement, log.levels.trace)
end
```

See more on [docs/types.md#rissue.Logger](#docs/types.md#rissuelogger)
