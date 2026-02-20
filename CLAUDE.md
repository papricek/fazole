# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fazole is a Ruby gem (early stage, scaffolded with `bundle gem`). Requires Ruby >= 3.2.0.

## Commands

- **Install dependencies:** `bin/setup` (or `bundle install`)
- **Interactive console:** `bin/console` (loads the gem into an IRB session)
- **Install gem locally:** `bundle exec rake install`
- **Release:** Update `lib/fazole/version.rb`, then `bundle exec rake release`

## Architecture

- `lib/fazole.rb` — Main entry point, defines `Fazole` module and base `Fazole::Error`
- `lib/fazole/version.rb` — Version constant
- `sig/fazole.rbs` — RBS type signatures
- `exe/` — Directory for CLI executables (if any are added)

No test framework is configured yet. The default Rake task is empty.
