require 'thread'
require 'monitor'
require 'timeout'

# the given url could not be handled by clive
class NotCliveable < Exception; end

module MPlayer
  class Control
    def initialize
      @status = Status.new(self)
    end

    def got_line line
      if line.match /^ANS_PERCENT_POSITION=(.*)/
        @status.percent_pos = $1.to_i
      elsif line.match /^ANS_META_TITLE='(.*)'/
        @status.title = $1.strip
      elsif line.match /^ANS_META_ARTIST='(.*)'/
        @status.artist = $1.strip
      end
    end

    def play_next stop_first = true
      pl = @status.playlist

      if pl.empty?
        if @io and @io.closed?
          @status.playing = nil
          @io = nil
        end
        return # nothing's next, ignore the command
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

    def play_file file_data, stop_first = false
      self.stop if @status.playing and stop_first

      path = file_data[0]
      cmd = 'mplayer -fs -noconsolecontrols -slave -quiet -prefer-ipv4 -af volnorm'
      path_esc = %Q{ "#{path.gsub(/"/, '\"')}"}

      if File.directory?(path) and File.directory?(path + '/VIDEO_TS')
        cmd += ' -dvd-device'
        cmd += path_esc
        cmd += ' dvd://'
      else
        cmd += path_esc
      end

      @io = IO.popen cmd, "r+"

      @thread = Thread.new do
        @io.each_line do |line|
          self.got_line(line)
        end

        @io.close
        play_next(false) if @status.playing
      end

      @status.playing = file_data
    end

    def playlist_append path, title
      if @status.playing.nil?
        play_file [path, title]
      else
        pl = @status.playlist
        pl << [path, title]
        @status.playlist = pl
      end
    end

    def playlist_append_dir path
      if File.directory?(path + '/VIDEO_TS')
        playlist_append(path, File.basename(path))
      else
        Dir[path + '/*'].sort.each do |fn|
          playlist_append(fn, File.basename(fn)) if File.file? fn
        end
      end
    end

    def playlist_append_youtube html_url
      p html_url

      clive_csv = `cclive --emit-csv "#{html_url}" | tail -n1`

      p clive_csv
      raise NotCliveable if clive_csv.match /^FAILED: /

      orig_url, title_fname, flv_url,  size = clive_csv.split(/","/)

      p flv_url

      playlist_append(flv_url, title_fname)
    end

    def run cmd
      @status.unpaused unless cmd == 'pause'
      @io.puts cmd
    end

    def percent_pos
      return 0 unless @io
      @status.percent_pos
    end

    def subtitle_cycle
      run 'sub_select'
    end

    def audio_cycle
      run 'switch_audio -1'
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

    def playing_title
      if @io and (title = @status.title) and (artist = @status.artist)
        return artist + ' - ' + title
      end

      p = self.playing
      p[1] if p
    end
  end

  class Status
    include MonitorMixin

    def initialize control
      @control = control

      @status = { :playlist => [] }
      @status[:playlist].freeze

      self.reset_metadata!

      @status_update = self.new_cond

      super()
    end

    def reset_metadata!
      @status[:percent_pos] = 0
      @status[:artist]      = nil
      @status[:title]       = nil
      @status[:playing]     = nil
      @status[:paused]      = false
    end

    def percent_pos= pp
      synchronize do
        @status[:percent_pos] = pp
        @status_update.signal
      end
    end

    def percent_pos
      # FIXME: i don't like this timeout. also it raises an exception.
      Timeout::timeout(1) do
        synchronize do
          unless @status[:paused]
            @control.run 'get_percent_pos'
            @status_update.wait
          end
          @status[:percent_pos]
        end
      end
    end

    def title= t
      synchronize do
        t = nil if t.empty?
        @status[:title] = t
        @status_update.signal
      end
    end

    def title
      return @status[:title] if @status[:title]

      # FIXME: i don't like this timeout. also it raises an exception.
      Timeout::timeout(1) do
        synchronize do
          unless @status[:paused] # this could cause weirdness.
            @control.run 'get_meta_title'
            @status_update.wait
          end
          @status[:title]
        end
      end
    end

    def artist= ar
      synchronize do
        @status[:artist] = ar
        @status_update.signal
      end
    end

    def artist
      return @status[:artist] if @status[:artist]

      # FIXME: i don't like this timeout. also it raises an exception.
      Timeout::timeout(1) do
        synchronize do
          unless @status[:paused] # this could cause weirdness.
            @control.run 'get_meta_artist'
            @status_update.wait
          end
          @status[:artist]
        end
      end
    end

    def playing
      synchronize { @status[:playing] }
    end

    def playing= p
      synchronize do
        # wipe the data for any item that might have been playing
        self.reset_metadata!

        @status[:playing] = p
        @status_update.signal
      end
    end

    def playlist
      synchronize { @status[:playlist].dup }
    end

    def playlist= pl
      synchronize do
        pl.freeze
        @status[:playlist] = pl
      end
    end

    def unpaused
      synchronize { @status[:paused] = false }
    end

    def toggle_paused
      synchronize { @status[:paused] = !@status[:paused] }
    end
  end
end
