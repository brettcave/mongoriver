module Mongoriver

  # A variant of Tailer that automatically loads and persists the
  # "last timestamp processes" state. See PersistentTailer for a
  # concrete subclass that uses the same mongod you are already
  # tailing.

  class AbstractPersistentTailer < Tailer
    def initialize(upstream, type, opts={})
      raise "You can't instantiate an AbstractPersistentTailer -- did you want PersistentTailer? " if self.class == AbstractPersistentTailer
      super(upstream, type)

      @last_saved       = nil
      @batch            = opts[:batch]
      @last_read        = nil
    end

    def tail(opts={})
      opts[:from] ||= read_timestamp
      super(opts)
    end

    def stream(limit=nil)
      start_time = BSON::Timestamp.new(connection_config['localTime'].to_i, 0)
      found_entry = false

      ret = super(limit) do |entry|
        yield entry
        found_entry = true
        @last_read = entry['ts']
        maybe_save_timestamp unless @batch
      end

      if !found_entry && !ret
        @last_read = start_time
        maybe_save_timestamp unless @batch
      end

      return ret
    end

    def batch_done
      raise "You must specify :batch => true to use the batch-processing interface." unless @batch
      maybe_save_timestamp
    end

    def read_timestamp
      raise "read_timestamp unimplemented!"
    end

    def write_timestamp
      raise "save_timestamp unimplemented!"
    end

    def save_timestamp
      write_timestamp(@last_read)
      @last_saved = @last_read
      log.info("Saved timestamp: #{@last_saved} (#{Time.at(@last_saved.seconds)})")
    end

    def maybe_save_timestamp
      # Write timestamps once a minute
      return unless @last_read
      save_timestamp if @last_saved.nil? || (@last_read.seconds - @last_saved.seconds) > 60
    end
  end
end
