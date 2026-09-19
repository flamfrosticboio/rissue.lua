# RIssue

A nvim plugin that abstracts issues and pull requests from git providers such as:

- github
- gitlab
- gitea
- forgejo (codeberg)

This plugin can be extended for integrations for multiple plugins such as Snacks.

## Documentation

Browse in the [docs folder](./docs) for documentation.

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

- [node](https://nodejs.org/en) (specifically npm)
  (markdown format)

  Install node (preferably with the latest LTS version) with your preferred
  package manager

### Setup Development Tools

Setup development tools such as prettier by running the command below:

```bash
npm install
```
