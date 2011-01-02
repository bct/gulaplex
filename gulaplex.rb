#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

require 'mplayer'

require 'config'

require 'json'

require 'watcher'
require 'media_db'

require 'sinatra/default_charset'
Sinatra.register Sinatra::DefaultCharset
set :default_charset, 'utf-8'

def show_media_path path
  @root_tree = json_media_path(path)

  haml :media_path
end

def json_media_path path
  dir = File.join(MEDIA_ROOT, path)

  entries = Dir.entries(dir)
  entries.delete '.'
  entries.delete '..'

  entries = entries.map { |x| File.join path, x }

  ds, fs = entries.partition do |x|
    full_path = File.join(MEDIA_ROOT, x)

    # treat it as a directory if it is a directory and it's not a dvd directory
    File.directory?(full_path) and not File.directory?(File.join(full_path, 'VIDEO_TS'))
  end
  # augment with playcounts
  fs = fs.sort.reject { |f| f.match(IGNORE_EXTENSIONS) }.map { |f| [f, $db.playcount(File.join(MEDIA_ROOT, f))] }
  { 'directories' => ds.sort, 'files' => fs }.to_json
end

get '/' do
  redirect '/media/'
end

get /media\/(.*)/ do |path|
  headers 'Cache-Control' => 'no-cache'

  if request.xhr?
    content_type :json

    json_media_path(path)
  else
    content_type :html

    show_media_path(path)
  end
end

get '/search' do
  headers 'Cache-Control' => 'no-cache'

  if params[:q]
    # return the search results
    $db.search(params[:q]).map do |p|
      # strip off prefix, we only want to see relative to MEDIA_ROOT
      path = p[:path].sub(MEDIA_ROOT, '')
      [ path, p[:playcount] ]
    end.sort.to_json
  else
    # return the search page
    haml :search
  end
end

post '/playfile' do
  $mp.playlist_append(File.join(MEDIA_ROOT, params[:path]), File.basename(params[:path]))
  ''
end

post '/playdir' do
  $mp.playlist_append_dir params[:path]
  ''
end

post '/playlist' do
  p params
  p request.body.read
  ''
end

post '/playlist-youtube' do
  begin
    $mp.playlist_append_youtube params[:url]
    ''
  rescue NotCliveable
    $mp.playlist_append(params[:url], File.basename(params[:url]))
    ''
  end
end

post '/forward' do
  $mp.play_next
  ''
end

post '/pause' do
  $mp.toggle_pause
  ''
end

post '/stop' do
  $mp.stop
  ''
end

post '/playtime' do
  $mp.seek params[:pos]
  ''
end

post '/clear' do
  $mp.clear_playlist
  ''
end

post '/sub-select' do
  $mp.subtitle_cycle
  ''
end

post '/audio-select' do
  $mp.audio_cycle
  ''
end

get '/status' do
  headers 'Cache-Control' => 'no-cache'

  content_type :json

  {
    'percentPos'  => $mp.percent_pos,
    'playing'     => $mp.playing_title.to_s,
    'playlist'    => $mp.playlist.map { |f,t| t }
  }.to_json
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'

  $mp ||= MPlayer::Control.new
  $db ||= MediaDB.new REPO_PATH

  print "loading watcher..."
  w = Watcher.new

  w.when_directory_deleted { |p| puts "xxx #{p}"; $db.directory_deleted(p) }

  w.when_directory_moved { |old,new| puts "m #{old} #{new}"; $db.directory_moved(old,new) }

  w.when_file_created { |p| puts "cre #{p}"; $db.new_file(p) }
  w.when_file_deleted { |p| puts "del #{p}"; $db.kill_file(p) }

  w.watch(MEDIA_ROOT, EXCLUDE)
  puts "done!"

  Thread.new do
    begin
      w.go!
    rescue => e
      puts e.inspect
      puts e.backtrace
      exit()
    end
  end
end
