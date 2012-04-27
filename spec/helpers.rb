# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'logger'

# An alternate formatter for Logger instances that outputs +div+ HTML
# fragments.
class HtmlFormatter < Logger::Formatter

	# The default HTML fragment that'll be used as the template for each log message.
	HTML_LOG_FORMAT = %q{
	<div class="log-message %5$s">
		<span class="log-time">%1$s.%2$06d</span>
		[
			<span class="log-pid">%3$d</span>
			/
			<span class="log-tid">%4$s</span>
		]
		<span class="log-level">%5$s</span>
		:
		<span class="log-name">%6$s</span>
		<span class="log-message-text">%7$s</span>
	</div>
	}

	### Override the logging formats with ones that generate HTML fragments
	def initialize( logger, format=HTML_LOG_FORMAT ) # :notnew:
		@logger = logger
		@format = format
		super()
	end


	######
	public
	######

	# The HTML fragment that will be used as a format() string for the log
	attr_accessor :format


	### Return a log message composed out of the arguments formatted using the
	### formatter's format string
	def call( severity, time, progname, msg )
		args = [
			time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
			time.usec,                                                    # %2$d
			Process.pid,                                                  # %3$d
			Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
			severity.downcase,                                                     # %5$s
			progname,                                                     # %6$s
			escape_html( msg ).gsub(/\n/, '<br />')                       # %7$s
		]

		return self.format % args
	end


	#######
	private
	#######

	### Escape any HTML special characters in +string+.
	def escape_html( string )
		return string.
			gsub( '&', '&amp;' ).
			gsub( '<', '&lt;'  ).
			gsub( '>', '&gt;'  )
	end

end # class HtmlFormatter


# A logger outputter that logs to an Array.
class ArrayLogger
	### Create a new ArrayLogger that will append content to +array+.
	def initialize( array=[] )
		@array = array
	end

	######
	public
	######

	##
	# The array of logger output
	attr_reader :array

	### Write the specified +message+ to the array.
	def write( message )
		@array << message
	end

	### No-op -- this is here just so Logger doesn't complain
	def close; end

end # class ArrayLogger

