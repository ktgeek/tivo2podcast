source 'https://rubygems.org'

ruby '~>2.4'

gem 'activerecord', '~>4.2'
# I really want to get an updated dnssd, because it has a SEGV fix
# I've been running into. However, there's no gemspec in the
# repository. This is an investigation for later.
#gem 'dnssd', '~>3.0'
gem 'dnssd', git: 'https://github.com/ktgeek/dnssd.git', ref: '08a95da894114caa3494a5313654ec8c7ad7c8e3'
gem 'ffi', '~>1.9'
gem 'httpclient', '~>2.8'
gem 'sqlite3', '~>1.3'
gem 'ansi', '~>1.5'
gem 'rest-client', '~>1.8'
gem 'facets', '~>3.0'
gem 'pastel'
gem 'tty-screen'
gem 'tty-prompt', git: 'https://github.com/piotrmurach/tty-prompt.git', ref: '0aee562676be7477519a21a1eb05cc5638c985e8'
gem 'tty-spinner'
gem 'tty-progressbar'
gem 'tty-table'

group :development do
  gem 'byebug'
end

group :test do
  gem 'rspec'
end
