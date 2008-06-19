module BackgrounDRb
  # Will use Memcache if specified in configuration file
  # otherwise it will use in memory hash
  class ResultStorage
    attr_accessor :storage_type
    def initalize storage_type = nil
      @cache = (storage_type == :memcache) ? memcache_instance : {}
    end

    def [] key
      @cache[key]
    end

    def []= key,value
      @cache[key,value]
    end

    def memcache_instance
      require 'memcache'
      memcache_options = {
        :c_threshold => 10_000,
        :compression => true,
        :debug => false,
        :namespace => 'backgroundrb_result_hash',
        :readonly => false,
        :urlencode => false
      }
      t_cache = MemCache.new(memcache_options)
      t_cache.servers = CONFIG_FILE[:memcache].split(',')
      t_cache
    end
  end
end
