# encoding: UTF-8
$:.push(File.dirname($0))
require 'utility-functions'
require 'yaml'
# =============================================================================
# todo:
# -
# do the transform on file uploaded
# preview with HTML, offer various downloads
# integrate with Bootstrap, nice design
# animation, short video explaining etc
# ideas: guess indent pattern based on first line indented with whitespace
# =============================================================================

# we have to do this because of using Ruby 1.8.7 regexp, with no lookahead.
# also, we turn - into ___ because the \w end-of-word only accepts _ and not -
# we put it all back when we're done
class TagExtract
  def initialize(text)
    @text = clean_ckeys(text)
    text2array
    linecontext
    process_tags
  end

  def taglist_to_html
    tag_pre = %Q|<div class="toc"><div class="tocheader toctoggle" id="toc__header">Tags</div><div id="toc__inside"><ul class="toc">|
    tag_post = %Q|</ul></li></ul></div></div>|

    out = tag_pre
    tag_list.each do |tag|
      out << %Q|<li class="level1"><div class="li"><span class="li"><a href="##{tag}" class="toc">#{tag}</a></span></div></li>|
    end
    out << tag_post
    return out
  end

  def to_html
    text = to_taskpaper + "\n"

    # TOC with tags
    out = taglist_to_html

    # change tabs to CSS styles
    out << text.gsubcap(/^(\t*)(.+?)$/) {|tabs, content|"<p class=\"tab#{tabs.size}\">#{content}</p>"}
    out.gsub!(%r|\<p class="tab0"\>(.+?):\<|, '<a  id="\1"></a><a class="tags" href="#\1">\0/a><')
    out << "</div>"
    return out
  end

  def tag_list
    @tags.dup.map {|tag,_| restore_ckeys(tag) }
  end

  def to_taskpaper
    text = output_taskpaper
    return restore_ckeys(text)
  end

  def clean_ckeys(text)
    return text.gsubs([/\[\@(.+?)\]/, '[!!!!\1]'], ['-', '____'])
  end

  def restore_ckeys(text)
    return text.gsubs([/\[\!!!!(.+?)\]/, '[@\1]'], ['____', '-'])
  end

  # insert lines into an array with first argument being indent level, second being line content
  # default indent pattern is tabs
  def text2array(indent_pattern = /^(\t*)/)
    lines = Array.new

    @text.dup.each_line_with_index do |l, i|

      # count tabs at front of line to get indent level
      tabs = $1 if indent_pattern =~ l
      level = (defined? tabs) ? tabs.size : 0

      lines[i] = {:level => level, :line => l}
    end

    @lines = lines
  end


  # iterate through array and for each line, pick out "line context" (all subsequent lines at lower levels)
  def linecontext(ckey_pattern = /^\[!!!!(.+?)\]/)
    ckey = ''       # holds the current citation key
    lcontext = Array.new
    text = ''

    @lines.dup.each_with_index do |l, i|
      level = l[:level]
      line = l[:line]

      # if first level, grab ckey or empty out
      if level == 0
        ckey = (ckey_pattern =~ line) ? $1 : ''
      end

      if i == @lines.size-1 || @lines[i+1][:level] <= level   # if it's the last entry, or the next entry is lower level
        lcontext[i] = {:context => line.strip, :ckey => ckey}
      else
        c = i + 1         # set start of counter to current pub

        # as long as the level of the line in question is higher than the start level
        while c < @lines.size && @lines[c][:level] > level
          text << @lines[c][:line][level..-1] # remove the same number of indents as highest level has, preserve subsequent indents
          c += 1
        end

        lcontext[i] = {:context => line + text, :ckey => ckey}
        text = ''
      end
    end
    @lcontext = lcontext
  end


  # process tags, taking line context and ckey into account
  def process_tags(tag_regexp = /\s\@(.+?)\b/, ckey_pattern = /^\[!!!!(.+?)\]/)
    all_tagged = '' # holds all tagged text, to later check for lines that have not been tagged
    tags = Hash.new

    # iterate through array, and if tag is found, insert line context for that line into tag hash
    @lines.dup.each_with_index do |line, i|
      hastag = line[:line].scan2(tag_regexp)        # recognize a @tag
      if hastag
        hastag[:tagcapt].each do |x|            # for each tag if multiple
          cont = @lcontext[i][:context]                 # get the context for the current line
          cont.remove!(/\[!!!!#{@lcontext[i][:ckey]}\] /, tag_regexp, /\:$/)
          tags.add(x, [cont.strip, @lcontext[i][:ckey]])
          all_tagged << cont
        end
      end
    end

    # do a final sweep to see if any lines have not been collected
    @lines.dup.each_with_index do |l, i|
      next if l[:line].remove(ckey_pattern).strip.size == 0       # nothing but ckey
      next if l[:line].scan2(tag_regexp)                          # recognize a @tag

      cont = l[:line].remove(/\[\@#{@lcontext[i][1]}\]/, /\:$/).strip

      unless all_tagged.index(cont) # unless it has been tagged
        cont.remove!(/\[!!!!#{@lcontext[i][:ckey]}\] /, tag_regexp, /\:$/)
        tags.add('not_tagged', [cont, @lcontext[i][:ckey]])
      end
    end
    @tags = tags
  end


  # format output for taskpaper
  def output_taskpaper
     return @out_taskpaper if defined? @out_taskpaper
     out = ''

     @tags.dup.each do |tag, content|
      nockey = ''

      out << "#{tag}:\n"
      content.each do |fragments|
        fragments[0] = fragments[0].lines.map {|ln| ("\t\t" + ln).remove("\n")}

        if fragments[1] == ''
          nockey << "#{fragments[0].join("\n")}\n"
          next
        end

        out << "\t[@#{fragments[1]}]:\n#{fragments[0].join("\n")}\n"
      end
      out << "\tNo citekey:\n#{nockey}" if nockey.size > 0
    end
    @out_taskpaper = out
    return out
  end


  # format output for scrivener
  def to_scrivener(dir)
    `mkdir '#{dir}.tmp'`
    @tags.dup.each do |tag, content|
      out = ''
      nockey = ''

      tag = restore_ckeys(tag)
      content.each do |fragments|
        fragments[0] = restore_ckeys(fragments[0])
        fragments[1] = restore_ckeys(fragments[1])

        if fragments[1] == ''
          nockey << "#{fragments[0]}\n\n"
          next
        end
        out << "#{fragments[0]} [@#{fragments[1]}]\n\n"
      end
      if nockey.size > 0
        out << nockey
      end
      File.write("#{dir}.tmp/#{tag}.txt", out)
    end
    puts "zip '#{dir}' '#{dir}.tmp/*'"
    `zip -j -r '#{dir}' '#{dir}.tmp/'`
  end
end

if __FILE__ == $0

  a =File.read('./test.taskpaper')

  litreview = TagExtract.new(a)
puts   litreview.to_html

  litreview.to_scrivener("tmp")
litreview.output_taskpaper
litreview.to_taskpaper
litreview.to_scrivener("tmp")
end




















#   if format == 'dokuwiki'
#     out.gsubs!(
#       ["\t", '  '],
#       [/(?! )(.+?)$/, '  * \1'],
#       [/^  \* /, 'h2. ']
#     )

# ideas:
# - hierarchy of tags
# - if tag starts with @-, only take current line

# Ruby 1.9.3 Oniguruma search string
# tag_regexp = /
# \B                  # non-word marker
# (?<!\[)             # not preceded by [ (to avoid catching publication references like [@publication])
# \@(?<tagcapt>.+?)   # word starting with @
# \b                  # word boundary
# /x
