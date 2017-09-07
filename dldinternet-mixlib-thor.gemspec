# -*- encoding: utf-8 -*-

require File.expand_path('../lib/dldinternet/thor/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'dldinternet-mixlib-thor'
  gem.version       = Dldinternet::Mixlib::Thor::VERSION
  gem.summary       = %q{Thor no_commands reuse}
  gem.description   = %q{Thor no_commands reuse}
  gem.license       = 'Apachev2'
  gem.authors       = ['Christo De Lange']
  gem.email         = 'rubygems@dldinternet.com'
  gem.homepage      = 'https://rubygems.org/gems/dldinternet-mixlib-thor'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 			'thor', '~> 0.19', '>= 0'
  gem.add_dependency              'awesome_print'                       #, '~> 1.2'
  gem.add_dependency              'paint-shortcuts', '>= 0'
  gem.add_dependency              'inifile'                             #, '~> '
  gem.add_dependency              'hashie'                             #, '~> '
  gem.add_dependency              'command_line_reporter', '~> 3.3', '>= 3.3.6'
  gem.add_dependency              'dldinternet-mixlib-logging', '>= 0.7.0'
  gem.add_dependency              'config-factory'                      #, '~> '

  gem.add_development_dependency 'bundler', '~> 1.0'
  gem.add_development_dependency 'rake', '~> 10'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'
end
