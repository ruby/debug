# frozen_string_literal: true

require 'test/unit'
require_relative '../../lib/debug/reflection'

module DEBUGGER__
  class ReflectionTest < Test::Unit::TestCase
    def setup
      @sample_object = SampleClass.new(1, 2)
    end

    def test_instance_variables_of
      assert_equal [:@a, :@b], Reflection.instance_variables_of(@sample_object)
    end

    def test_instance_variables_get
      assert_equal 1, Reflection.instance_variable_get_from(@sample_object, :@a)
      assert_equal 2, Reflection.instance_variable_get_from(@sample_object, :@b)
    end

    def test_class_of
      assert_same SampleClass, Reflection.class_of(@sample_object)
    end

    def test_singleton_class_of
      expected = class << SampleClass
        self
      end

      assert_same expected, Reflection.singleton_class_of(SampleClass)
    end

    def test_is_kind_of?()
      assert_true Reflection.is_kind_of?(@sample_object, SampleClass)
      assert_false Reflection.is_kind_of?(@sample_object, Object)
    end

    def test_responds_to?
      assert_true Reflection.responds_to?(@sample_object, :a)
      assert_false Reflection.responds_to?(@sample_object, :doesnt_exist)

      assert_false Reflection.responds_to?(@sample_object, :sample_private_method)
      assert_false Reflection.responds_to?(@sample_object, :sample_private_method, include_all: false)
      assert_true Reflection.responds_to?(@sample_object, :sample_private_method, include_all: true)
    end

    def test_method_of
      assert_equal 1, Reflection.method_of(@sample_object, :a).call
    end

    def test_object_id_of
      assert_equal @sample_object.__id__, Reflection.object_id_of(@sample_object)
    end

    def test_name_of
      assert_equal "DEBUGGER__::ReflectionTest::SampleClass", Reflection.name_of(SampleClass)
    end

    def test_bind_call_backport
      omit_if(
        UnboundMethod.instance_method(:bind_call).source_location.nil?,
        "This Ruby version (#{RUBY_VERSION}) has a native #bind_call implementation, so it doesn't need the backport.",
      )

      puts caller_locations
      original_object = SampleTarget.new("original")
      new_target = SampleTarget.new("new")

      m = original_object.method(:sample_method).unbind

      rest_args = ["a1", "a2"]
      kwargs = { k1: 1, k2: 2 }
      proc = Proc.new { |x| x }

      result = m.bind_call(new_target, "parg1", "parg2", *rest_args, **kwargs, &proc)

      assert_equal "new", result.fetch(:self).id
      assert_equal "parg1", result.fetch(:parg1)
      assert_equal "parg2", result.fetch(:parg2)
      assert_equal rest_args, result.fetch(:rest_args)
      assert_equal kwargs, result.fetch(:kwargs)
      assert_same proc, result.fetch(:block)
    end

    private

    # A class for testing reflection, which doesn't implement all the usual reflection methods being tested.
    class SampleClass < BasicObject
      attr_reader :a, :b

      def initialize(a, b)
        @a = a
        @b = b
      end

      private

      def sample_private_method; end

      class << self
        undef_method :method
      end
    end

    class SampleTarget
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def sample_method(parg1, parg2, *rest_args, **kwargs, &block)
        { self: self, parg1: parg1, parg2: parg2, rest_args: rest_args, kwargs: kwargs, block: block }
      end
    end
  end
end
