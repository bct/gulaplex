#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

ROOT = '/media'

class MPlayer
  attr_reader :playlist

  def initialize
    @playing = nil
    @playlist = []
  end

  def start
    return if @io   # TODO: check that the pipe's actually still open.

    @io = IO.popen "mplayer -fs -noconsolecontrols -idle -slave -quiet", 'r+'

    @io_thread = Thread.new do
      loop do
        got_line(@io.readline)
      end
    end

    @io_lock = Mutex.new
  end

  def got_line line
    @io_lock.synchronize do
      puts line
      if line.match /^Playing (.*)\./
        puts $1
        @playing = $1
      end
    end
  end

  def run cmd
    @io and @io.puts cmd
  end

  def play_file(path, append = false)
    run %Q{loadfile '#{path.gsub /'/, %q{\\\'}}' #{append ? 1 : 0 }}
    # run "sub_select -1"

    if append
      @playlist << path
    else
      @playlist = [ path ]
    end
  end

  def play_dir(path)
    Dir[ROOT + path + '/*'].sort.each do |fn|
      if File.file? fn
        play_file(fn, true)
      end
    end
  end

  # +1: forward
  # -1: backward
  def step(dir)
    run "pt_step #{dir}"
  end

  def toggle_pause
    run 'pause'
  end

  def seek_rel length
    run "seek #{length} 0"
  end

  def seek_time length
    run "seek #{length} 2"
  end

  def stop
    run 'stop'
    @playing = nil
  end

  def playing
    @io_lock.synchronize { @playing }
  end
end

def show_path path
  @ds, @fs = Dir[ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub ROOT, '' }
  @fs.map! { |fn| fn.sub ROOT, '' }

  @path = path

  haml <<END
%style{:type => 'text/css'}
  :plain
    body { margin: 5em auto; width: 80%; background: white; }
    #status { padding: 1em; border: 1px solid black; }
    .button, .inline { display: inline; }
    input[type=submit] { background: #ccc; border: 1px solid black; }
    #playlist { float: right; width: 30%; border: 1px solid black; }

#playlist
  %strong Playlist
  %ul
    - $mp.playlist.each do |file|
      %li= file

#status
  #playing
    Playing:
    = $mp.playing()
  %form.button{:method => 'post', :action => '/pause'}
    %input{:type => 'submit', :value => 'play/pause'}
  %form.button{:method => 'post', :action => '/stop'}
    %input{:type => 'submit', :value => 'stop'}
  %form.button{:method => 'post', :action => '/backward'}
    %input{:type => 'submit', :value => '<<'}
  %form.button{:method => 'post', :action => '/forward'}
    %input{:type => 'submit', :value => '>>'}
  %form.button{:method => 'post', :action => '/seek'}
    %input{:type => 'submit', :name => 'length', :value => '-10'}
    %input{:type => 'submit', :name => 'length', :value => '+10'}
  %form{:method => 'post', :action => '/seek'}
    Seek to time (s):
    %input{:name => 'length'}
    %input{:type => 'submit', :value => 'seek'}

%ul
  %li
    %a{:href => '/' + @path.split('/')[0..-2].reject{|x|x.empty?}.join('/') } updir
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
  $mp.play_file(ROOT + params[:path])
  redirect request.referer
end

post '/playdir' do
  $mp.play_dir params[:path]
  redirect request.referer
end

post '/forward' do
  $mp.step 1
  redirect request.referer
end

post '/backward' do
  $mp.step -1
  redirect request.referer
end

post '/pause' do
  $mp.toggle_pause
  redirect request.referer
end

post '/stop' do
  $mp.stop
  redirect request.referer
end

post '/seek' do
  if ['+', '-'].map { |x| x[0] }.member? params[:length][0]
    $mp.seek_rel params[:length]
  else
    $mp.seek_time params[:length]
  end
  redirect request.referer
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'

  $mp ||= MPlayer.new
  $mp.start
end
