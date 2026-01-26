# frozen_string_literal: true

class User < Dry::Struct
  module Types
    include Dry.Types()
  end

  attribute :id, Types::Integer
  attribute :name, Types::String
  attribute :email, Types::String
  attribute :age, Types::Integer.optional
  attribute :active, Types::Bool
  attribute :address, Address
  attribute :tags, Types::Array.of(Types::String)
end
