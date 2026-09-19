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

- [precommit](https://github.com/pre-commit/pre-commit) or
  [prek](https://github.com/j178/prek) (better)

  Install it with your preferred package manager.

  Afterwards, install precommit/prek in this project.

  ```bash
  # If using precommit
  precommit install

  # If using prek
  prek install
  ```

- [luals](https://luals.github.io) (language server)

  Install it with in your preferred IDE and use it.

- [stylua](https://github.com/JohnnyMorganz/StyLua) (formatter)

  Install it as a tool with your preferred package manager.

  Alternatively, you can install it with cargo:

  ```bash
  cargo install stylua
  ```

- [selene](https://github.com/JohnnyMorganz/StyLua) (linter)

  Install it as a tool with your preferred package manager.

  Alternatively, you can install it with cargo:

  ```bash
  cargo install selene
  ```

- [busted](https://github.com/lunarmodules/busted)

  Can be installed with luarocks:

  ```bash
  luarocks install busted
  ```

- [node](https://nodejs.org/en) (specifically npm)
  (markdown format)

  Install node (preferably with the latest LTS version) with your preferred
  package manager.

  Afterwards, install all node_modules needed:

  ```bash
  npm install
  ```
