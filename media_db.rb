#!/usr/bin/env ruby
# you can run this directly to index the MEDIA_ROOT

require 'rubygems'
require 'sequel'
require 'find'

class MediaDB
  def initialize uri
    @db = Sequel.connect uri

    unless @db.table_exists? 'files'
      # this is done specially so that we can benefit from full-text search of the path column
      @db.run <<-END
        CREATE VIRTUAL TABLE files USING fts3 (
          path      VARCHAR(511) NOT NULL,
          playcount INT DEFAULT 0 NOT NULL,
          mtime     TIMESTAMP
        )
      END
    end

    @files = @db[:files]
  end

  def we_care_about? path
    path.match MEDIA_EXTENSIONS
  end

  def new_file path
    # a boring file.
    return unless we_care_about? path

    # we've already got this, whatevs
    return if @files.where(:path => path).first

    begin
      mtime = File.mtime(path)
    rescue Errno::ENOENT
      # the file was removed or renamed
      return
    end

    @files.insert :path => path, :mtime => mtime, :playcount => 0
  end

  def kill_file path
    @files.filter(:path => path).delete
  end

  def directory_deleted(path)
    @files.filter(:path.like("#{path}%")).delete
  end

  def directory_moved(old_path, new_path)
    # update file paths
    @files.filter(:path.like("#{old_path}%")).each do |f|
      new_file_path = f[:path].sub old_path, new_path
      @files.filter(:rowid => f[:rowid]).update(:path => new_file_path)
    end
  end

  # increment a file's playcount
  def increment_playcount(path)
    @files.filter(:path => path).update(:playcount => :playcount + 1)
  end

  def playcount(path)
    f = @files[:path => path]
    f and f[:playcount]
  end

  # return urls that match the given query
  def search q
    @db.fetch('SELECT * FROM files WHERE path MATCH ?', q).all
  end

  def newest
    @files.filter(:playcount => 0).order(:mtime.desc).limit(10).map do |f|
      [ f[:path], f[:path] ]
    end
  end
end

if __FILE__ == $0
  require 'config'

  db = MediaDB.new(REPO_PATH)

  Find.find(MEDIA_ROOT) do |path|
    unless EXCLUDE.member? path
      puts path
      db.new_file(path)
    end
  end
end
