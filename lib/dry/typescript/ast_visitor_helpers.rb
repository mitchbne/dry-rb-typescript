# frozen_string_literal: true

module Dry
  module TypeScript
    module AstVisitorHelpers
      private

      def normalize_union(ts_types)
        ts_types = ts_types.flat_map { |t| flatten_union(t) }.uniq

        if ts_types.include?("null")
          ts_types.delete("null")
          ts_types << "null"
        end

        ts_types.size == 1 ? ts_types.first : ts_types.join(" | ")
      end

      def flatten_union(ts_type)
        return [ts_type] unless ts_type.include?(" | ") && !ts_type.start_with?("(")

        ts_type.split(" | ")
      end

      def wrap_array_member(member_ts)
        member_ts = "(#{member_ts})" if needs_parens_in_array?(member_ts)
        "#{member_ts}[]"
      end

      def needs_parens_in_array?(member_ts)
        member_ts.include?(" | ") || member_ts.include?(" & ")
      end
    end
  end
end
