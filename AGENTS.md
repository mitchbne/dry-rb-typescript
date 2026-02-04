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

- **TypeCompiler**: Visitor pattern that traverses dry-types AST and emits TypeScript type strings
  - `visit_nominal` → primitives (string, number, boolean, null)
  - `visit_sum` → union types (A | B)
  - `visit_array` → array types (T[])
  - `visit_constrained` → unwraps constrained types

## Testing

Uses minitest. TDD approach - write tests first, then implement.

## Code Style

- frozen_string_literal pragma on all Ruby files
- Follow dry-rb naming conventions
- No comments unless code is complex
- Never use `send` or `__send__` unless absolutely necessary (e.g., calling private methods in tests)
