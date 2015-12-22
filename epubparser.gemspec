$:.push File.expand_path("../lib", __FILE__)

# Maintain your s.add_dependency "s version:
require "epubparser/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "epubparser"
  s.version     = Epubparser::VERSION
  s.authors     = ["Jorge"]
  s.email       = ["jorge@codeplace.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Epubparser."
  s.description = "TODO: Description of Epubparser."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.5"

  s.add_dependency "jquery-rails"
  s.add_dependency "jquery-fileupload-rails"

  s.add_dependency  "aws-sdk"
  s.add_dependency  "s3"
  s.add_dependency  "paperclip"

  s.add_development_dependency "sqlite3"
end
