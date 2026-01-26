# Dry::TypeScript Implementation Handoff Prompts

Each prompt below is designed to be handed off to a separate Amp thread. Execute them in order (Phase 1 → 5).

---

## Phase 1: Project Scaffolding & Core Type Compiler

```
You are implementing Phase 1 of dry-typescript, a Ruby gem that converts Dry::Struct definitions to TypeScript types.

## Your Task
Build the foundational gem structure and core TypeCompiler using TDD.

## Step 1: Research (Use Librarian)
Use the librarian tool to understand:
1. How dry-types represents primitives internally (Dry::Types::Nominal, .primitive method)
2. How dry-types Sum types work (for optionals like `Types::String.optional`)
3. How dry-types Array::Member works for typed arrays
4. The visitor pattern used in dry-schema's json_schema extension

## Step 2: Scaffold the Gem
Create the basic gem structure:
- dry-typescript.gemspec (depend on dry-types ~> 1.7, dry-struct ~> 1.6)
- lib/dry-typescript.rb (main entry point)
- lib/dry/typescript/version.rb
- lib/dry/typescript/type_compiler.rb
- Gemfile
- Rakefile (with minitest task)
- test/test_helper.rb

## Step 3: Implement TypeCompiler (TDD)
Create test/dry/typescript/type_compiler_test.rb with tests for:

1. Primitive mapping:
   - Dry::Types["string"] → "string"
   - Dry::Types["integer"] → "number"
   - Dry::Types["float"] → "number"
   - Dry::Types["bool"] → "boolean"
   - Dry::Types["nil"] → "null"
   - Dry::Types["date"] → "string" (with comment about ISO format)
   - Dry::Types["time"] → "string"
   - Dry::Types["date_time"] → "string"

2. Optional types (Sum with nil):
   - Dry::Types["string"].optional → "string | null"

3. Array types:
   - Dry::Types["array"].of(Dry::Types["string"]) → "string[]"
   - Dry::Types["array"].of(Dry::Types["integer"]).optional → "number[] | null"

4. Union types:
   - Dry::Types["string"] | Dry::Types["integer"] → "string | number"

5. Constrained types (unwrap decorator):
   - Dry::Types["integer"].constrained(gt: 0) → "number"

Implement TypeCompiler with a visitor pattern:
- visit(type) dispatches to visit_nominal, visit_sum, visit_array, visit_constrained
- Each visitor returns a TypeScript type string

## Step 4: Analyze with Oracle
Once tests pass, use the Oracle tool to:
- Review the TypeCompiler architecture for extensibility
- Identify edge cases not covered by tests
- Suggest improvements for the visitor pattern implementation

## Verification
Run: bundle exec rake test
All tests should pass.
```

---

## Phase 2: Struct Compiler & Schema Walking

```
You are implementing Phase 2 of dry-typescript. Phase 1 (TypeCompiler for primitives) is complete.

## Your Task
Build the StructCompiler that walks Dry::Struct schemas and generates TypeScript interface definitions.

## Step 1: Research (Use Librarian)
Use the librarian tool to understand:
1. How Dry::Struct.schema works and returns a Dry::Types::Hash::Schema
2. How to iterate schema.keys to get Key objects
3. Key object API: key.name, key.type, key.required?
4. How nested Dry::Struct classes appear in schemas
5. How to detect if a type IS a Dry::Struct subclass

## Step 2: Implement StructCompiler (TDD)
Create test/dry/typescript/struct_compiler_test.rb with tests for:

1. Simple struct:
```ruby
class User < Dry::Struct
  attribute :name, Types::String
  attribute :age, Types::Integer
end
# → "type User = {\n  name: string;\n  age: number;\n}"
```

2. Optional attributes:
```ruby
class User < Dry::Struct
  attribute :name, Types::String
  attribute :nickname, Types::String.optional
end
# → nickname should be "nickname?: string | null" or "nickname: string | null"
```

3. Array attributes:
```ruby
class User < Dry::Struct
  attribute :tags, Types::Array.of(Types::String)
