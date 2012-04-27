# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'helpers'

require 'pathname'
require 'rspec'
require 'tmpdir'

require 'foreman/engine'
require 'foreman/export/daemontools'


#####################################################################
###	C O N T E X T S
#####################################################################
RSpec.configure do |config|
	config.treat_symbols_as_metadata_keys_with_true_values = true
	config.order = 'rand'
	config.mock_with( :rspec )
end


describe Foreman::Export::Daemontools do

	let( :servicedir ) { Pathname(Dir.tmpdir) + 'service' }
	let( :datadir )    { Pathname(__FILE__).dirname.parent.parent + 'data' }
	let( :procfile )   { datadir + 'Procfile' }
	let( :engine )     { Foreman::Engine.new(procfile) }
	let( :options )    {{
		:app_root    => datadir,
		:app         => 'test',
		:env         => datadir + '.env',
		:concurrency => 'cms=2,api=0,mongrel2=1',
		:user        => 'www',
	}}

	subject { described_class.new(servicedir, engine, options) }

	before( :each ) do
		logdevice = ArrayLogger.new
		subject.logger = Logger.new( logdevice )
		subject.logger.formatter = HtmlFormatter.new( subject.logger )
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = logdevice.array
		end
	end

	after( :all ) do
		servicedir.rmtree
	end


	it "exports to the filesystem" do
		subject.export
		servicedir.should exist()

		%w[ test-cms-1 test-cms-2 test-mongrel2 ].each do |procname|
			procdir = servicedir + procname

			runfile = procdir + 'run'
			runfile.should exist()
			runfile.should be_executable()
			runfile.read.should =~ %r{exec setuidgid www envdir \./env}

			logdir = procdir + 'log'
			logdir.should be_directory()
			logrun = logdir + 'run'
			logrun.should be_executable()
			logrun.read.should =~ /exec setuidgid www multilog t/

			envdir = procdir + 'env'
			envdir.should be_directory()
			( envdir + 'HOMEDIR' ).read.should == "/Users/ged\n"
			( envdir + 'MONGREL2_HOME' ).read.should == "/var/run/mongrel2\n"

		end
	end

end

