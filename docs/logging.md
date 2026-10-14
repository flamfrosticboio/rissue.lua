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
- logger: `fun(msg: string, level: integer)?`
  -- Replaces the current built-in logger.

<!-- &rissue.log.Opts@docs -->
<!-- &rissue.log.logger@docs -->

### `rissue.log.logger`

Type: `alias` -- `fun(msg: string, level: integer)`

<!-- &rissue.log.logger@docs -->