end
# → "tags: string[]"
```

4. Nested structs (inline):
```ruby
class User < Dry::Struct
  attribute :address do
    attribute :city, Types::String
    attribute :zip, Types::String
  end
end
# → address: { city: string; zip: string }
```

5. Referenced structs:
```ruby
class Address < Dry::Struct
  attribute :city, Types::String
end
class User < Dry::Struct
  attribute :address, Address
end
# → Should track Address as a dependency/import
```

Create lib/dry/typescript/struct_compiler.rb:
- StructCompiler.new(struct_class)
- #call returns { typescript: "type User = {...}", dependencies: [Address] }
- Uses TypeCompiler internally for attribute types
- Handles required vs optional attributes

## Step 3: Analyze with Oracle
Once tests pass, use the Oracle to:
- Review how nested vs referenced structs are handled
- Ensure the dependency tracking is correct for import generation
- Check for circular reference handling

## Verification
Run: bundle exec rake test
All tests should pass.
```

---

## Phase 3: Extension Module (Struct.to_typescript)

```
You are implementing Phase 3 of dry-typescript. Phases 1-2 (TypeCompiler, StructCompiler) are complete.

## Your Task
Create the extension that adds `.to_typescript` method to Dry::Struct classes, similar to dry-schema's json_schema extension.

## Step 1: Research (Use Librarian)
Use the librarian tool to understand:
1. How dry-schema's json_schema extension is structured (lib/dry/schema/extensions/json_schema.rb)
2. How it injects methods into Processor class via module inclusion
3. How dry-struct's ClassInterface module works for adding class methods
4. Pattern for optional extension loading in dry-rb gems

## Step 2: Implement Extension (TDD)
Create test/dry/typescript/extension_test.rb with tests for:

1. Extension loading:
```ruby
require "dry/typescript"
Dry::Struct.extend(Dry::TypeScript::StructMethods)
# or: require "dry/typescript/struct_extension"
```

2. Basic usage:
```ruby
class User < Dry::Struct
  attribute :name, Types::String
end
User.to_typescript
# => "type User = {\n  name: string;\n}"
```

3. With options:
```ruby
User.to_typescript(name: "UserDTO")  # Custom type name
User.to_typescript(export: true)     # "export type User = ..."
```

4. Multiple structs with dependencies:
```ruby
[User, Address].map(&:to_typescript)
# Should return array with proper import statements
```

Create lib/dry/typescript/struct_methods.rb:
- Module that gets included into Dry::Struct
- Adds .to_typescript class method
- Delegates to StructCompiler

Create lib/dry/typescript/struct_extension.rb:
- Auto-registers the extension when required

## Step 3: Analyze with Oracle
Once tests pass, use the Oracle to:
- Review the extension pattern matches dry-rb conventions
- Check that it doesn't pollute Dry::Struct unnecessarily
- Verify thread-safety of the implementation

## Verification
Run: bundle exec rake test
All tests should pass.
```

---

## Phase 4: Configuration System

```
You are implementing Phase 4 of dry-typescript. Phases 1-3 are complete.

## Your Task
Build a configuration system for customizing TypeScript output (naming conventions, optionality handling, custom type mappings).

## Step 1: Research (Use Librarian)
Use the librarian tool to understand:
1. How typelizer's Config class works with hierarchical settings
2. How dry-configurable gem works (if used by dry-rb)
3. Common configuration patterns in dry-rb gems
4. How to handle null_strategy options (:nullable, :optional, :nullable_and_optional)

## Step 2: Implement Configuration (TDD)
Create test/dry/typescript/config_test.rb with tests for:

1. Global configuration:
```ruby
Dry::TypeScript.configure do |config|
  config.output_dir = "app/javascript/types"
  config.null_strategy = :optional  # name?: Type vs name: Type | null
  config.export_keyword = true      # "export type" vs "type"
end
```

2. Custom type mapping:
```ruby
Dry::TypeScript.configure do |config|
  config.type_mappings[BigDecimal] = "string"
  config.type_mappings[Date] = "Date"  # Use JS Date instead of string
