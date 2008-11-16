class Issue < ActiveRecord::Base
  has_magic_columns :through => :issue
end