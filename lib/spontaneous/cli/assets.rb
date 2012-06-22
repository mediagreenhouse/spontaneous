module Spontaneous
  module Cli
    class Assets < ::Spontaneous::Cli::Thor
      Spontaneous = ::Spontaneous
      namespace :assets
      default_task :compile


      # class Up < SyncTask
      #   desc "Syncs up"
      # end

      desc "#{namespace}:compile", "Compiles assets for the Spontaneous UI"
      method_option :destination, :type => :string, :aliases => "-d", :required => true, :desc => "Compile assets into DESTINATION"
      def compile
        prepare(:compile)
        # options[:mode] = :console
        # Find path to install of Spontaneous using bundler and then
        # use this path as params to compiler
        spec = Bundler.load.specs.find{|s| s.name == "spontaneous" }
        p spec.full_gem_path

        compiler = Spontaneous::Asset::AppCompiler.new(spec.full_gem_path, options.destination)
        compiler.compile
      end
    end
  end
end

