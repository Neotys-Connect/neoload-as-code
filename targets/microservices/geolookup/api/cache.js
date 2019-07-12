'use strict';

const redis = require('redis');
require('redis-delete-wildcard')(redis);

var cache = {
  isEnabled: false,
  client: null,
  KEY_PREFIX: '',
  init: function(argv,log) {
    if(argv.redis) log.always('Using redis client')
    var server = "localhost";
    var port = 6379;
    if(argv.redis != undefined) {
      if(!isNaN(argv.redis))
        port = argv.redis;
      else {
        var parts = argv.redis.split(':')
        server = parts[0];
        if(parts.length>1 && !isNaN(parts[1]))
          port = parts[1]
      }
      this.isEnabled = true;
    }
    if(this.isEnabled)
    {
      this.client = redis.createClient(port,server)
    }
  },
  get: function(key,callback) {
    if(!this.isEnabled)
      callback(undefined)
    else
    {
      this.client.get(this.KEY_PREFIX+key, (err,data) => {
        if(err) throw err;
        var cached = (data != null)
        if(cached)
          callback(data)
        else
          callback(undefined)
      });
    }
  },
  set: function(key,value) {
    if(this.isEnabled)
      this.client.set(this.KEY_PREFIX+key,value);
  },
  clear: function(callback) {
    if(!this.isEnabled)
      callback({caching:false});
    else
    {
      log.always('Clearing cache, prefix: '+this.KEY_PREFIX)
      this.client.delwild('pattern:'+this.KEY_PREFIX+'*', function(err, numberDeletedKeys) {
        var ret = {}
        if(err) ret.error = err;
        ret.numberDeletedKeys = numberDeletedKeys;
        callback(ret);
        log.always('deleted: '+numberDeletedKeys);
      });
    }
  },
  listKeys: function(callback) {
    if(!this.isEnabled)
      callback({caching:false})
    else
    {
      this.client.keys(this.KEY_PREFIX+'*', function (err, keys) {
        var ret = {}
        if(err) ret.error = err;
        ret.keys = keys;
        callback(ret);
      });
    }
  },
  deleteNonPrefixKeys: function(callback) {
    if(!this.isEnabled)
      callback({caching:false});
    else
    {
      log.always('Clearing non-prefixed keys, prefix: '+this.KEY_PREFIX)
      this.client.delwild('pattern:'+this.KEY_PREFIX+'*', function(err, numberDeletedKeys) {
        var ret = {}
        if(err) ret.error = err;
        ret.numberDeletedKeys = numberDeletedKeys;
        callback(ret);
        log.always('deleted: '+numberDeletedKeys);
      });
    }
  },
}

module.exports = cache
