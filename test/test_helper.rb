require 'test/unit'
require 'rubygems'
require 'active_record'
require 'lib/has/magic/columns.rb' #why?
require 'lib/generators/has_magic_columns_tables/templates/migration.rb'
Dir.glob(File.join(File.dirname(__FILE__), '/../lib/*.rb')).each {|f| require f }

$:.unshift File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/../init'

#Setup the connection
#ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => "test.sqlite3")
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

require 'test/person'
require 'test/issue'
require 'test/project'

class Test::Unit::TestCase
  def assert_queries(num = 1)
    $query_count = 0
    yield
  ensure
    assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
end

def setup_db
  # AR keeps printing annoying schema statements
  old_stdout = $stdout
  $stdout = StringIO.new

  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :people do |t|
      t.column :description, :string, :default => 'annoying'
      t.column :email, :string, :null => false
    end

    create_table :projects do |t|
      t.column :name, :string
    end

    create_table :issues do |t|
      t.column :name, :string
    end
  end

  # Run the migrations
  AddHasMagicColumnsTables.migrate(:up)

  $stdout = old_stdout
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end