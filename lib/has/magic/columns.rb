# Has Magic Columns
#
# Copyright (c) 2007 Brandon Keene <bkeene AT gmail DOT com>
# see README for license
module Has #:nodoc:
  module Magic #:nodoc:
    # Extends @attributes on a per model basis.  Column definitions exist through the built-in
    # :magic_columns association.
    #
    # class Model < ActiveRecord::Base
    #   has_magic_columns
    # end
    #
    # @model = Model.create(...) #=> @model.id == 1
    # @model.magic_columns << MagicColumn.create(:name => "first_name")
    # @model.first_name = "Brandon"
    # @model.save
    # @model = Model.find(1)
    # @model.first_name #=> "Brandon"
    #
    module Columns
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def has_magic_columns(options = {})
          unless magical?
            # Associations
            has_many :magic_attribute_relationships, :as => :owner, :dependent => :destroy
            has_many :magic_attributes, :through => :magic_attribute_relationships, :dependent => :destroy
            
            # Eager loading - EXPERIMENTAL!
            if options[:eager]
              class_eval do
                def after_initialize
                  initialize_magic_columns
                end
              end
            end

            if options[:through]
              through = options[:through].to_s.downcase.singularize
              self_class = self.to_s

              define_method "magic_columns_with_#{through}_columns" do
                if self.send(through)
                  self.send(through).magic_auto_columns || []
                end
                #alias_method_chain :magic_columns, "#{through}_columns"
              end
            end

            if options[:for]
              for_class = options[:for].to_s.downcase.singularize
              self_class = self.to_s

              has_and_belongs_to_many "magic_#{for_class}_columns",
                :class_name => 'MagicColumn',
                :join_table => "#{self_class.downcase}_magic_#{for_class}_columns",
                :select => 'magic_columns.*'
              return
            end

            # Inheritence
            cattr_accessor :inherited_from
            unless self.inherited_from = options[:inherit]
              has_many :magic_column_relationships, :as => :owner, :dependent => :destroy
              has_many :magic_columns, :through => :magic_column_relationships, :dependent => :destroy
            else
              class_eval do
                def inherited_magic_columns
                  raise "Cannot inherit MagicColumns from a non-existant association: #{@inherited_from}" unless self.class.method_defined?(inherited_from)# and self.send(inherited_from)
                  self.send(inherited_from).magic_columns
                end
              end
              alias_method :magic_columns, :inherited_magic_columns unless method_defined? :magic_columns
            end
            
            # Hook into Base
            class_eval do
              alias_method :reload_without_magic, :reload
              alias_method :create_or_update_without_magic, :create_or_update
              alias_method :read_attribute_without_magic, :read_attribute
            end
          end
          include InstanceMethods
          
          # Add Magic to Base
          alias_method :reload, :reload_with_magic
          alias_method :read_attribute, :read_attribute_with_magic
          alias_method :create_or_update, :create_or_update_with_magic
        end

        def magical?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        # Reinitialize MagicColumns and MagicAttributes when Model is reloaded
        def reload_with_magic
          initialize_magic_columns
          reload_without_magic
        end

        def magic_column_names
          magic_columns.map(&:name)
        end

        private
        
        # Save MagicAttributes from @attributes
        def create_or_update_with_magic
          if result = create_or_update_without_magic
            magic_columns.each do |column|
              value = @attributes[column.name]
              existing = find_magic_attribute_by_column(column)
              
              unless column.datatype == 'check_box_multiple'
                (attr = existing.first) ? 
                  update_magic_attribute(attr, value) : 
                  create_magic_attribute(column, value)
              else
                #TODO - make this more efficient
                value = [value] unless value.is_a? Array
                existing.map(&:destroy) if existing
                value.collect {|v| create_magic_attribute(column, v)}
              end
            end
          end
          result
        end
        
        # Load (lazily) MagicAttributes or fall back
        def method_missing(method_id, *args)
          super(method_id, *args)
        rescue NoMethodError
          method_name = method_id.to_s
          attr_names = magic_columns.map(&:name)
          initialize_magic_columns and retry if attr_names.include?(method_name) or 
            (md = /[\?|\=]/.match(method_name) and 
              attr_names.include?(md.pre_match))
          super(method_id, *args)
        end
        
        # Load the MagicAttribute(s) associated with attr_name and cast them to proper type.
        def read_attribute_with_magic(attr_name)
          return read_attribute_without_magic(attr_name) if column_for_attribute(attr_name) # filter for regular columns
          attr_name = attr_name.to_s
          
          if !(value = @attributes[attr_name]).nil?
            if column = find_magic_column_by_name(attr_name)
              if value.is_a? Array
                value.map {|v| column.type_cast(v)}
              else
                column.type_cast(value)
              end
            else
              value
            end
          else
            nil
          end
        end
        
        # Lookup all MagicAttributes and setup @attributes
        def initialize_magic_columns
          magic_columns.each do |column| 
            attribute = find_magic_attribute_by_column(column)
            name = column.name
            
            # Validation
            self.class.validates_presence_of(name) if column.is_required?
            
            # Write attribute
            unless column.datatype == 'check_box_multiple'
              (attr = attribute.first) ?
                write_attribute(name, attr.to_s) :
                write_attribute(name, column.default)
            else
              write_attribute(name, attribute.map(&:to_s))
            end
          end
        end
        
        def find_magic_attribute_by_column(column)
          #magic_attributes.find(:all, :conditions => ["magic_column_id = ?", column.id])
          magic_attributes.to_a.find_all {|attr| attr.magic_column_id == column.id}
        end
        
        def find_magic_column_by_name(attr_name)
          #magic_columns.find(:first, :conditions => ["name = ?", attr_name])
          magic_columns.to_a.find {|column| column.name == attr_name}
        end
        
        def create_magic_attribute(magic_column, value)
          magic_attributes << MagicAttribute.create(:magic_column => magic_column, :value => value)
        end
        
        def update_magic_attribute(magic_attribute, value)
          magic_attribute.update_attributes(:value => value)
        end
        
      end 
    end
  end
end