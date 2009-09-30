#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

require 'mplayer'

require 'json'

MEDIA_ROOT  = '/media'
SNES_ROOT   = '/media/software/roms/snes'
COMMIT_ID   = `git log -n1 --oneline | cut -f1 -d\\ `

def show_media_path path
  @root_tree = json_media_path(path)
  @slider_pos = $mp.percent_pos

  haml :media_path
end

def json_media_path path
  dir = MEDIA_ROOT + path

  entries = Dir.entries(dir)
  entries.delete '.'
  entries.delete '..'

  entries = entries.map { |x| File.join path, x }

  ds, fs = entries.partition do |x|
    full_path = File.join(MEDIA_ROOT, x)

    # treat it as a directory if it is a directory and it's not a dvd directory
    File.directory?(full_path) and not File.directory?(File.join(full_path, 'VIDEO_TS'))
  end
  { 'directories' => ds.sort, 'files' => fs.sort }.to_json
end

def show_snes_path path
  @ds, @fs = Dir[MEDIA_ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub SNES_ROOT, '' }
  @fs.map! { |fn| fn.sub SNES_ROOT, '' }

  @path = path

  haml :snes_path
end

get '/' do
  redirect '/media/'
end

get /media\/(.*)/ do |path|
  if request.xhr?
    content_type :json

    json_media_path(path)
  else
    show_media_path(path)
  end
end

get /snes\/(.*)/ do |path|
  show_snes_path('/' + path)
end

post '/playfile' do
  $mp.playlist_append(MEDIA_ROOT + params[:path], File.basename(params[:path]))
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

post '/snes/playing' do
  $mp.stop
  system('snes9x', '-joydev1', '/dev/input/js0', MEDIA_ROOT + params[:path])
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
  content_type :json

  {
    'percentPos'  => $mp.percent_pos.to_s,
    'playing'     => $mp.playing_title.to_s,
    'playlist'    => $mp.playlist.map { |f,t| t }
  }.to_json
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'

  $mp ||= MPlayer::Control.new
end
