# encoding: UTF-8


module Spontaneous::Plugins::Application
  module State

    def self.configure(base)
    end

    module ClassMethods

      def init(options={})
        # return false if loaded?
        self.environment = (options.delete(:environment) || ENV["SPOT_ENV"] || :development)
        self.mode = options.delete(:mode) || ENV["SPOT_MODE"] || :back
        Spontaneous::Logger.setup(:log_level => options[:log_level], :logfile => options[:logfile], :cli => options[:cli])
        Spontaneous.instance = Spontaneous::Site.instantiate(root, environment, mode)
        Spontaneous.instance.initialize!
        Spontaneous.schema.validate! if self.mode == :console
        Thread.current[:spontaneous_loaded] = true
      end

      def loaded?
        Thread.current[:spontaneous_loaded]
      end


      def config
        Spontaneous::Site.instance.config
      end

      def db_settings
        YAML.load_file(root /  "config/database.yml")[environment]
      end

      def database
        Spontaneous::Site.instance.database
      end

      def database=(database)
        Spontaneous::Site.instance.database = database
      end

      def mode=(mode)
        @mode = mode.to_sym
      end

      def mode
        @mode
      end

      def front?
        mode == :front
      end

      def back?
        mode == :back
      end

      def environment=(env)
        @environment = env.to_sym rescue environment
      end

      alias_method :env=, :environment=

      def environment
        @environment ||= (ENV["SPOT_ENV"] || :development).to_sym
      end

      alias_method :env, :environment

      def development?
        environment == :development
      end

      def production?
        environment == :production
      end

      def test?
        environment == :test
      end
    end # ClassMethods
  end # State
end

