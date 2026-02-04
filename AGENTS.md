# dry-typescript

A Ruby gem that converts Dry::Struct definitions to TypeScript types.

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run specific test file
bundle exec ruby -Itest test/dry/typescript/type_compiler_test.rb
```

## Architecture

### Core Compilation

- **TypeCompiler**: Visitor pattern that traverses dry-types AST and emits TypeScript type strings
  - `visit_nominal` → primitives (string, number, boolean, null)
  - `visit_sum` → union types (A | B)
  - `visit_array` → array types (T[])
  - `visit_constrained` → unwraps constrained types
- **StructCompiler**: Compiles a Dry::Struct class to TypeScript, handling nested structs, dependencies, and configuration
- **Generator**: Topologically sorts structs by dependencies for correct import ordering

### File Output

- **Writer**: Writes TypeScript files with fingerprint-based change detection, atomic writes, and import generation
- **FreshnessChecker**: Compares generated output in memory vs files on disk (used by `check` rake task for CI)

### Configuration

- **Config**: Global configuration (output_dir, null_strategy, transformers)
- **PerStructConfig**: Per-struct overrides via `typescript_config` block

### Rails Integration

- **Railtie**: Auto-configures in Rails, loads rake tasks, sets up file watching
- **Listen**: File watcher that regenerates types when struct files change
- **RakeTask**: Configurable rake task generator for non-Rails apps

### Mixins

- **StructMethods**: Adds `to_typescript` method to structs
- **StructExtension**: Alternative extension mechanism
- **AstVisitorHelpers**: Shared visitor helpers for array wrapping and union normalization

## Rake Tasks (Rails)

- `dry_typescript:generate` - Generate TypeScript files
- `dry_typescript:refresh` - Clean and regenerate
- `dry_typescript:clean` - Remove generated files
- `dry_typescript:check` - Check if types are up to date (exits 1 if stale, for CI)

## Testing

Uses minitest with TDD approach. Tests use anonymous classes to avoid ObjectSpace pollution across test files.

## Code Style

- frozen_string_literal pragma on all Ruby files
- Follow dry-rb naming conventions
- No comments unless code is complex
- Never use `send` or `__send__` unless absolutely necessary (e.g., calling private methods in tests)