end
```

3. Name transformers:
```ruby
Dry::TypeScript.configure do |config|
  config.type_name_transformer = ->(name) { "#{name}DTO" }
  config.property_name_transformer = ->(name) { name.to_s.camelize(:lower) }
end
```

4. Per-struct overrides:
```ruby
class User < Dry::Struct
  typescript_config do |config|
    config.type_name = "UserResponse"
  end
end
```

Create lib/dry/typescript/config.rb:
- Config class with defaults
- Dry::TypeScript.config accessor
- Dry::TypeScript.configure block method
- Merge logic for per-struct overrides

Update TypeCompiler and StructCompiler to use Config.

## Step 3: Analyze with Oracle
Once tests pass, use the Oracle to:
- Review configuration precedence (global < per-struct)
- Check for missing commonly-needed options
- Verify the API is intuitive and matches dry-rb patterns

## Verification
Run: bundle exec rake test
All tests should pass.
```

---

## Phase 5: File Generator & Writer

```
You are implementing Phase 5 of dry-typescript. Phases 1-4 are complete.

## Your Task
Build the Generator (discovers structs) and Writer (outputs .ts files) with smart change detection.

## Step 1: Research (Use Librarian)
Use the librarian tool to understand:
1. How typelizer's Generator discovers serializer classes
2. How typelizer's Writer handles file output and cleanup
3. How fingerprinting works for change detection
4. How barrel exports (index.ts) are generated

## Step 2: Implement Generator (TDD)
Create test/dry/typescript/generator_test.rb with tests for:

1. Struct discovery:
```ruby
Dry::TypeScript::Generator.new(dirs: ["app/structs"]).structs
# Returns all Dry::Struct subclasses in those directories
```

2. Dependency resolution:
```ruby
generator.sorted_structs  # Topologically sorted by dependencies
```

3. Full generation:
```ruby
Dry::TypeScript::Generator.call(force: false)
# Returns list of written file paths
```

Create lib/dry/typescript/generator.rb.

## Step 3: Implement Writer (TDD)
Create test/dry/typescript/writer_test.rb with tests for:

1. Single file output:
```ruby
writer = Dry::TypeScript::Writer.new(output_dir: "tmp/types")
writer.write(User)  # Creates tmp/types/User.ts
```

2. Import generation:
```ruby
# User references Address
# User.ts should have: import type { Address } from './Address';
```

3. Index file:
```ruby
writer.write_index([User, Address])
# Creates index.ts with: export type { User } from './User';
```

4. Fingerprint-based skipping:
```ruby
writer.write(User)  # Writes file
writer.write(User)  # Skips (no changes)
# Modify struct...
writer.write(User)  # Writes file (fingerprint changed)
```

5. Stale file cleanup:
```ruby
writer.cleanup(current_structs: [User])
# Removes .ts files for structs no longer in list
```

Create lib/dry/typescript/writer.rb with ERB templates.

## Step 4: Rake Task
Create lib/dry/typescript/rake_task.rb:
```ruby
# Usage in Rakefile:
require "dry/typescript/rake_task"
Dry::TypeScript::RakeTask.new(:typescript) do |t|
  t.dirs = ["app/structs"]
  t.output_dir = "app/javascript/types"
end
# Provides: rake typescript:generate, rake typescript:clean
```

## Step 5: Analyze with Oracle
Once tests pass, use the Oracle to:
- Review the full generation pipeline end-to-end
- Check for race conditions in file writing
- Verify import paths are correct for various project structures
- Suggest watch mode implementation for development

## Verification
Run: bundle exec rake test
All tests should pass.

Create a working example in examples/ directory demonstrating full usage.
```

---

## Execution Order

1. **Phase 1** → Creates gem skeleton + TypeCompiler
2. **Phase 2** → StructCompiler (depends on TypeCompiler)
3. **Phase 3** → Extension module (depends on StructCompiler)
4. **Phase 4** → Configuration (integrates with all compilers)
5. **Phase 5** → Generator/Writer (orchestrates everything)

Each phase builds on the previous and can be verified independently.
