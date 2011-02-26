require 'active_support/all' # Hash#to_json is unfortunately tightly coupled to a lot of other AS code.
require 'mustache_wax/mustache_rails'

class MustacheWax
  
  if defined?(Rails::Railtie)
    class Railtie < Rails::Railtie
      initializer 'mustache_wax.initialize' do |app|
        MustacheWax.generate_templates

        require 'mustache_rails'
        # Generator
        Rails.application.config.generators.template_engine :mustache
        
        if Rails.env.development?
          class MustacheWax::Middleware
            def initialize(app)
              @app=app
              @newest = Time.now
            end 
     
            def call(env)
              mtimes = MustacheWax.template_files.map do |f|
                File.mtime(f)
              end 
              
              if (newest = mtimes.max) > @newest
                MustacheWax.generate_templates
                @newest = newest
              end 
     
              @app.call(env)
            end 
          end 
     
          app.config.middleware.use MustacheWax::Middleware
        end 
        
      end 
    end
    
  end 
  
  def self.template_files
    Dir[File.join(%w(app views), '**', '*.html.mustache')]
  end 
  
  def self.generate_templates
    templates = {}
    template_files.each do |template_file|
      template_name = template_file.gsub(/^.*app\/views\//, '').gsub(/\.html\.mustache$/, '')
      template = File.read(template_file)
      templates[template_name] = template
    end

    template_script = %(window.MustacheTemplates = #{templates.to_json};)

    base = defined?(Rails.root) ? Rails.root : '.'
    File.open("#{base}/public/javascripts/mustache_templates.js", 'w') do |f|
      f.write template_script
    end
  end
end
