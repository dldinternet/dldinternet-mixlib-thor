require 'thor'
require 'thor/command'

module DLDInternet
  module Thor
    class DynamicCommand < ::Thor::DynamicCommand
      # By default, a command invokes a method in the thor class. You can change this
      # implementation to create custom commands.
      def run(instance, args = [])
        arity = nil

        if private_method?(instance)
          instance.class.handle_no_command_error(name)
        elsif public_method?(instance)
          arity = instance.method(name).arity
          instance.__send__(name, *args)
        elsif local_method?(instance, :method_missing)
          instance.__send__(:method_missing, name.to_sym, *args)
        else
          if instance.class.instance_methods.include?(:handle_no_command_error)
            instance.handle_no_command_error(name)
          else
            instance.class.handle_no_command_error(name)
          end
        end
      rescue ArgumentError => e
        handle_argument_error?(instance, e, caller) ? instance.class.handle_argument_error(self, e, args, arity) : (raise e)
      rescue ::Thor::NoMethodError => e
        handle_no_method_error?(instance, e, caller) ? instance.class.handle_no_command_error(name) : (raise e)
      end

    end
  end
end