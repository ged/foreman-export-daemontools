#!/usr/bin/env ruby
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'erb'
require 'logger'
require 'pathname'
require 'foreman/export'
require 'foreman/cli'


# A Foreman exporter for daemontools[http://cr.yp.to/daemontools.html]. This exports
# processes from the Procfile as a hierarchy of directories intended to be run under
# 'supervise'
#
# Some of this code was borrowed from the 'runit' exporter.
class Foreman::Export::Daemontools < Foreman::Export::Base

	# Library version constant
	VERSION = '0.0.1'

	# Version-control revision constant
	REVISION = %q$Revision$

	# The data directory in the project if that exists, otherwise the gem datadir
	DEFAULT_DATADIR = if ENV['FOREMAN_EXPORT_DATADIR']
			Pathname( ENV['FOREMAN_EXPORT_DATADIR'] )
		elsif File.directory?( 'data/foreman-export-daemontools' )
			Pathname( 'data/foreman-export-daemontools' )
		elsif path = Gem.datadir( 'foreman-export-daemontools' )
			Pathname( path )
		else
			raise ScriptError, "can't find the data directory!"
		end

	# Directory to look in for personal templates
	HOME_TEMPLATEDIR = Pathname( "~/.foreman/templates" ).expand_path

	# Pattern used to extract inline env variables from the command
	ENV_VARIABLE_REGEX = /([a-zA-Z_]+[a-zA-Z0-9_]*)=(\S+)/


	##
	# The data directory for the gem
	class << self; attr_accessor :datadir; end
	@datadir = DEFAULT_DATADIR


	### Set up the template root
	def initialize( location, engine, options={} ) # :notnew:
		super
		@logger = Logger.new( $stderr )
		@template_search_path = [ HOME_TEMPLATEDIR, DEFAULT_DATADIR + 'templates' ]
		@template_search_path.unshift( Pathname(options[:template]) ) if options.key?( :template )
	end


	######
	public
	######

	##
	# The list of directories to search in for templates
	attr_accessor :template_search_path

	##
	# The Logger object that gets exporter output
	attr_accessor :logger


	### Main API method -- export the loaded Procfile as supervise service directories
	def export
		servicedir = self.location or
			raise Foreman::Export::Exception, "No service directory specified."
		servicedir = Pathname( servicedir )
		app        = self.app || File.basename( self.engine.directory )
		user       = self.user || app

		unless servicedir.exist?
			say "Creating #{servicedir}..."
			servicedir.mkpath
		end

	    engine.each_process do |name, process|
			say "Setting up %s-%s service directories..." % [ app, name ]
			count   = engine.formation[ name ]
			say "  concurrency = #{count}"
			next unless count >= 1
			procdir = servicedir + "%s-%s" % [ app, name ]

			# Create a numbered service dir for each instance if there are
			# more than one
			if count != 1
				1.upto( count ) do |i|
					self.write_servicedir( process, Pathname(procdir.to_s + "-#{i}"), user, i )
				end
			else
				self.write_servicedir( process, procdir, user )
			end
		end
	end


	### Write a supervise directory to +targetdir+
	def write_servicedir( process, procdir, user, num=1  )
		say "Making directory %s..." % [ procdir ]
		procdir.mkpath

		# Write the down file to keep the service from spinning up before the user has
		# a chance to look things over
		say "  writing the 'down' file"
		write_file( procdir + 'down', '' )

		# Set up logging
		say "  setting up logging..."
		logdir = procdir + 'log'
		logdir.mkpath
		logruntmpl = self.load_template( 'log-run' )
		runfile = logdir + 'run'
		write_file( runfile, logruntmpl.result(binding()) )
		runfile.chmod( 0755 )

		# Set up the envdir
		say "  setting up environment variables..."
		envdir = procdir + 'env'
		envdir.mkpath
        port = engine.port_for( process, num )
		environment_variables = { 'PORT' => port }.
			merge( engine.environment ).
			merge( inline_variables(process.command) )
		environment_variables.each_pair do |var, env|
			write_file( envdir + var, env )
		end

		# Set up the runfile
		runtmpl = self.load_template( 'run' )
		runfile = procdir + 'run'
		write_file( runfile, runtmpl.result(binding()) )
		runfile.chmod( 0755 )

	end


	### Load the daemontools template for the file named +name+, and return it
	### as an ERB object.
	def load_template( name )
		template_name = "#{name}.erb"
		template = self.template_search_path.
			map {|dir| dir + template_name }.
			find {|tmpl| tmpl.exist? }

		template or raise Foreman::Export::Exception,
			"Can't find the %p template in any of: %p" %
			[ name, self.template_search_path.map(&:to_s) ]

		erbtmpl = ERB.new( template.read, nil, '<%>' )
	end


	#########
	protected
	#########

	### Override to output to the logger instead of STDERR.
	def say( message )
		@logger.info( '[foreman export]' ) { message }
	end


	#######
	private
	#######

	### Extract the inline environment variables from +command+ and return them as
	### a Hash.
	def inline_variables( command )
		pairs = command.scan( ENV_VARIABLE_REGEX )
		return Hash[ *pairs.flatten ]
	end


end # Foreman::Export::Daemontools
