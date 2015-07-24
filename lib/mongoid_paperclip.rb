# encoding: utf-8

begin
  require "paperclip"
rescue LoadError
  puts "Mongoid::Paperclip requires that you install the Paperclip gem."
  exit
end

##
# the id of mongoid is not integer, correct the id_partitioin.
Paperclip.interpolates :id_partition do |attachment, style|
  attachment.instance.id.to_s.scan(/.{4}/).join("/")
end

##
# mongoid criteria uses a different syntax.
module Paperclip
  module Helpers
    def each_instance_with_attachment(klass, name)
      class_for(klass).unscoped.where("#{name}_file_name".to_sym.ne => nil).each do |instance|
        yield(instance)
      end
    end
  end
end

##
# The Mongoid::Paperclip extension
# Makes Paperclip play nice with the Mongoid ODM
#
# Example:
#
#  class User
#    include Mongoid::Document
#    include Mongoid::Paperclip
#
#    has_mongoid_attached_file :avatar
#  end
#
# The above example is all you need to do. This will load the Paperclip library into the User model
# and add the "has_mongoid_attached_file" class method. Provide this method with the same values as you would
# when using "vanilla Paperclip". The first parameter is a symbol [:field] and the second parameter is a hash of options [options = {}].
#
# Unlike Paperclip for ActiveRecord, since MongoDB does not use "schema" or "migrations", Mongoid::Paperclip automatically adds the neccesary "fields"
# to your Model (MongoDB collection) when you invoke the "#has_mongoid_attached_file" method. When you invoke "has_mongoid_attached_file :avatar" it will
# automatially add the following fields:
#
#  field :avatar_file_name,    :type => String
#  field :avatar_content_type, :type => String
#  field :avatar_file_size,    :type => Integer
#  field :avatar_updated_at,   :type => DateTime
#  field :avatar_fingerprint,  :type => String
#
module Mongoid
  module Paperclip

    ##
    # Extends the model with the defined Class methods
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
    
      ##
      # Adds after_commit
      def after_commit(*args, &block)
        options = args.pop if args.last.is_a? Hash
        if options
          case options[:on]
          when :create
            after_create(*args, &block)
          when :update
            after_update(*args, &block)
          when :destroy
            after_destroy(*args, &block)
          else
            after_save(*args, &block)
          end
        else
          after_save(*args, &block)
        end
      end

      def validates_presence_of_attached_file(field)
        validates_presence_of("#{field}_file_name")
        validates_presence_of("#{field}_content_type")
        validates_presence_of("#{field}_file_size")
      end
      ##
      # Adds Mongoid::Paperclip's "#has_mongoid_attached_file" class method to the model
      # which includes Paperclip and Paperclip::Glue in to the model. Additionally
      # it'll also add the required fields for Paperclip since MongoDB is schemaless and doesn't
      # have migrations.
      def has_mongoid_attached_file(field, options = {})

        ##
        # Include Paperclip and Paperclip::Glue for compatibility
        unless self.ancestors.include?(::Paperclip)
          include ::Paperclip
          include ::Paperclip::Glue
        end

        ##
        # Invoke Paperclip's #has_attached_file method and passes in the
        # arguments specified by the user that invoked Mongoid::Paperclip#has_mongoid_attached_file
        has_attached_file(field, options)

        ##
        # Define the necessary collection fields in Mongoid for Paperclip
        field(:"#{field}_file_name",    :type => String)
        field(:"#{field}_content_type", :type => String)
        field(:"#{field}_file_size",    :type => Integer)
        field(:"#{field}_updated_at",   :type => DateTime)
        field(:"#{field}_fingerprint",  :type => String)
      end

      ##
      # This method is deprecated
      def has_attached_file(field, options = {})
      end
    end

  end
end
