require "fileutils"
require "shellwords"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repo_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("springer-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/troyizzle/springer.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{springer/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def set_application_name
  environment "config.application_name = Rails.application.class.module_parent_name"
end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def add_tailwind
  run "npm install tailwindcss@npm:@tailwindcss/postcss7-compat @tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9"
  style_css = 'app/javascript/stylesheets/application.scss'

  styles = <<-STYLE
    @import "tailwindcss/base";
    @import "tailwindcss/components";
    @import "tailwindcss/utilities";
  STYLE

  create_file(style_css, styles)

  # require stylesheet in Application.js
  append_to_file 'app/javascript/packs/application.js' do
    'require("stylesheets/application.scss")'
  end

  # add pack tag to application.html.erb
  content = "<%= stylesheet_pack_tag 'application', 'data-turbolinks-track': 'reload' %>"
  link_tag = <<-TAG
    <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
  TAG
  insert_into_file('app/views/layouts/application.html.erb',
                   "\n" + content,
                   after: link_tag)

  # require tailwindcss in postCSS config
  insert_into_file('postcss.config.js',
                   "\n" + 'require("tailwindcss"),',
                   after: "plugins: [")
end

def add_form_builder
  insert_into_file('app/controllers/application_controller.rb',
                   "\n" + 'default_form_builder ApplicationFormBuilder',
                   after: 'class ApplicationController < ActionController::Base'
                  )

  form = <<-FORM
  # frozen_string_literal: true

  class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  end
  FORM
  create_file('app/helpers/application_form_builder.rb', form)
end

def add_gems
  gem 'devise', github: 'heartcombo/devise'
  gem 'hotwire-rails'
  gem 'omniauth', '>=1.0.0'
  gem 'pundit'
  gem "view_component", require: "view_component/engine"
  gem 'whenever', require: false

  gem_group :development, :test do
    gem 'rspec-rails'
  end
end

def add_users
  # Install Devise
  generate 'devise:install'

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
  route "root to: 'home#index'"

  generate :devise, 'User',
    'admin:boolean',
    'username:string'

  # Add omniauthable on model
  insert_into_file "app/models/user.rb",
    ", :omniauthable, omniauth_providers: %i[facebook twitter github]",
    after: " :validatable"

  in_root do
    migration = Dir.glob("db/migrate/*").max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
    gsub_file migration, /:username/, ":username, default: '', null: false"
  end

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb",
      / # config.secret_key = .+/,
      " config.secret_key = Rails.application.credentials.secret_key_base"
  end
end

def add_users_profile
  generate "model Profile first_name last_name users:references"
end

def add_home_controller
  generate "controller home index"
end

def add_authorization
  generate 'pundit:install'
end

def add_multiple_authentication
  insert_into_file "config/routes.rb",
    ', controllers: { omniauth_callbacks: "users/omniauth_callbacks" }',
    after: "  devise_for :users"


    template = """
    env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
    %i{ facebook twitter github }.each do |provider|
      if options = env_creds[provider]
        config.omniauth provider, options[:app_id], options[:app_secret], options.fetch(:options, {})
      end
    end
    """.strip

    insert_into_file "config/initializers/devise.rb", "  " + template + "\n\n",
          before: "  # ==> Warden configuration"
end

def add_whenever
  run "wheneverize ."
end

def stop_spring
  run "spring stop"
end

def remove_test_directory
  remove_file("test")
end

# Main setup
add_template_repo_to_source_path

add_gems

after_bundle do
  set_application_name
  stop_spring
  add_home_controller
  add_users
  add_users_profile
  add_authorization
  add_multiple_authentication
  add_form_builder
  add_whenever

  rails_command "active_storage:install"
  rails_command "hotwire:install"
  rails_command "generate rspec:install"
  remove_test_directory

  add_tailwind

  # Commit everything
  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    # git commit will fail if user.email is not configured
    begin
      git commit: %( -m 'Initial commit' )
    rescue StandardError => e
      puts e.message
    end
  end

  say "App successfully created!", :blue
end
