require 'iron_cache'
require 'base64'

module ActiveSupport
  module Cache
    class IronCache < ActiveSupport::Cache::Store

      def initialize(options = nil)
        super(options)

        @client = ::IronCache::Client.new(@options)

        extend ActiveSupport::Cache::Strategy::LocalCache
      end

      def increment(key, amount = 1, options = nil)
        with_namespace(key, options) do |cache, k|
          cache.increment(k, amount)
        end
      end

      def decrement(key, amount = 1, options = nil)
        with_namespace(key, options) do |cache, k|
          cache.increment(k, -amount)
        end
      end

      def clear(options = {})
        opts = {:namespace => 'rails_cache'}.merge(options || {})
        @client.post( "projects/#{ @client.project_id }/caches/#{ opts[:namespace] }/clear" )
      end

      protected

      def read_entry(key, options)
        item = nil

        with_namespace(key, options) do |cache, k|
          item = cache.get(k)
          item = item.value unless item.nil?
        end

        deserialize_entry(item)
      end

      def write_entry(key, entry, options)
        with_namespace(key, options) do |cache, k|
          cache.put(k, serialize_entry(entry, options), options)
        end

        true
      end

      def delete_entry(key, options)
        with_namespace(key, options) do |cache, k|
          cache.delete(k)
        end

        true
      end

      private

      def with_namespace(key, options)
        opts = {:namespace => 'rails_cache'}.merge(options || {})

        cache_name, key_name = namespaced_key(key, opts).split(':', 2)

        yield(@client.cache(cache_name), escape_key(key_name))
      end

      def escape_key(key)
        ekey = ::Base64.encode64(key).gsub("\n",'').gsub("/",'')

        if ekey.size > 250
          ekey = "#{ekey[0, 213]}:md5:#{Digest::MD5.hexdigest(ekey)}"
        end

        ekey
      end

      def deserialize_entry(raw_value)
        if raw_value
          raw_value = ::Base64.decode64(raw_value) rescue raw_value
          entry = Marshal.load(raw_value) rescue raw_value
          entry.is_a?(ActiveSupport::Cache::Entry) ? entry : ActiveSupport::Cache::Entry.new(entry)
        else
          nil
        end
      end

      def serialize_entry(entry, options)
        value = nil

        if options[:raw]
          if entry.respond_to?(:value)
            value = entry.value.to_s
          else
            value = entry.to_s
          end
        else
          value = ::Base64.encode64 Marshal.dump(entry)
        end
      end
    end
  end
end
