# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :signing
Hoe.plugin :deveiate
Hoe.plugin :mercurial

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec( 'foreman-export-daemontools' ) do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'foreman', '~> 0.45'
	self.dependency 'hoe-deveiate',    '~> 0.1', :developer

	self.spec_extras[:licenses] = ["BSD"]
	self.spec_extras[:rdoc_options] = ['-f', 'fivefish', '-t', 'Foreman Daemontools Exporter']
	self.require_ruby_version( '>=1.9.2' )
	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.check_history_on_release = true if self.respond_to?( :check_history_on_release= )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

# Ensure the specs pass before checking in
task 'hg:precheckin' => [ :check_history, :check_manifest, :spec ]

