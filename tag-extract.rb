# encoding: UTF-8
$:.push(File.dirname($0))
require 'utility-functions'

# =============================================================================
# todo: see if Heroku/Site5 allows Ruby 1.9, otherwise rewrite regexps
# try to modularize library - first parse, then output filters
# do the transform on file uploaded
# preview with HTML, offer various downloads
# integrate with Bootstrap, nice design
# animation, short video explaining etc
# ideas: guess indent pattern based on first line indented with whitespace
# =============================================================================

# we have to do this because of using Ruby 1.8.7 regexp, with no lookahead.
# also, we turn - into ___ because the \w end-of-word only accepts _ and not -
# we put it all back when we're done
def clean_ckeys(text)
  text.gsubs([/\[\@(.+?)\]/, '[!!!!\1]'], ['-', '____'])
end

def restore_ckeys(text)
  text.gsubs([/\[\!!!!(.+?)\]/, '[@\1]'], ['____', '-'])
end

# insert lines into an array with first argument being indent level, second being line content
# default indent pattern is tabs
def text2array(text, indent_pattern = /^(\t*)/)
  lines = Array.new

  text.each_line_with_index do |l, i|

    # count tabs at front of line to get indent level
    tabs = $1 if indent_pattern =~ l
    level = (defined? tabs) ? tabs.size : 0

    lines[i] = {:level => level, :line => l}
  end

  return lines
end


# iterate through array and for each line, pick out "line context" (all subsequent lines at lower levels)
def linecontext(lines, ckey_pattern = /^\[!!!!(.+?)\]/)
  ckey = ''       # holds the current citation key
  lcontext = Array.new
  text = ''

  lines.each_with_index do |l, i|
    level = l[:level]
    line = l[:line]

    # if first level, grab ckey or empty out
    if level == 0
      ckey = (ckey_pattern =~ line) ? $1 : ''
    end

    if i == lines.size-1 || lines[i+1][:level] <= level   # if it's the last entry, or the next entry is lower level
      lcontext[i] = {:context => line.strip, :ckey => ckey}
    else
      c = i + 1         # set start of counter to current pub

      # as long as the level of the line in question is higher than the start level
      while c < lines.size && lines[c][:level] > level
        text << lines[c][:line][level..-1] # remove the same number of indents as highest level has, preserve subsequent indents
        c += 1
      end

      lcontext[i] = {:context => line + text, :ckey => ckey}
      text = ''
    end
  end
  return lcontext
end


# process tags, taking line context and ckey into account
def process_tags(lines, lcontext, tag_regexp = /\s\@(.+?)\b/, ckey_pattern = /^\[!!!!(.+?)\]/)
  all_tagged = '' # holds all tagged text, to later check for lines that have not been tagged
  tags = Hash.new

  # iterate through array, and if tag is found, insert line context for that line into tag hash
  lines.each_with_index do |line, i|
    hastag = line[:line].scan2(tag_regexp)        # recognize a @tag
    if hastag
      hastag[:tagcapt].each do |x|            # for each tag if multiple
        cont = lcontext[i][:context]                 # get the context for the current line
        cont.remove!(/\[!!!!#{lcontext[i][:ckey]}\] /, tag_regexp, /\:$/)
        tags.add(x, [cont.strip, lcontext[i][:ckey]])
        all_tagged << cont
      end
    end
  end

  # do a final sweep to see if any lines have not been collected
  lines.each_with_index do |l, i|
    next if l[:line].remove(ckey_pattern).strip.size == 0       # nothing but ckey
    next if l[:line].scan2(tag_regexp)                          # recognize a @tag

    cont = l[:line].remove(/\[\@#{lcontext[i][1]}\]/, /\:$/).strip

    unless all_tagged.index(cont) # unless it has been tagged
      cont.remove!(/\[!!!!#{lcontext[i][:ckey]}\] /, tag_regexp, /\:$/)
      tags.add('not_tagged', [cont, lcontext[i][:ckey]])
    end
  end
  return tags
end


# format output for taskpaper
def output_taskpaper(tags)
   out = ''

   tags.each do |tag, content|
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
  return out
end


a = File.read("Litreview.taskpaper")

text = clean_ckeys(a)
lines = text2array(text)
lcontext = linecontext(lines)
tags = process_tags(lines, lcontext)
output = output_taskpaper(tags)
output = restore_ckeys(output)
File.write('out.taskpaper', output)
exit



















# when 'scrivener'
#   `mkdir '#{outdir}'`
#   `rm -rf '#{outdir}/*.txt'`
#   tags.each do |tag, content|

#     out = ''
#     nockey = ''
#     content.each do |fragments|
#       if fragments[1] == ''
#         nockey << "#{fragments[0]}\n\n"
#         next
#       end
#       out << "#{fragments[0]} [@#{fragments[1]}]\n\n"
#     end
#     if nockey.size > 0
#       out << nockey
#     end
#     File.write("#{outdir}/#{tag}.txt", out)
#   end



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
