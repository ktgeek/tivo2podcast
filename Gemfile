source 'https://rubygems.org'

ruby '~>2.3.1'

gem 'activerecord', '~>4.2'
# I really want to get an updated dnssd, because it has a SEGV fix
# I've been running into. However, there's no gemspec in the
# repository. This is an investigation for later.
gem 'dnssd', '~>3.0'
#gem 'dnssd', git: 'https://github.com/tenderlove/dnssd.git', ref: '5365d38d8bd97d01ce10ee9e178ec610606cc308'
gem 'ffi', '~>1.9'
gem 'httpclient', '~>2.6'
gem 'sqlite3', '~>1.3'
gem 'highline', '~>1.7'
gem 'ansi', '~>1.5'
gem 'rest-client', '~>1.8'
gem 'facets', '~>3.0'
gem 'tty-progressbar'
gem 'pastel'
gem 'tty-screen'
gem 'tty-prompt', git: 'https://github.com/ktgeek/tty-prompt.git', ref: '8dc6943191f440bba7d86dcac5ce445a80c64530'
gem 'tty-spinner'

group :development do
  gem 'byebug'
end

group :test do
  gem 'rspec'
end
