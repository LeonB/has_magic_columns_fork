require 'test/test_helper'

class HasMagicColumnsTest < Test::Unit::TestCase
  def setup
    setup_db
    @bob = Person.create(:email => "bob@example.com")
  end

  def teardown
    teardown_db
  end

  # Replace this with your real tests.
  def test_magic_column_should_add_read_method
    @bob.magic_columns << MagicColumn.create(:name => "first_name")
    @bob.first_name #method gets generated the first time it is called :S
    assert @bob.respond_to?(:first_name)
  end

  def test_magic_column_should_add_write_method
    @bob.magic_columns << MagicColumn.create(:name => "first_name")
    @bob.first_name
    assert @bob.respond_to?(:first_name=)
  end

  def test_magic_column_should_be_saved
    @bob.magic_columns << MagicColumn.create(:name => "last_name")
    @bob.last_name = 'Doe'
    @bob.save

    # Find @bob and inspect him
    @bob = Person.find_by_email('bob@example.com')
    assert @bob.last_name == 'Doe'
  end

  def test_datatype_should_be_remembered
    @bob.magic_columns << MagicColumn.create(:name => "birthday", :datatype => "date")
    @bob.birthday = Date.today
    @bob.save

    # Find @bob and inspect him
    @bob = Person.find_by_email('bob@example.com')
    assert @bob.birthday.is_a?(Date)
  end

  def test_columns_for_should_create_method
    @project = Project.new
    assert @project.respond_to?(:magic_issue_columns)
  end

  def test_columns_for_should_not_create_magic_columns_method
    @project = Project.new
    assert !@project.respond_to?(:magic_columns)
  end

  def test_columns_through_should_create_magic_columns_method
    @issue = Issue.new
    assert @issue.respond_to?(:magic_columns)
  end
end
