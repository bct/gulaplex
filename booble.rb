#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

$playing = nil

def start_mplayer
  $io = IO.popen "mplayer -fs -noconsolecontrols -idle -slave -really-quiet", 'r+'
end

def play_file(path, append = false)
  $io.puts %Q{loadfile '#{path.sub /'/, %q{\\\'}}' #{append ? 1 : 0 }}
end

def play_dir(path)
  Dir[ROOT + path + '/*'].sort.each do |fn|
    if File.file? fn
      play_file(fn, true)
    end
  end
end

def toggle_pause
  $io.puts "pause"
end

def stop_video
  $io.puts "stop"
end

def show_playing()
=begin
  $io.puts "get_file_name"
  $io.readline
=end
  "THIS IS BROKEN"
end

YOUTUBE_FILE = "/tmp/booble-youtube.flv"

def play_youtube(url)
  File.delete(YOUTUBE_FILE) rescue nil
  system("clive", "-o", YOUTUBE_FILE, url)
  $io.puts("loadfile " + YOUTUBE_FILE)
end

ROOT = '/media'

def show_path path
  @ds, @fs = Dir[ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub ROOT, '' }
  @fs.map! { |fn| fn.sub ROOT, '' }

  @ds = ['./..'] + @ds unless ['/', ''].member? path

  haml <<END
%style{:type => 'text/css'}
  :plain
    html { margin: 0 auto; }
    body { width: 80%; }
    p { }
    .inline { display: inline; }

#youtube
  %form{:method => 'post', :action => '/youtube'}
    youtube URL:
    %input{:name => 'url'}
    %input{:type => 'submit', :value => '>'}

#status
  Playing:
  = show_playing()
  %form{:method => 'post', :action => '/pause'}
    %input{:type => 'submit', :value => 'play/pause'}
  %form{:method => 'post', :action => '/stop'}
    %input{:type => 'submit', :value => 'stop'}

%ul
- @ds.sort.each do |d|
  %li
    %form.inline{:method => 'post', :action => '/playdir'}
      %input{:type => 'hidden', :name => 'path', :value => d }
      %input{:type => 'submit', :value => '>'}

    %a{:href => d }= d

%ul
- @fs.sort.each do |f|
  %li
    %form.inline{:method => 'post', :action => '/playfile'}
      %input{:type => 'hidden', :name => 'path', :value => f }
      %input{:type => 'submit', :value => '>'}

    %span= f
END
end

get '/' do
  show_path ''
end

get /\/(.*)/ do |path|
  show_path('/' + path)
end

post '/playfile' do
  play_file(ROOT + params[:path])
  redirect request.referer
end

post '/playdir' do
  play_dir params[:path]
  redirect request.referer
end

post '/pause' do
  toggle_pause
  redirect request.referer
end

post '/stop' do
  stop_video
  redirect request.referer
end

post '/youtube' do
  play_youtube params[:url]
  redirect request.referer
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'
  start_mplayer()
end
