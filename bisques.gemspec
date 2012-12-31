$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

include_files = ["README*", "LICENSE", "Rakefile", "init.rb", "{lib}/**/*"].map do |glob|
  Dir[glob]
end.flatten
exclude_files = ["**/*.rbc"].map do |glob|
  Dir[glob]
end.flatten

spec = Gem::Specification.new do |s|
  s.name              = "bisques"
  s.version           = "1.0.1"
  s.author            = "Jeremy Wells"
  s.email             = "jemmyw@gmail.com"
  s.homepage          = "https://github.com/jemmyw/bisques"
  s.description       = "AWS SQS client"
  s.platform          = Gem::Platform::RUBY
  s.summary           = "AWS SQS client"
  s.files             = include_files - exclude_files
  s.require_path      = "lib"
  s.test_files        = Dir["test/**/test_*.rb"]
  s.extra_rdoc_files  = Dir["README*"]
  s.rdoc_options << '--line-numbers' << '--inline-source'
  s.add_dependency 'httpclient'
  s.add_dependency 'addressable'
  s.add_dependency 'nokogiri'
  s.add_dependency 'json'
  s.add_development_dependency 'rspec'
end

