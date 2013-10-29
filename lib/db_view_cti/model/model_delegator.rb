require 'delegate'

module DBViewCTI
  module Model
    
    class ModelDelegator < SimpleDelegator
      
      attr_reader :cti_target_class

      def initialize(object, target_class)
        @cti_object = object
        @cti_converted_object = object.convert_to(target_class)
        if !@cti_converted_object
          @cti_converted_object = object.becomes(target_class.constantize)
          @cti_is_new = true
        else
          disable_validations
        end
        @cti_target_class = target_class
        super( @cti_converted_object )
      end
      
      def cti_is_new?
        @cti_is_new
      end
      
      def save(*args, &block)
        return super unless cti_is_new?
        # special case for new objects, we need som hackish id-juggling
        old_id = @cti_object.id
        new_id = @cti_object.convert_to( @cti_target_class ).id
        # since @cti_converted_object was created using 'becomes', @cti_object.id changes
        # as well in the following statement. So we saved it in old_id and restore it after the
        # call to save (i.e. super)
        @cti_object.reload  # only needed in rails 4
        self.id = new_id
        self.created_at = @cti_object.created_at  # only needed in rails 4
        self.updated_at = @cti_object.updated_at  # only needed in rails 4
        retval = !!super
        @cti_is_new = false
        @cti_object.id = old_id
        @cti_converted_object = @cti_object.convert_to( @cti_target_class )
        disable_validations
        __setobj__(@cti_converted_object)
        retval
      end
      
      private
      
        module DisableValidator
          def validate_each(record, *args)
            return if record.respond_to?(:cti_disable_validations) && record.cti_disable_validations
            super
          end
          
          if Rails::VERSION::MAJOR == 3
            def validate(record, *args)
              return if record.respond_to?(:cti_disable_validations) && record.cti_disable_validations
              super
            end
          end
        end
        
        def disable_validations
          @cti_converted_object.cti_disable_validations = true
          @cti_converted_object._validators.values.flatten.each do |validator|
            validator.extend( DisableValidator )
          end
        end
      
    end
    
  end
end
