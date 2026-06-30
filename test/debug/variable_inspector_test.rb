# frozen_string_literal: true

require 'test/unit'
require_relative '../../lib/debug/variable_inspector'

module DEBUGGER__
  class VariableInspectorTest < Test::Unit::TestCase
    def setup
      @inspector = VariableInspector.new
    end

    def test_array_indexed_members
      a = ['a', 'b', 'c']

      # Test correct truncation
      assert_equal [], @inspector.indexed_members_of(a, start: 0, count: 0).map(&:value)
      assert_equal ['a'], @inspector.indexed_members_of(a, start: 0, count: 1).map(&:value)
      assert_equal ['a', 'b'], @inspector.indexed_members_of(a, start: 0, count: 2).map(&:value)
      assert_equal ['a', 'b', 'c'], @inspector.indexed_members_of(a, start: 0, count: 3).map(&:value)
      assert_equal ['a', 'b', 'c'], @inspector.indexed_members_of(a, start: 0, count: 4).map(&:value)
      assert_equal ['b'], @inspector.indexed_members_of(a, start: 1, count: 1).map(&:value)
      assert_equal ['b', 'c'], @inspector.indexed_members_of(a, start: 1, count: 2).map(&:value)
      assert_equal ['b', 'c'], @inspector.indexed_members_of(a, start: 1, count: 3).map(&:value)
      assert_equal ['b', 'c'], @inspector.indexed_members_of(a, start: 1, count: 4).map(&:value)

      # Test starting off the end
      assert_equal [], @inspector.indexed_members_of(a, start: 999, count: 1).map(&:value)

      assert_equal [], @inspector.indexed_members_of([], start: 0, count: 999)
      assert_equal [Variable.new(name: '0', value: 'a')], @inspector.indexed_members_of(['a'], start: 0, count: 999)

      expected = [
        Variable.new(name: '5', value: 'f'),
        Variable.new(name: '6', value: 'g'),
        Variable.new(name: '7', value: 'h'),
      ]
      assert_equal expected, @inspector.indexed_members_of(Array('a'...'z'), start: 5, count: 3)
    end

    def test_named_members_of_hash
      actual = @inspector.named_members_of(
        {
          sym: 'has Symbol key',
          "str" => 'has String key',
          1 => 'has Integer key',
        }
      )

      expected = [
        Variable.internal(name: '#class', value: Hash),
        Variable.new(name: ':sym', value: "has Symbol key"),
        Variable.new(name: '"str"', value: "has String key"),
        Variable.new(name: '1', value: "has Integer key"),
      ]

      assert_equal expected, actual
    end

    def test_named_members_of_struct
      expected = [
        Variable.internal(name: '#class', value: PointStruct),
        # Struct members are stored separately from ivars
        Variable.new(name: :x, value: 1),
        Variable.new(name: :y, value: 2),
        # If there are any other other ivars, they should also be included
        Variable.new(name: :@ivar, value: "some other ivar"),
      ]

      point = PointStruct.new(x: 1, y: 2)

      assert_equal expected, @inspector.named_members_of(point)
    end

    def test_named_members_of_string
      expected = [
        Variable.internal(name: '#class', value: String),
        Variable.internal(name: '#length', value: 5),
        Variable.internal(name: '#encoding', value: Encoding::UTF_8),
        # skip #dump member for short strings
      ]

      assert_equal expected, @inspector.named_members_of("hello")


      long_string = "A long string " + ('*' * 1000)

      expected = [
        Variable.internal(name: '#class', value: String),
        Variable.internal(name: '#length', value: long_string.length),
        Variable.internal(name: '#encoding', value: Encoding::UTF_8),
        Variable.internal(name: '#dump', value: VariableInspector::NaiveString.new(long_string)),
      ]

      assert_equal expected, @inspector.named_members_of(long_string)
    end

    def test_named_members_of_class
      expected = [
        Variable.internal(name: '#class', value: Class),
        Variable.internal(name: '%ancestors', value: PointStruct.ancestors.drop(1)),
      ]

      assert_equal expected, @inspector.named_members_of(PointStruct)
    end

    def test_named_members_of_module
      ancestors = [Module.new, Module.new, Module.new]
      mod = Module.new do
        include *ancestors
      end

      expected = [
        Variable.internal(name: '#class', value: Module),
        Variable.internal(name: '%ancestors', value: ancestors),
      ]

      assert_equal expected, @inspector.named_members_of(mod)
    end

    def test_named_members_of_range
      # Ranges that include end
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: 1),
          Variable.internal(name: "#end", value: 2),
        ],
        @inspector.named_members_of(1..2)
      )
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: 1),
          Variable.internal(name: "#end", value: nil),
        ],
        @inspector.named_members_of(1..)
      )
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: nil),
          Variable.internal(name: "#end", value: 2),
        ],
        @inspector.named_members_of(..2)
      )

      # Ranges that exclude end
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: 1),
          Variable.internal(name: "#end", value: 2),
        ],
        @inspector.named_members_of(1...2)
      )
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: 1),
          Variable.internal(name: "#end", value: nil),
        ],
        @inspector.named_members_of(1...)
      )
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: nil),
          Variable.internal(name: "#end", value: 2)
        ],
        @inspector.named_members_of(...2)
      )

      # Range with nil bounds
      assert_equal(
        [
          Variable.internal(name: "#class", value: Range),
          Variable.internal(name: "#begin", value: nil),
          Variable.internal(name: "#end", value: nil),
        ],
        @inspector.named_members_of(Range.new(nil, nil))
      )
    end

    def test_named_members_of_other_objects
      assert_equal [Variable.internal(name: '#class', value: Object)], @inspector.named_members_of(Object.new)

      expected = [
        Variable.internal(name: '#class', value: Point),
        # Struct members are stored separately from ivars
        Variable.new(name: :@x, value: 1),
        Variable.new(name: :@y, value: 2),
      ]

      point = Point.new(x: 1, y: 2)

      assert_equal expected, @inspector.named_members_of(point)
    end

    private

    class PointStruct < Struct.new(:x, :y, keyword_init: true)
      def initialize(x:, y:)
        super
        @ivar = "some other ivar"
      end
    end

    class Point # A "plain ol' Ruby object"
      def initialize(x:, y:)
        @x = x
        @y = y
      end
    end
  end
end
