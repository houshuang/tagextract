# encoding: utf-8
# utility functions for researchr
$:.push(File.dirname($0))
Home_path = ENV['HOME']
Script_path = File.dirname(__FILE__)

def log(text)
  File.append("#{Script_path}/log.txt",text)
end


# a few extra file functions
class File
  class << self

    # adds File.write - analogous to File.read, writes text to filename
    def write(filename, text)
      File.open(filename,"w") {|f| f << text}
    end

    # adds File.append - analogous to File.read, writes text to filename
    def append(filename, text)
      File.open(filename,"a") {|f| f << text + "\n"}
    end

    # find the last file added in directory
    def last_added(path)
      path += "*" unless path.index("*")
      Dir.glob(path, File::FNM_CASEFOLD).select {|f| test ?f, f}.sort_by {|f|  File.mtime f}.pop
    end

    # find the last file added in directory
    def last_added_dir(path)
      path += "*" unless path.index("*")
      Dir.glob(path + "/*/", File::FNM_CASEFOLD).sort_by {|f| File.mtime f}.pop
    end


    def replace(path, before, after, newpath = "")
      a = File.read(path)
      a.gsub!(before, after)
      newpath = path if newpath == ""
      File.write(newpath, a)
    end
  end
end

# to make multiple replacements easier, gsubs accepts array of replacements (each replacement is array of from/to)
# takes regexp or string replacement
# for example "stian".gsubs(['s', 'x'], [/^/, "\n"])
# you can also provide a universal "to" string, and a list of "from" strings
# for example "this is my house".gsubs({:all_with => ''}, 'this', /s.y/)
# uses the last function to provide remove, which takes a list of search arguments to remove
# the example above is similar to "this is my house".remove('this', /s.y/)
# also provides remove! destructive function
#
# also adds scan2, which returns named capture groups into compressed hash
class String
  def gsubs!(*searches)
    self.replace(gsubs(*searches))
  end

  def any_index(searches)
    searches.each {|search| return true if self.match(search)}
    return false
  end

  def gsubs(*searches)
    if searches[0].kind_of?(Hash)
      args = searches.shift
      all_replace = try { args[:all_with] }
    end
    tmp = self.dup
    searches.each do |search|
      if all_replace
        tmp.gsub!(search, all_replace)
      else
        tmp.gsub!(search[0], search[1])
      end
    end
    return tmp
  end

  def remove(*searches)
    gsubs({:all_with => ''}, *searches)
  end

  def remove!(*searches)
    self.replace(remove(*searches))
  end

  def scan2(regexp) # returns named capture groups into compressed hash, inspired by http://stackoverflow.com/a/9485453/764519
    names = regexp.names
    captures = Hash.new
    scan(regexp).collect do |match|
      nzip = names.zip(match)
      nzip.each do |m|
        captgrp = m[0].to_sym
        captures.add(captgrp, m[1])
      end
    end
    return (captures == {}) ? nil : captures
  end
end


# download a path to a location, require_type is array of acceptable content_types
def dl_file(full_url, to_here, require_type = false)
  require 'open-uri'
  writeOut = open(to_here, "wb")
  url = open(full_url)
  if require_type
    raise NameError unless require_type.index( url.content_type.strip.downcase )
  end
  writeOut.write(url.read)
  writeOut.close
end


# returns either the value of the block, or nil, allowing things to fail gracefully. easily
# combinable with fail unless
def try(default = nil, &block)
  if defined?(DEBUG)
    yield block
  else
    begin
      yield block
    rescue
      return default
    end
  end
end