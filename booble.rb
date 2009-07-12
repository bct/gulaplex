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
      puts line
      if line.match /^Playing (.*)\./
        @playing = $1
      elsif line.match /^ANS_PERCENT_POSITION=(.*)/
        @percent_pos = $1
      end
    end
  end

  def run cmd
    @io.puts cmd
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
    Dir[MEDIA_ROOT + path + '/*'].sort.each do |fn|
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

    run 'get_percent_pos'
    @io_lock.synchronize do
      @percent_pos
    end
  end
end

def show_media_path path
  @ds, @fs = Dir[MEDIA_ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub MEDIA_ROOT, '' }
  @fs.map! { |fn| fn.sub MEDIA_ROOT, '' }

  @path = path

  @slider_pos = $mp.percent_pos

  haml <<END
%style{:type => 'text/css'}
  :plain
    body { margin: 5em auto; width: 80%; background: white; }
    #status { padding: 1em; border: 1px solid black; }
    .button, .inline { display: inline; }
    input[type=submit] { background: #ccc; border: 1px solid black; }
    #playlist { float: right; width: 30%; border: 1px solid black; }
    #slider { margin: 1em }

%link{:rel => 'stylesheet', :type => 'text/css', :href => '/css/theme/jquery-ui-1.7.2.custom.css'}

%script{:type => 'text/javascript', :src => '/js/jquery-1.3.2.min.js' }
%script{:type => 'text/javascript', :src => '/js/jquery-ui-1.7.2.custom.min.js' }

%script{:type => 'text/javascript'}
  var sliderPos = #{@slider_pos};
  var updatePeriod = 10 * 1000;

  :plain
    function seekPercent(percent) {
      $.post("/playtime", { pos: percent + "%"});
    }

    function updatePercent() {
      $.get('/playtime', {}, function(data, textStatus) {
        $("#slider").slider('option', 'value', data);
      });

      setTimeout(updatePercent, updatePeriod);
    }

    $(document).ready(function(){
      $("#slider").slider({
        value: sliderPos,
        stop: function(event, ui) { seekPercent(ui.value); }
      });

      setTimeout(updatePercent, updatePeriod);
    });

%ul
  %li
    %a{:href => '/media/'} media
  %li
    %a{:href => '/snes/'} snes

#slider

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
  %form.button{:method => 'post', :action => '/playtime'}
    %input{:type => 'submit', :name => 'pos', :value => '-10'}
    %input{:type => 'submit', :name => 'pos', :value => '+10'}

%ul
  %li
    %a{:href => '/media/' + @path.split('/')[0..-2].reject{|x|x.empty?}.join('/') } updir
  - @ds.sort.each do |d|
    %li
      %form.inline{:method => 'post', :action => '/playdir'}
        %input{:type => 'hidden', :name => 'path', :value => '/media' + d }
        %input{:type => 'submit', :value => '>'}

      %a{:href => '/media' + d }= d

%ul
  - @fs.sort.each do |f|
    %li
      %form.inline{:method => 'post', :action => '/playfile'}
        %input{:type => 'hidden', :name => 'path', :value => f }
        %input{:type => 'submit', :value => '>'}

      %span= f
END
end

def show_snes_path path
  @ds, @fs = Dir[MEDIA_ROOT + path + '/*'].partition { |x| File.directory? x }

  @ds.map! { |fn| fn.sub SNES_ROOT, '' }
  @fs.map! { |fn| fn.sub SNES_ROOT, '' }

  @path = path

  haml <<END
%ul
  %li
    %a{:href => '/media/' + @path.split('/')[0..-2].reject{|x|x.empty?}.join('/') } updir
  - @ds.sort.each do |d|
    %li
      %a{:href => '/media' + d }= d

%ul
  - @fs.sort.each do |f|
    %li
      %form.inline{:method => 'post', :action => '/snes/playing'}
        %input{:type => 'hidden', :name => 'rom', :value => f }
        %input{:type => 'submit', :value => '>'}

      %span= f
END
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
  $mp.play_file(MEDIA_ROOT + params[:path])
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
