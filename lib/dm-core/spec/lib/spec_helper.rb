module DataMapper
  module Spec

    # global model cleanup
    def self.cleanup_models
      descendants = DataMapper::Model.descendants.to_a
      while model = descendants.shift
        descendants.concat(model.descendants.to_a - [ model ])

        unless model.name.to_s[0] == ?#
          parts         = model.name.split('::')
          constant_name = parts.pop.to_sym
          base          = parts.empty? ? Object : Object.full_const_get(parts.join('::'))

          base.class_eval { remove_const(constant_name) if const_defined?(constant_name) }
        end

        remove_ivars(model)
        model.instance_methods(false).each { |method| model.send(:undef_method, method) }

        DataMapper::Model.descendants.delete(model)
      end
    end

    def self.remove_ivars(object, instance_variables = object.instance_variables)
      seen  = {}
      stack = instance_variables.map { |var| [ object, var ] }

      while node = stack.pop
        object, ivar = node

        # skip "global" and non-DM objects
        next if object.kind_of?(DataMapper::Logger)               ||
                object.kind_of?(DataMapper::Model::DescendantSet) ||
                object.class.name[0, 13] == 'DataObjects::'

        # skip classes and modules in the DataMapper namespace
        next if object.kind_of?(Module) &&
                !object.name.nil?       &&
                object.name[0, 12] == 'DataMapper::'

        # skip when the ivar is no longer defined in the object
        next unless object.instance_variable_defined?(ivar)

        value = object.instance_variable_get(ivar)
        object.__send__(:remove_instance_variable, ivar) unless object.frozen?

        # skip when the value was seen
        next if seen.key?(value.object_id)
        seen[value.object_id] = true

        stack.concat value.instance_variables.map { |ivar| [ value, ivar ] }
      end
    end

  end
end
