#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

require 'mplayer'

MEDIA_ROOT = '/media'
SNES_ROOT = '/media/software/roms/snes'

def show_media_path path
  @ds, @fs = Dir[MEDIA_ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub MEDIA_ROOT, '' }
  @fs.map! { |fn| fn.sub MEDIA_ROOT, '' }

  @path = path

  @slider_pos = $mp.percent_pos

  haml :media_path
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
  show_media_path('/' + path)
end

get /snes\/(.*)/ do |path|
  show_snes_path('/' + path)
end

post '/playfile' do
  $mp.pl_append(MEDIA_ROOT + params[:path])
  redirect request.referer, 303
end

post '/playdir' do
  $mp.pl_append_dir params[:path]
  redirect request.referer
end

post '/forward' do
  $mp.next
  redirect request.referer
end

post '/backward' do
  $mp.prev
  redirect request.referer
end

post '/pause' do
  $mp.toggle_pause
  redirect request.referer, 303
end

post '/stop' do
  $mp.stop
  redirect request.referer
end

post '/snes/playing' do
  $mp.stop
  system('snes9x', '-joydev1', '/dev/input/js0', MEDIA_ROOT + params[:path])
  redirect request.referer
end

get '/playtime' do
  $mp.percent_pos.to_s
end

post '/playtime' do
  $mp.seek params[:pos]
  redirect request.referer
end

post '/clear' do
  $mp.stop
  $mp.playlist.clear
  redirect request.referer
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'

  $mp ||= MPlayer.new
end
