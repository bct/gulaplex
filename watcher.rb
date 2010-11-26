#!usr/bin/ruby

require 'inotify'
require 'find'

class Watcher
  def initialize
    @i = Inotify.new
    @wd_to_path = {}
    @cookies = {}

    @when_directory_created = lambda {}
    @when_directory_deleted = lambda {}
    @when_directory_moved   = lambda {}

    @when_file_created = lambda {}
    @when_file_deleted = lambda {}
  end

  # add a single directory watch
  def _watch(path)
    wd = @i.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE)
    @wd_to_path[wd] = path
  rescue Errno::EACCES
  end

  # add watches, recursively
  def watch(path, excludes)
    Find.find(path) do |e|
      _watch(e) if File.directory?(e) and not excludes.member?(e)
    end
  end

  def go!
    @i.each_event do |ev|
      next if not ev.name # wtf i dunno
      self.handle_new_event(ev)
    end
  end

  def handle_new_event(ev)
    full_path = @wd_to_path[ev.wd] + '/' + ev.name

    akshun = if (ev.mask & Inotify::DELETE) != 0
               :delete
             elsif (ev.mask & Inotify::CREATE) != 0
               :create
             elsif (ev.mask & Inotify::MOVED_FROM) != 0
               :move_d
             elsif (ev.mask & Inotify::MOVED_TO) != 0
               :move_c
             end

    isdir = (ev.mask & Inotify::ISDIR) != 0

    # new directory added, start watching it
    if isdir
      if akshun == :create
        directory_created(full_path)
      elsif akshun == :delete
        @when_directory_deleted.call full_path
      elsif akshun == :move_d
        directory_moved_d(full_path, ev.cookie)
      elsif akshun == :move_c
        directory_moved_c(full_path, ev.cookie)
      end
    elsif akshun == :create or akshun == :move_c
      @when_file_created.call(full_path)
    elsif akshun == :delete or akshun == :move_d
      @when_file_deleted.call(full_path)
    end
  end

  def directory_created full_path
    begin
      # watch this directory, recursively
      watch(full_path, [])

      Dir[full_path+'/*'].each do |p|
        @when_file_created.call(p) if File.file? p
      end
    rescue Errno::ENOENT
      # maybe the directory was deleted before we handled this notification
      # that's ok
    end

    @when_directory_created.call full_path
  end

  def directory_moved_d full_path, cookie
    # store the original path so that we can replace it with the new one
    @cookies[cookie] = full_path
  end

  def directory_moved_c full_path, cookie
    old_path = @cookies[cookie]
    @cookies.delete(cookie)
    # update our wd_to_path hash with the new directory name
    wd, path = @wd_to_path.find { |k,v| v == old_path }
    @wd_to_path[wd] = full_path

    @when_directory_moved.call old_path, full_path
  end

  def when_directory_created &block
    @when_directory_created = block
  end

  def when_directory_deleted &block
    @when_directory_deleted = block
  end

  def when_directory_moved &block
    @when_directory_moved = block
  end

  def when_file_created &block
    @when_file_created = block
  end

  def when_file_deleted &block
    @when_file_deleted = block
  end
end


if __FILE__ == $0
  require 'config'

  w = Watcher.new
  w.when_directory_created { |p| puts "newdir #{p}" }
  w.when_directory_deleted { |p| puts " nodir #{p}" }
  w.when_directory_moved   { |old,new| puts "#{old} -> #{new}" }

  w.when_file_created { |p| puts "newfile #{p}" }
  w.when_file_deleted { |p| puts " nofile #{p}" }

  w.watch(MEDIA_ROOT)
  puts "set up watches, continuing"
  w.go!
end
