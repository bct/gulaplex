#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'haml'

MEDIA_ROOT = '/media'
SNES_ROOT = '/media/software/roms/snes'

class MPlayer
  attr_reader :playlist

  def initialize
    @playing = nil
    @paused = false
    @going = false
    @playlist = []
    @percent_pos = 0
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
      puts "<< " + line.inspect
      if line.match /^ANS_PERCENT_POSITION=(.*)/
        @percent_pos = $1
      elsif line.match /^Starting playback\.\.\./
        @going = true
      end
    end

    # this needs to be outside the lock because otherwise it deadlocks
    if line == "\n" and @going
      @going = false
      puts "---DONE---"
      play_next()
    end
  end

  def run cmd
    puts ">> " + cmd.inspect
    @paused = false # all commands seem to unpause this.
    @io.puts cmd
  end

  def play_next
    next_idx = @playlist.index(@playing)
    @playing = nil
    return unless next_idx

    next_file = @playlist[next_idx + 1]
    return unless next_file

    play_file next_file
  end

  def play_file(path, append = false)
    @going = false

    @io_lock.synchronize do
      @playing = path
      run %Q{loadfile '#{path.gsub /'/, %q{\\\'}}' 0}
    end

    # run "sub_select -1"
  end

  def pl_append path
    @playlist << path

    if @playing.nil?
      play_file @playlist.first
    end
  end

  def pl_append_dir(path)
    Dir[path + '/*'].sort.each do |fn|
      if File.file? fn
        pl_append(fn)
      end
    end
  end

  # +1: forward
  # -1: backward
  def step(dir)
    play_next
  end

  def toggle_pause
    was_paused = @paused
    run 'pause'
    @paused = !was_paused
  end

  def seek_rel pos
    run "seek #{pos} 0"
  end

  def seek_time pos
    run "seek #{pos} 2"
  end

  def seek_percent percent
    run "seek #{percent} 1"
  end

  def stop
    run 'stop'
    @playing = nil
    @playlist = []
  end

  def playing
    @io_lock.synchronize { @playing }
  end

  def percent_pos
    return 0 unless playing
    return @percent_pos if @paused

    @io_lock.synchronize do
      run 'get_percent_pos'
    end
    @percent_pos
  end
end

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
  $mp.step 1
  redirect request.referer
end

post '/backward' do
  $mp.step -1
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
  $mp.percent_pos
end

post '/playtime' do
  if ['+', '-'].map { |x| x[0] }.member? params[:pos][0]
    $mp.seek_rel params[:pos]
  elsif params[:pos][-1].chr == '%'
    $mp.seek_percent params[:pos][0..-2]
  else
    $mp.seek_time params[:pos]
  end
  redirect request.referer
end

if __FILE__ == $0
  ENV['DISPLAY'] = ':0'

  $mp ||= MPlayer.new
  $mp.start
end
