# frozen_string_literal: true

module Dry
  module TypeScript
    class Generator
      attr_reader :structs

      def initialize(structs:)
        @structs = structs
      end

      def call
        results = {}
        sorted_structs.each do |struct_class|
          compiler = StructCompiler.new(struct_class)
          results[struct_class] = compiler.call
        end
        results
      end

      def sorted_structs
        return [] if @structs.empty?

        build_dependency_graph
        topological_sort
      end

      private

      def build_dependency_graph
        @dependencies = {}
        @structs.each do |struct_class|
          compiler = StructCompiler.new(struct_class)
          result = compiler.call
          deps = result[:dependencies].select { |d| @structs.include?(d) }
          @dependencies[struct_class] = deps
        end
      end

      def topological_sort
        sorted = []
        visited = {}
        temp_visited = {}

        @structs.each do |struct_class|
          visit(struct_class, sorted, visited, temp_visited) unless visited[struct_class]
        end

        sorted
      end

      def visit(struct_class, sorted, visited, temp_visited)
        return if visited[struct_class]

        if temp_visited[struct_class]
          sorted << struct_class unless sorted.include?(struct_class)
          return
        end

        temp_visited[struct_class] = true

        (@dependencies[struct_class] || []).each do |dep|
          visit(dep, sorted, visited, temp_visited)
        end

        temp_visited.delete(struct_class)
        visited[struct_class] = true
        sorted << struct_class
      end
    end
  end
end
