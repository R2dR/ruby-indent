#!/usr/bin/env ruby

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
    
  end
end

String.class_eval do

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
  def String.expunge_closures(line)
    INLINE_CLOSURES.inject(line.dup) do |_line, closure|
      while _line.gsub!(closure, " "); end
      _line
    end
  end
  def expunged
  	@expunged ||= String.expunge_closures(self)
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
    /^[^\w]*\}/,  #/^[^\{\w]*\}/,
    /^[^\[\w]*\]/,
    /^[^\w]*\)/ #/^[^\(\w]*\)/ 
  ]

  POST_OUTDENTS = [
    /^.*\w.*\}/,
    /^.*\w.*\]/,
    /^.*\w.*\)/   	
  ]

  attr_reader :tab_count
  attr_reader :line_source

  def initialize(line_source)
    raise "Source is not a line source" unless line_source.methods.include?(:each_line)
    @line_source = line_source
  end
  
  def error?
  	@tab_count != 0
  end

  def init_vars
    @inside_comment_block = false
    @inside_here_doc_term = nil
    @inside_source_code = true
    @multi_line_array = []
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

  def source_code_ended?() !@inside_source_code end
  def inside_source_code?() @inside_source_code end
  def inside_comment_block?() @inside_comment_block end
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
  	#first eliminate inline closures that may contain comment char '#'
  	line.expunged =~ /^[^#]*\\\s*(#.*)?$/
  end
  def is_comment_line?(line)
    line =~ COMMENT_LINE_REGEX
  end
  def is_here_doc_start?(line)
    line =~ HERE_DOC_START_REGEX
  end
  
  def write_line(line)
  	@output << line
  end
  
  def flush_output
    (@output << "\n").join("\n")
  end
	
	def output_line(line, opts={:indent=>false})
    unless @multi_line_array.empty?
      @multi_line_array.each do |ml|
        write_line(opts[:indent] ? indent_line(ml) : ml)
      end
      @multi_line_array.clear
    else
	    write_line(opts[:indent] ? indent_line(line) : line)
	  end
	end
	
  def indent
    init_vars
    @line_source.each_line do |line|
      line.chomp!
      @current_line = line.dup

      #special cases & conditions
      if !inside_source_code?
        output_line(line, :indent=>false)
        next
      end

      if inside_here_doc?
      	#note: HERE DOC terminators must be on there own line
      	# the below regex works for all terminators
        if line =~ /^\s*#{@inside_here_doc_term}\b/
          @inside_here_doc_term = nil
          output_line(line, :indent=>true)
        else
	        output_line(line, :indent=>false)
	      end
        next
      elsif inside_comment_block?
        if(line.strip =~ /^=end/)
          @inside_comment_block = false
        end
        output_line(line, :indent=>false)
        next
     	end
     	
      #not inside block comment or here doc
      if is_continuing_line?(line)
        @multi_line_array.push line
        next
      end
      
      eval_line combined_lines(line)
    end

		flush_output
  end
  
  def combined_lines(line)
    return line unless @multi_line_array.length > 0
    @multi_line_array.push line
    @multi_line_array.inject("")do|str, item|
      str += item.sub(CONTINUING_LINE_REGEX, '\1')
    end
  end
  
  def eval_line(original_line)
  	line = original_line.strip
    case
    when line.empty?
    	output_line("", :indent=>false)
    when line =~ END_SOURCE_CODE_REGEX
      @inside_source_code = false
      output_line(line, :indent=>false)
    when line =~ /^=begin\b/
      @inside_comment_block = true
      output_line(line, :indent=>false)
    when is_here_doc_start?(line)
      @inside_here_doc_term = scan_here_doc_term(line)
      output_line(line, :indent=>true)
    when (spaces = original_line.scan(/^(\s*)#/).flatten.first)
    	#comment lines
      output_line(line, :indent=>(spaces.length > 0))
    else
      # throw out sequences that will
      # only sow confusion
      line = line.expunged
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
	   
    	output_line(original_line, :indent=>true)
    	POST_OUTDENTS.each do |re|
    		if line =~ re
    			@tab_count -= 1
    			break
    		end
    	end
      INDENTS.each do |re|
        if(line =~ re && !(line =~ /\s+end\s*$/))
          @tab_count += 1
          break
        end
      end    
    end
	end
end

module RBeautify	    
  def RBeautify.indent_file(path)
  	error = false
    if(path == '-') # stdin source
    	rboo = RBeautify::RBoo.text(STDIN.read)
    	result = rboo.indent
    	error ||= rboo.error?
    	STDERR.puts "Error: indent/outdent mismatch: #{rboo.tab_count}." if rboo.tab_count != 0
      print result
    else # named file source
      source = File.read(path)
      rboo = RBeautify::RBoo.text(source)
      result = rboo.indent
      error ||= rboo.error?
    	STDERR.puts "Error: indent/outdent mismatch: #{rboo.tab_count}." if rboo.tab_count != 0
      if(source != result)
        # make a backup copy
        File.open(path + "~","w") { |f| f.write(source) }
        # overwrite the original
        File.open(path,"w") { |f| f.write(result) }
      end 
    end 
    error
  end
    
  def RBeautify.main
    error = false
    if(!ARGV[0])
      STDERR.puts "usage: Ruby filenames or \"-\" for stdin."
      exit 1
    end
    ARGV.each do |path|
      error ||= indent_file(path)
    end
    exit (error ? 1 : 0)
  end # main
end # module RBeautify

# if launched as a standalone program, not loaded as a module
if __FILE__ == $0
  RBeautify.main
end
