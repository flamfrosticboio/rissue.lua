# RIssue

A nvim plugin that abstracts issues and pull requests from git providers such as:

- github
- gitlab
- gitea
- forgejo (codeberg)

This plugin can be extended for integrations for multiple plugins such as Snacks.

## Setup

TODO: Write setup here

## Developing

### Required Tools

- [precommit](https://github.com/pre-commit/pre-commit) or
  [prek](https://github.com/j178/prek) (better)
  (install on `hook` types `precommit` and `commit-msg`)

  ```bash
  # If using precommit
  precommit install

  # If using prek
  prek install
  ```

- [emmylua_analyzer_rust](https://github.com/EmmyLuaLs/emmylua-analyzer-rust)
  (lsp, format, checker)

  Needed binaries from `emmylua_analyzer_rust`

  ```bash
  cargo install emmylua_ls          # Language server
  cargo install emmylua_formatter   # Code formatter
  cargo install emmylua_check       # Static analyzer / linter
  ```

- [busted](https://github.com/lunarmodules/busted)

  Can be installed with luarocks:

  ```bash
  luarocks install busted
  ```
