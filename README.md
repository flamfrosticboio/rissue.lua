# RIssue

A nvim plugin that abstracts issues and pull requests from git providers such as:

- github
- gitlab
- gitea
- forgejo (codeberg)

This plugin can be extended for integrations for multiple plugins such as Snacks.

## Setup

Install dependencies required:

- luv (lua libuv)

  ```bash
  # With luarocks
  luarocks install luv
  ```

- curl (version >= 7.81.0)

On linux, install it with your preferred package manager (apt, pacman, etc.).

On windows, install it with your preferred way (winget, website, choco, etc.)

### Support

#### Github

Github versions that the provider supports:

- api.github.com (2026-03-10)
- ghec (Github Enterprise Cloud) (2026-03-10)
- ghes 3.10-3.22 (Github Enterprise Server) (2026-03-10 and 2022-11-28)

Minimum active support for ghes: 3.10

Theoretical support for ghes: 3.0

> [!NOTE] Support for ghes versions lower than the minimum active support
> There is has no active maintenance for versions lower than the active support,
> but is sometimes compatible from the theoretical support. For compatibility, versions
> starting at ghes 3.0 will be tested.

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
