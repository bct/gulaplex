require 'thread'
require 'monitor'

module MPlayer
  class Control
    def initialize
      @status = Status.new(self)
    end

    def got_line line
      puts line.inspect
      if line.match /^ANS_PERCENT_POSITION=(.*)/
        @status.percent_pos = $1.to_i
      end
    end

    def play_next stop_first = true
      pl = @status.playlist

      if pl.empty?
        @status.playing = nil
        @io = nil
        return
      end

      play_file pl.shift, stop_first
      @status.playlist = pl
    end

    def stop
      @status.playing = nil
      run 'stop'
      @io.close
      @io = nil
    end

    def play_file path, stop_first = false
      self.stop if @status.playing and stop_first

      cmd = 'mplayer -fs -noconsolecontrols -slave -quiet -prefer-ipv4'
      path_esc = %Q{ "#{path.gsub(/"/, '\"')}"}

      if File.directory?(path) and File.directory?(path + '/VIDEO_TS')
        cmd += ' -dvd-device'
        cmd += path_esc
        cmd += ' dvd://'
      else
        cmd += path_esc
      end

      @io = IO.popen cmd, "r+"
      @status.playing = path

      @thread = Thread.new do
        @io.each_line do |line|
          self.got_line(line)
        end

        play_next(false) if @status.playing
      end
    end

    def playlist_append path
      if @status.playing.nil?
        play_file path
      else
        pl = @status.playlist
        pl << path
        @status.playlist = pl
      end
    end

    def playlist_append_dir path
      if File.directory?(path + '/VIDEO_TS')
        pl_append(path)
      else
        Dir[path + '/*'].sort.each do |fn|
          pl_append(fn) if File.file? fn
        end
      end
    end

    def playlist_append_youtube html_url
      p html_url

      cclive_csv = `cclive --emit-csv "#{html_url}" | tail -n1`

      p cclive_csv

      flv_url = cclive_csv.split(/","/).last

      p flv_url

      playlist_append(flv_url)
    end

    def run cmd
      @status.unpaused unless cmd == 'pause'
      @io.puts cmd
    end

    def percent_pos
      return 0 unless @io
      @status.percent_pos
    end

    def subtitle_select
      run 'sub_select'
    end

    def clear_playlist
      @status.playlist = []
    end

    def seek pos
      if ["+", "-"].member? pos[0].chr
        pos = pos[1..-1]
        run "seek #{pos} 0"
      elsif pos[-1].chr == '%'
        pos = pos[0..-2]
        run "seek #{pos} 1"
      else
        run "seek #{pos} 2"
      end
    end

    def toggle_pause
      run 'pause'
      @status.toggle_paused
    end

    def playlist; @status.playlist; end
    def playing; @status.playing; end
  end

  class Status
    include MonitorMixin

    def initialize control
      @control = control

      @status = { :percent_pos => 0,
                  :playlist => [],
                  :playing => nil,
                  :paused => false }

      @status[:playlist].freeze

      @status_update = self.new_cond

      super()
    end

    def percent_pos= pp
      synchronize do
        @status[:percent_pos] = pp
        @status_update.signal
      end
    end

    def percent_pos
      synchronize do
        unless @status[:paused]
          @control.run 'get_percent_pos'
          @status_update.wait
        end
        @status[:percent_pos]
      end
    end

    def playing
      synchronize do
        @status[:playing]
      end
    end

    def playing= p
      synchronize do
        @status[:playing] = p
        @status_update.signal
      end
    end

    def playlist
      synchronize do
        @status[:playlist].dup
      end
    end

    def playlist= pl
      synchronize do
        pl.freeze
        @status[:playlist] = pl
      end
    end

    def unpaused
      synchronize do
        @status[:paused] = false
      end
    end

    def toggle_paused
      synchronize do
        @status[:paused] = !@status[:paused]
      end
    end
  end
end
