$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "shop_model_concerns/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "shop_model_concerns"
  s.version     = ShopModelConcerns::VERSION
  s.authors     = ["Brian Weiner"]
  s.email       = ["brian.weiner@dc.gov"]
  s.homepage    = "https://github.com/dchbx"
  s.summary     = "Consolidate SHOP models into a common concern repository"
  s.description = "Contains models critical and specific for SHOP behavior (e.g EmployerProfile, Organization, et al)"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 4.2.3"
  s.add_dependency 'mongo', '2.1.2'
  s.add_dependency 'mongoid', '5.0.1'
  s.add_dependency 'mongoid_userstamp'
  s.add_dependency "mongoid-autoinc"
  s.add_dependency 'money-rails', '~> 1.3.0'
  s.add_dependency "mongoid-enum"
end
