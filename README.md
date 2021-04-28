## Getting Started
This was heavily inspired by [Jumpstart](https://github.com/excid3/jumpstart) but incorporated some things I've frequently added.

#### Requirements

You'll need the following installed to run the template successfully:

* Ruby 2.7 or higher
* Rails 6 or higher
* Redis - For ActionCable support
* bundler - `gem install bundler`
* rails - `gem install rails`
* Yarn - `brew install yarn` or [Install Yarn](https://yarnpkg.com/en/docs/install)

#### Creating a new app

```bash
rails new myapp -d postgresql -m https://raw.githubusercontent.com/troyizzle/springer/master/template.rb
```

Or if you have downloaded this repo, you can reference template.rb locally:

```bash
rails new myapp -d postgresql -m template.rb
```

#### Running your app
Make sure to run `rails db:create` and `rails db:migrate`

```bash
rails db:drop
spring stop
cd ..
rm -rf myapp
```

