require 'thread'

require 'monitor'

class Status
  include MonitorMixin

  def initialize mp, io
    super()

    @io = io

    @prop_cond = self.new_cond

    @thread = Thread.new do
      puts "starting"
      @io.each_line { |line| self.got_line(line) }

      mp.stop unless mp.next # i suspect this will break horribly occasionally
    end
  end

  def got_line line
    self.synchronize do
      puts "<<< " + line
      if line.match /^ANS_PERCENT_POSITION=(.*)/
        @percent_pos = $1.to_i
        @prop_cond.signal
      end
    end
  end

  attr_reader :prop_cond, :percent_pos
end

class MPlayer
  attr_reader :playlist, :playing

  def initialize
    @playlist = []
    @io = nil
    @status = nil
  end

  def run cmd
    puts '>>> ' + cmd
    @io.puts cmd

    # running a command unpauses us (unless it was a pause command of course)
    @paused = false unless cmd == 'pause'
  end

  def pl_append file
    @playlist << file

    if !@playing
      play_file @playlist.first
    end
  end

  def pl_append_dir path
    if File.directory?(path + '/VIDEO_TS')
      pl_append(path)
    end

    Dir[path + '/*'].sort.each do |fn|
      if File.file? fn
        pl_append(fn)
      end
    end
  end

  def play_file path
    cmd = 'mplayer -fs -noconsolecontrols -slave -quiet'

    path_esc = %Q{ "#{path.gsub(/"/, '\"')}"}

    if File.directory?(path) and File.directory?(path + '/VIDEO_TS')
      cmd += ' -dvd-device'
      cmd += path_esc
      cmd += ' dvd://'
    else
      cmd += path_esc
    end

    puts cmd.inspect

    stop if @io
    @io = IO.popen cmd, "r+"
    @status = Status.new(self, @io)

    @paused = false
    @playing = path
  end

  def percent_pos
    return 0 unless @status
    # if it's paused, avoid running a command (it will unpause it)
    return @status.percent_pos if @paused

    @status.synchronize do
      run 'get_percent_pos'
      @status.prop_cond.wait
      @status.percent_pos
    end
  end

  def stop
    if @io and not @io.closed?
      run 'stop'
      @io.close
    end
  rescue Errno::EPIPE
    # whatever, we're good
  ensure
    @io = nil
    @playing = nil
    @status = nil
  end

  def next
    curr_idx = @playlist.index(@playing)
    return unless curr_idx

    @playlist = @playlist[(curr_idx+1)..-1]
    return if @playlist.empty?

    play_file @playlist.first
  end

  def toggle_pause
    run 'pause'
    @paused = !@paused
  end

  def seek pos
    if ["+"[0], "-"[0]].member? pos[0]
      pos = pos[1..-1]
      run "seek #{pos} 0"
    elsif pos[-1].chr == '%'
      pos = pos[0..-2]
      run "seek #{pos} 1"
    else
      run "seek #{pos} 2"
    end
  end
end
