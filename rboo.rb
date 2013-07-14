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
 **Rework of original RBeautify by R2dR
=end

PVERSION = "Version 3.0, 7/12/2013"

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
  def expunge
    @expunged ||= String.expunge_closures(self)
  end
end

RBeautify::RBoo.class_eval do
  TABSTR = " "
  TABSIZE = 2
  OUT=-1
  IN=1
	
	#In and Out indentations
	#predents are tabs added/subtracted before the line is printed
	#postdents are the tabs added/subtracted after the line is printed
	DENTS = {
    /^end\b/ => {:predent=>OUT},
    /\send\b/ => {:postdent=>OUT},
    /\{/ => {:postdent=>IN}, #from /\{[^\}]*$/
    /\[/ => {:postdent=>IN}, #from /\[[^\]]*$/
    /\(/ => {:postdent=>IN}, #from /\([^\)]*$/
    /^\}/ => {:predent=>OUT},  #/^[^\{\w]*\}/,
    /^\]/ => {:predent=>OUT},
    /^\)/ => {:predent=>OUT},  #/^[^\(\w]*\)/
    /.(\})/ => {:postdent=>OUT},
    /.(\])/ => {:postdent=>OUT},
    /.(\))/ => {:postdent=>OUT},
    /^module\b/ => {:postdent=>IN},
    /^class\b/ => {:postdent=>IN}, 
    /(?:=\s*|^)if\b/ => {:postdent=>IN}, #/(=\s*|^)if\b/ => :indent,  
    /(?:=\s*|^)until\b/ => {:postdent=>IN}, #/(=\s*|^)until\b/ => :indent,
    /(?:=\s*|^)for\b/ => {:postdent=>IN},
    /(?:=\s*|^)unless\b/ => {:postdent=>IN},
    /(?:=\s*|^)while\b/ => {:postdent=>IN},
    /(?:=\s*|^)begin\b/ => {:postdent=>IN},
    /(?:^| )case\b/ => {:postdent=>IN},
    /^rescue\b/ => {:predent=>OUT, :postdent=>IN},
    /^def\b/ => {:postdent=>IN},
    /\bdo\b/ => {:postdent=>IN},
    /^else\b/ => {:predent=>OUT, :postdent=>IN},
    /^elsif\b/ => {:predent=>OUT, :postdent=>IN},
    /^ensure\b/ => {:predent=>OUT, :postdent=>IN},
    /\bwhen\b/ => {:predent=>OUT, :postdent=>IN},
	}
  #/\bthen\b/ => {:postdent=>IN}, #???

  attr_reader :tab_count
  attr_reader :line_source

  def initialize(line_source)
    raise "Source is not a line source" unless line_source.methods.include?(:each_line)
    @line_source = line_source
  end

  def mismatch?
    @tab_count != 0
  end

  def init_vars
    @inside_comment_block = false
    @inside_here_doc_term = nil
    @inside_source_code = true
    @continued_line_array = []
    @tab_count = 0
    @lines = []
    @output = nil
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
  HERE_DOC_REGEX = /(?:(?:=|^)\s*<<-?|<<-)\s*(?:'([^'\s]+)|"([^"\s]+)|([^\s]+))/
  # careful! here doc can be confused with array assignment, ie array<<'RUBY'
  # this may not be useful because we want to

  def scan_here_doc_term(line)
    line.scan(HERE_DOC_REGEX).flatten.compact.first
  end
  def is_continuing_line?(line)
    line.expunge =~ /^[^#]*\\\s*(#.*)?$/
    #first use expunge to eliminate inline closures 
    #that may contain comment char '#'
  end
  def is_comment_line?(line)
    line =~ COMMENT_LINE_REGEX
  end
  def is_here_doc_start?(line)
    line =~ HERE_DOC_REGEX
  end

  def write_line(line)
    @lines << line
  end

  def output
    @output ||= (@lines << "\n").join("\n")
  end

  def output_line(line, opts={:indent=>false})
    unless @continued_line_array.empty?
      @continued_line_array.each do |ml|
        write_line(opts[:indent] ? indent_line(ml) : ml)
      end
      @continued_line_array.clear
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
          @tab_count -= 1
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
        @continued_line_array.push line
        next
      end

      eval_source_line concat_continued_lines(line)
    end

    output
  end

  def concat_continued_lines(line)
    return line unless @continued_line_array.length > 0
    @continued_line_array.push line
    @continued_line_array.inject("")do|str, item|
      str += item.sub(CONTINUING_LINE_REGEX, '\1')
    end
  end

  def eval_source_line(original_line)
    if original_line.empty?
      output_line("", :indent=>false)
      return
    end
    stripline = original_line.strip
    #guard for special beginning-of-line cases that void further indentation analysis
    case
    when stripline =~ END_SOURCE_CODE_REGEX
      @inside_source_code = false
      output_line(original_line, :indent=>false)
      return
    when stripline =~ /^=begin\b/
      @inside_comment_block = true
      output_line(original_line, :indent=>false)
      return
    when (spaces = original_line.scan(/^(\s*)#/).flatten.first)
      #comment lines
      output_line(original_line, :indent=>(spaces.length > 0))
      return
    end
    
    lines = original_line.expunge.squeeze(';').split(/;/).map(&:strip)
    lines.each_with_index do |line, index|
    	lines[index] = " #{lines[index]}" if index > 0
    end
    counts = Struct.new(:predents, :postdents).new(0,0)
    lines.each do |line|
      next if line.empty?
      break if line =~ /^\s*#/

      # delete end-of-line comments
      line.sub!(/#[^\"]+$/,"")
      # convert quotes
      line.gsub!(/\\\"/,"'")

      #find first occurrence of indent, outdent, postdent or inside-special-case
			_scan_line = line.dup      
      loop do
        first = Struct.new(:pos, :regex).new(_scan_line.length + 1)
        DENTS.keys.each do |regex|
        	if (pos = (_scan_line =~ regex)) && line =~ regex && pos < first.pos
        		first.regex = regex
        		first.pos = pos
        	end
        end
        if (pos = (_scan_line =~ HERE_DOC_REGEX)) && line =~ HERE_DOC_REGEX && pos < first.pos
          first.regex = :heredoc
          first.pos = pos
        end

				case first.regex
				when nil then break
				when :heredoc
        	@inside_here_doc_term = scan_here_doc_term(_scan_line)
        	counts.postdents += 1
        	break
        else
        	DENTS[first.regex].each do |type, count|
		        case type
  		      when :predent then counts.predents += count
    		    when :postdent then counts.postdents += count
	      	  end
	      	end
        end
        
        #remove the regex from the _scan_line
        #MUST sub with a space, not a blank!
        _scan_line = _scan_line.sub(first.regex, ' ')
      end
    end
    @tab_count += counts.predents
    output_line(original_line, :indent=>true)
    @tab_count += counts.postdents
  end
end

module RBeautify
  def RBeautify.indent_file(path)
    error = false
    if(path == '-') # stdin source
      rboo = RBeautify::RBoo.text(STDIN.read)
      result = rboo.indent
      error ||= rboo.mismatch?
      STDERR.puts "Error: indent/outdent mismatch: #{rboo.tab_count}." if rboo.tab_count != 0
      print result
    else # named file source
      source = File.read(path)
      rboo = RBeautify::RBoo.text(source)
      result = rboo.indent
      error ||= rboo.mismatch?
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
