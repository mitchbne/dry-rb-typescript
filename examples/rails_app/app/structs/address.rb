# frozen_string_literal: true

class Address < Dry::Struct
  module Types
    include Dry.Types()
  end

  attribute :street, Types::String
  attribute :city, Types::String
  attribute :zip, Types::String.optional
end
