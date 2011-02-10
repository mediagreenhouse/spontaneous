# encoding: UTF-8

require 'test_helper'


class PermissionsTest < Test::Unit::TestCase

  context "Permissions" do
    should "be able to generate random strings of any length" do
      (2..256).each do |length|
        s1 = Permissions.random_string(length)
        s2 = Permissions.random_string(length)
        s1.length.should == length
        s2.length.should == length
        s1.should_not == s2
      end
    end
  end
  context "Levels" do
    setup do
      Permissions::UserLevel
      @pwd = Dir.pwd
      Dir.chdir(File.expand_path('../../fixtures/permissions', __FILE__))
      File.exists?('config/user_levels.yml').should be_true
    end
    teardown do
      Dir.chdir(@pwd)
    end
    should "always have a level of :none/0" do
      Permissions::UserLevel.none.should == Permissions::UserLevel::None
      Permissions::UserLevel[:none].should == Permissions::UserLevel.none
      Permissions::UserLevel['none'].should == Permissions::UserLevel.none
    end
    should "load from the config/user_levels.yml file" do
      Permissions::UserLevel[:editor].should == 1
      Permissions::UserLevel['editor'].should == 1
      Permissions::UserLevel['admin'].should == 10
      Permissions::UserLevel['designer'].should == 50
    end
    should "provide a sorted list of all levels" do
      Permissions::UserLevel.all.should == [:none, :editor, :admin, :designer, :root]
    end
    should "provide a list of all levels <= provided level" do
      Permissions::UserLevel.all(:editor).should == [:none, :editor]
      Permissions::UserLevel.all(:designer).should == [:none, :editor, :admin, :designer]
    end

    should "have a root level" do
      Permissions::UserLevel.root.should == Permissions::UserLevel::Root
    end

    should "have a root level that is always greater than other levels" do
      Permissions::UserLevel.root.should > Permissions::UserLevel['designer']
      Permissions::UserLevel.root.should >= Permissions::UserLevel['designer']
      Permissions::UserLevel.root.should > Permissions::UserLevel::Root
      Permissions::UserLevel.root.should >= Permissions::UserLevel::Root
      Permissions::UserLevel[:root].should == Permissions::UserLevel::Root
    end
    # should "map id to name"
    should "work with > operator" do
      Permissions::UserLevel[:admin].should > Permissions::UserLevel[:editor]
      Permissions::UserLevel[:editor].should > Permissions::UserLevel[:none]
    end
    should "work with >= operator" do
      Permissions::UserLevel[:admin].should >= Permissions::UserLevel[:admin]
      Permissions::UserLevel[:editor].should >= Permissions::UserLevel[:editor]
    end

    should "return a minimum level > none" do
      Permissions::UserLevel.minimum.should == Permissions::UserLevel.editor
    end
    should "have a valid string representation" do
      Permissions::UserLevel[:editor].to_s.should == 'editor'
      Permissions::UserLevel[:none].to_s.should == 'none'
      Permissions::UserLevel[:root].to_s.should == 'root'
      Permissions::UserLevel[:designer].to_s.should == 'designer'
    end
  end

  context "Users" do
    setup do
      @now = Time.now
      Time.stubs(:now).returns(@now)
      @valid = {
        :name => "A Person",
        :email => "person@example.org",
        :login => "person",
        :password => "xxxxxx",
        :password_confirmation => "xxxxxx"
      }
    end

    teardown do
      Permissions::User.delete
      Permissions::AccessKey.delete
    end

    should "be creatable with valid params" do
      user = Permissions::User.new(@valid)
      user.save.should be_instance_of(Permissions::User)
      user.valid?.should be_true
    end

    should "validate name" do
      user = Permissions::User.new(@valid.merge(:name => ""))
      user.save.should be_nil
      user.valid?.should be_false
      user.errors[:name].should_not be_blank
    end

    should "validate presence of email address" do
      user = Permissions::User.new(@valid.merge(:email => ""))
      user.save
      user.valid?.should be_false
      user.errors[:email].should_not be_blank
    end

    should "validate format of email address" do
      user = Permissions::User.new(@valid.merge(:email => "invalid.email.address"))
      user.save
      user.valid?.should be_false
      user.errors[:email].should_not be_blank
    end

    should "validate presence of login" do
      user = Permissions::User.new(@valid.merge(:login => ""))
      user.save
      user.valid?.should be_false
      user.errors[:login].should_not be_blank
    end

    should "validate length of login" do
      user = Permissions::User.new(@valid.merge(:login => "xx"))
      user.save
      user.valid?.should be_false
      user.errors[:login].should_not be_blank
    end

    should "reject duplicate logins" do
      user1 = Permissions::User.create(@valid)
      user2 = Permissions::User.new(@valid)
      user2.save
      user2.valid?.should be_false
      user2.errors[:login].should_not be_blank
    end

    should "require a non-blank password & password_confirmation" do
      user = Permissions::User.new(@valid.merge(:password => "", :password_confirmation => ""))
      user.save
      user.valid?.should be_false
      user.errors[:password].should_not be_blank
    end

    should "require a matching password & password_confirmation" do
      user = Permissions::User.new(@valid.merge(:password => "sdfsddfsdf", :password_confirmation => "sdf"))
      user.save
      user.valid?.should be_false
      user.errors[:password_confirmation].should_not be_blank
    end

    should "require passwords to be at least 6 characters" do
      user = Permissions::User.new(@valid.merge(:password => "12345", :password_confirmation => "12345"))
      user.save
      user.valid?.should be_false
      user.errors[:password].should_not be_blank
    end


    should "have a random salt" do
      user1 = Permissions::User.create(@valid)
      user2 = Permissions::User.create(@valid.merge(:login => "person2"))
      user1.salt.should_not be_blank
      user2.salt.should_not be_blank
      user1.salt.should_not == user2.salt
    end

    context "who are valid" do
      setup do
        @user = Permissions::User.create(@valid)
        @user.reload
      end

      should "have a created_at date" do
        @user.created_at.to_i.should == @now.to_i
      end

      should "have an associated 'invisible' group" do
        @user.group.should be_instance_of(Permissions::AccessGroup)
        @user.group.invisible?.should be_true
        @user.group.level.should == Permissions::UserLevel.minimum
      end

      # the following actually works on the associated silent group
      should "default to a user level of Permissions::UserLevel.minimum" do
        @user.level.should == Permissions::UserLevel.minimum
      end

      should "have a settable user level" do
        @user.update(:level => Permissions::UserLevel[:root])
        @user.reload.level.should == Permissions::UserLevel.root
      end

      should "have a list of groups it belongs to" do
        @user.memberships.should == [@user.group]
      end

      should "be able to login with right login/password combination" do
        key = Permissions::User.authenticate(@user.login, @user.password)
        key.user.id.should == @user.id
        key = Permissions::User.authenticate(@user.login, "wrong password")
        key.should be_nil
      end

      should "have a last login date" do
        @user.last_login_at.should be_nil
        key = Permissions::User.authenticate(@user.login, @user.password)
        @user.reload.last_login_at.to_i.should == @now.to_i
      end

      should "generate a new access key on successful login" do
        @user.access_keys.should be_blank
        key = Permissions::User.authenticate(@user.login, @user.password)
        @user.reload.access_keys.length.should == 1
        @user.access_keys.first.created_at.to_i.should == @now.to_i
        @user.access_keys.first.last_access_at.to_i.should == @now.to_i
      end

      should "be able to belong to more than one group"
      should "be blockable"
      should "have a login count"
      should "have a list of access keys"
      should "be able to remove a specific access key"
    end
  end

  context "access keys" do
    setup do
      @now = Time.now
      Time.stubs(:now).returns(@now)
      @valid = {
        :name => "A Person",
        :email => "person@example.org",
        :login => "person",
        :password => "xxxxxx",
        :password_confirmation => "xxxxxx"
      }
    end
    teardown do
      Permissions::AccessKey.delete
      Permissions::User.delete
    end

    should "have a generated key_id" do
      key1 = Permissions::AccessKey.create
      key1.key_id.length.should == 44
      key2 = Permissions::AccessKey.create
      key2.key_id.length.should == 44
      key1.key_id.should_not == key2.key_id
    end

    should "allow authentication of a user" do
      key1 = Permissions::AccessKey.create
      key2 = Permissions::AccessKey.authenticate(key1.key_id)
      key1.id.should == key2.id
    end

    should "update timestamps when authenticated" do
      user = Permissions::User.create(@valid)
      key1 = Permissions::AccessKey.create(:user_id => user.id)
      Time.stubs(:now).returns(@now + 1000)
      key2 = Permissions::AccessKey.create(:user_id => user.id)
      key3 = Permissions::AccessKey.authenticate(key2.key_id)
      key2.id.should == key3.id
      key2.reload.last_access_at.to_i.should == (@now+1000).to_i
      key2.user.last_access_at.to_i.should == (@now+1000).to_i
    end

    should "be guaranteed unique" do
      Permissions.stubs(:random_string).returns("xxxx")
      key1 = Permissions::AccessKey.create()
      lambda { Permissions::AccessKey.create() }.should raise_error
    end

    should "have a creation date" do
      key1 = Permissions::AccessKey.create
      key1.created_at.to_i.should == @now.to_i
    end
    should "have a source IP address"
    should "retrieve their associated user" do
      user = Permissions::User.create(@valid)
      key1 = Permissions::AccessKey.create(:user_id => user.id)
      key1.reload.user.should == user
    end
    should "be disabled when user blocked" do
      user = Permissions::User.create(@valid)
      key1 = Permissions::AccessKey.create(:user_id => user.id)
      user.update(:disabled => true)
      key3 = Permissions::AccessKey.authenticate(key1.key_id)
      key3.should be_nil
    end
  end



  context "Groups" do
    should "always have a name"
    should "be blockable"
    should "have a list of users"
    should "have an associated user level"
    should "default to a user level of :none/0"
    should "default to applying to the whole site"
  end

end
