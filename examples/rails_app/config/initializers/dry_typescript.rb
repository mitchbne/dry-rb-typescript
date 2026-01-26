# frozen_string_literal: true

Dry::TypeScript.configure do |config|
  config.output_dir = Rails.root.join("app/javascript/types")
  config.dirs = [Rails.root.join("app/structs")]
  config.listen = false
end
