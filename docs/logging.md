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

## Types

<!-- &rissue.log.level@docs -->

### `rissue.log.level`

Type: `alias` -- `0|1|2|3|4...(+1)`

Logging levels where:

- off: 5
- error: 4
- warn: 3
- info: 2
- debug: 1
- trace: 0

<!-- &rissue.log.level@docs -->

<!-- &rissue.log.Opts@docs -->

### `rissue.log.Opts`

Type: `class`

Options for logger

- builtin_logger_color_enabled: `boolean?`
  -- Enables or disables printing with `colors` on the built-in logger.
- log_level: `(0|1|2|3|4...(+1))?`
  -- The current log level. Use `log.levels.<name>` to set up or pass an integer
  corresponding to the log level.
- logger: `fun(msg: string, level: 0|1|2|3|4...(+1), info?: rissue.logger.log_info)?`
  -- Replaces the current built-in logger.

<!-- &rissue.log.Opts@docs -->
<!-- &rissue.logger@docs -->

### `rissue.logger`

Type: `class`

- debug: `fun(...any)` -- Log an `debug` statement
- error: `fun(...any)` -- Log an `error` message
- get_log_level: `fun():integer` -- Gets the current log level
- info: `fun(...any)` -- Log an `info` message
- level_enabled: `fun(level: 0|1|2|3|4...(+1)):boolean`
- levels: `rissue.log.levels` -- List of levels
- log: `fun(msg: string, level: 0|1|2|3|4...(+1))`
  -- Logs to logger.

  Warning: Does not filter logging based on current log level.
  Wrap it with `log.level_enabled()` instead.

- set_log_level: `fun(level: "debug"|"error"|"info"|"off"|"trace"...(+7))`
  -- Sets the current log level
- set_logger: `fun(logger: fun(msg: string, level: 0|1|2|3|4...(+1), info?: rissue.logger.log_info))`
- trace: `fun(...any)` -- Log an `trace` statement
- warn: `fun(...any)` -- Log an `warning` message

<!-- &rissue.logger@docs -->

<!-- &rissue.mod.logger@docs -->

### `rissue.mod.logger`

Type: `class`

- debug: `fun(...any)` -- Log an `debug` statement
- error: `fun(...any)` -- Log an `error` message
- get_log_level: `fun():integer` -- Gets the current log level
- info: `fun(...any)` -- Log an `info` message
- level_enabled: `fun(level: 0|1|2|3|4...(+1)):boolean`
- levels: `rissue.log.levels` -- List of levels
- log: `fun(msg: string, level: 0|1|2|3|4...(+1))`
  -- Logs to logger.

  Warning: Does not filter logging based on current log level.
  Wrap it with `log.level_enabled()` instead.

- new: `fun(opts?: rissue.log.new.Opts):rissue.logger`
  -- Creates a new logger instance. If logger is not passed from opts, it will
  use the global logger.
- set_log_level: `fun(level: "debug"|"error"|"info"|"off"|"trace"...(+7))`
  -- Sets the current log level
- set_logger: `fun(logger: fun(msg: string, level: 0|1|2|3|4...(+1), info?: rissue.logger.log_info))`
- setup: `fun(opts: rissue.log.Opts)` -- Setup the global logger.
- trace: `fun(...any)` -- Log an `trace` statement
- warn: `fun(...any)` -- Log an `warning` message

<!-- &rissue.mod.logger@docs -->

<!-- &rissue.log.new.Opts@docs -->

### `rissue.log.new.Opts`

Type: `class`

- context: `string?`
- logger: `fun(msg: string, level: 0|1|2|3|4...(+1), info?: rissue.logger.log_info)?`

<!-- &rissue.log.new.Opts@docs -->
<!-- &rissue.logger_func@docs -->

### `rissue.logger_func`

Type: `alias` -- `fun(msg: string, level: 0|1|2|3|4...(+1), info?: rissue.logger.log_info)`

<!-- &rissue.logger_func@docs -->
