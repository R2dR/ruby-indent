#!/usr/bin/env ruby

####!/usr/bin/ruby -w

=begin
/***************************************************************************
 *   Copyright (C) 2008, Paul Lutus                                        *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
=end

PVERSION = "Version 2.9, 10/24/2008"

module RBeautify
	class RBoo
	end
	class << RBoo
		private :new
		
		def text(text)
			array = case text
			when Array then text
			when String then text.split(/\n/)
			else raise 'Invalid argument: must be string array or text'
			end
			def array.each_line(&block)
				self.each(&block)
			end
			new(array)
		end
		
		def file(file)
			file = case file
			when Text
			when File
			else raise 'Invalid argument: must be file object or name'
			end
			new(file)
		end
	end
end

RBeautify::RBoo.class_eval do
	TABSTR = " "
	TABSIZE = 2
	
  # indent regexp tests
  INDENTS = [
    /^module\b/,
    /^class\b/,
    /(=\s*|^)if\b/,  #changed
    #/^if\b/,
		#/^\@{0,2}[\w\.]*[\s\t]*\=[\s\t]*if\b/,
    /(=\s*|^)until\b/,
    /(=\s*|^)for\b/,
    /(=\s*|^)unless\b/, #changed
    /(=\s*|^)while\b/,
    /(=\s*|^)begin\b/,
    /(^| )case\b/,
    /\bthen\b/,
    /^rescue\b/,
    /^def\b/,
    /\bdo\b/,
    /^else\b/,
    /^elsif\b/,
    /^ensure\b/,
    /\bwhen\b/,
    /\{[^\}]*$/,
    /\[[^\]]*$/,
    /\([^\)]*$/  #added
  ]

  # outdent regexp tests
  OUTDENTS = [
    /^rescue\b/,
    /^ensure\b/,
    /^elsif\b/,
    /^end\b/,
    /^else\b/,
    /\bwhen\b/,
    /^[^\{]*\}/,
    /^[^\[]*\]/,
    /^[^\(]*\)/  #added
  ]

	attr_reader :tab_count
	attr_reader :line_source
	
	def initialize(line_source)
		raise "Source is not a line source" unless line_source.methods.include?(:each_line)
		@line_source = line_source
	end
	
	def init_vars
    @comment_block = false
    @inside_here_doc_term = nil
    @source_code_end = false
    @multi_line_array = []
    @multi_line_string = ""
    @tab_count = 0
    @output = []
	end

  def indention(tabs = @tab_count)
    tabs <= 0 ? "" : TABSTR * TABSIZE * tabs
  end

  def indent_line(line, tabs = @tab_count)
    line.strip!
    line.length > 0 ? indention(tabs) + line : line
  end
	
	def source_code_ended?() @source_code_end end
	def after_source_end?() @source_code_end end
	def inside_comment_block?() @comment_block end
	def inside_here_doc?() !!@inside_here_doc_term end

	END_SOURCE_CODE_REGEX = /^__END__/
	CONTINUING_LINE_REGEX = /^(.*)\\\s*(#.*)?$/  
	COMMENT_LINE_REGEX = /^\s*#/
	HERE_DOC_REGEX = /(=|\{|\bdo|^)\s*<<-?\s*("([^"]+)|'([^']+)|([_\w]+))/
	HERE_DOC_START_REGEX = /^\s*<<-?\s*("([^"]+)|'([^']+)|([_\w]+))/

	# careful! here doc can be confused with array assignment, ie array<<'RUBY'
	# this may not be useful because we want to 
	
	def scan_here_doc_term(line)
		scan = line.scan(HERE_DOC_START_REGEX).flatten[2..-1] #yields array or nil
		scan && scan.compact.first
	end
  def is_continuing_line?(line)
  	!is_comment_line?(line) && line =~ CONTINUING_LINE_REGEX
  end
  def is_comment_line?(line)
  	line =~ COMMENT_LINE_REGEX
  end
	def is_here_doc_start?(line)
		line =~ HERE_DOC_START_REGEX
	end

	def output_current_line
    unless @multi_line_array.empty?
      @multi_line_array.each do |ml|
        @output << indent_line(ml)
      end
      @multi_line_array.clear
      @multi_line_string = ""
    else
      @output << indent_line(@current_line)
    end	
	end
	
  def indent
  	init_vars
    @line_source.each_line do |line|
    	line.chomp!
			debugger
    	@current_line = line
    	
    	#special cases & conditions
    	if source_code_ended?
    		output_current_line
    		next
    	end

			if inside_here_doc?
				if line =~ /^\s*#{@inside_here_doc_term}\b/
      		@inside_here_doc_term = nil
				end
				output_current_line
				next
			elsif inside_comment_block?
		    if(line =~ /^=end/)
    		  @comment_block = false
    		end
				output_current_line
				next
    	else #not inside block comment or here doc
				#not here -- instead test as possible double on a line
      	#if is_here_doc_start?(line)
        #	@here_doc_term = scan_here_doc_term(line)
        #	@inside_here_doc = @here_doc_term.size > 0
      	#end

    		if line =~ END_SOURCE_CODE_REGEX
    			@source_code_end = true
    			output_current_line
    			next
    		end
				if line =~ /^=begin\b/
					@comment_block = true
					output_current_line
					next
				end
				if is_here_doc_start?(line)
					@inside_here_doc_term = scan_here_doc_term(line)
					output_current_line
					next
				end
				
    		if is_continuing_line?(line)
        	@multi_line_array.push line
        	@multi_line_string += line.sub(CONTINUATION_REGEX,'\1')
        	next
      	end
      end
	
	    if(@multi_line_string.length > 0)
  	    @multi_line_array.push line
    	  @multi_line_string += line.sub(/^(.*)\\\s*$/,'\1')
    	end
    	eval_line (@multi_line_string.length > 0 ? @multi_line_string : line).strip
    end
        
    STDERR.puts "Error: indent/outdent mismatch: #{@tab_count}." if @tab_count != 0
    (@output << "\n").join("\n") #, @tab_count != 0
  end

	INLINE_CLOSURES = [
    /\{[^\{]*?\}/,
    /\[[^\[]*?\]/,
		/'.*?'/,
		/".*?"/,
		/\`.*?\`/,
		/\([^\(]*?\)/,
		/\/.*?\//,
		/%r(.).*?\1/
	]

	def eval_line(line)    
    comment_line = (line =~ /^#/)
    if(!comment_line)	
      # throw out sequences that will
      # only sow confusion
			INLINE_CLOSURES.each do |closure|
				while line.gsub!(closure); end
			end
      # delete end-of-line comments
      line.sub!(/#[^\"]+$/,"")
      # convert quotes
      line.gsub!(/\\\"/,"'")
      OUTDENTS.each do |regex|
        if line =~ regex
          @tab_count -= 1
          break
        end
      end
    end
    output_current_line
    if(!comment_line)
      INDENTS.each do |re|
        if(line =~ re && !(line =~ /\s+end\s*$/))
          @tab_count += 1
          break
        end
      end
    end
  end # indent_line

  def RBeautify.beautify_file(path)
    error = false
    if(path == '-') # stdin source
      source = STDIN.read
      dest,error = indent_code(source,"stdin")
      print dest
    else # named file source
      source = File.read(path)
      dest,error = indent_code(source,path)
      if(source != dest)
        # make a backup copy
        File.open(path + "~","w") { |f| f.write(source) }
        # overwrite the original
        File.open(path,"w") { |f| f.write(dest) }
      end
    end
    return error
  end # beautify_file

  def RBeautify.main
    error = false
    if(!ARGV[0])
      STDERR.puts "usage: Ruby filenames or \"-\" for stdin."
      exit 0
    end
    ARGV.each do |path|
      error = (beautify_file(path))?true:error
    end
    error = (error)?1:0
    exit error
  end # main
end # module RBeautify

# if launched as a standalone program, not loaded as a module
if __FILE__ == $0
  RBeautify.main
end
