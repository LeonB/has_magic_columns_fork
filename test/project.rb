class Project < ActiveRecord::Base
  has_magic_columns :for => :issue
end