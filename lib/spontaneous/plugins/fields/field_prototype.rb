# encoding: UTF-8


module Spontaneous::Plugins
  module Fields
    class FieldPrototype
      attr_reader :name

      def initialize(name, type, options={})
        @name = name
        # if the type is nil then try the name, this will assign sensible defaults
        # to fields like 'image' or 'date'
        base_class = Spontaneous::FieldTypes[type || name]
        if block_given?
          @field_class = Class.new(base_class, &Proc.new)
          @field_class.meta.send(:define_method, :name) do
            base_class.name
          end
        else
          @field_class = base_class
        end

        @field_class.prototype = self
        parse_options(options)
      end

      def title(new_title=nil)
        self.title = new_title if new_title
        @title || @options[:title] || default_title
      end

      def title=(new_title)
        @title = new_title
      end

      def default_title
        @name.to_s.titleize
      end

      def parse_options(options)
        @options = {
          :default_value => '',
          :comment => false
        }.merge(options)
      end

      def field_class
        @field_class
      end

      def default_value
        @options[:default_value]
      end

      def comment
        @options[:comment]
      end

      def to_field(values=nil)
        from_db = !values.nil?
        values ||= {
          :name => name,
          :unprocessed_value => default_value
        }
        self.field_class.new(values, from_db)
      end

      def to_hash
        {
          :name => name.to_s,
          :type => field_class.json_name,
          :title => title,
          :comment => comment || ""
        }
      end
    end
  end
end
