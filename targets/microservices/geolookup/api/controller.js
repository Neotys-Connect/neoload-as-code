'use strict';

const request = require('request');
const argv = require('yargs').argv
const log = require('./log').newInstance(argv.log_level);
const fs = require('fs');

log.always('Started with the following options: ' + JSON.stringify(argv))

log.always('Logging initialized at level['+log.level+']')

var cache = require('./cache');
cache.CACHE_PREFIX = 'geolookup_';
cache.init(argv,log)

var __searchCount=0
var __httpCount=0
var __errorCount=0

var controller = {
  search: function(req, res) {
    __searchCount++

    var noCache = (req.query.cache && req.query.cache=='false')

    var fProcess = function(q) {
      if(noCache)
      {
        log.info('Received query '+req.method+' ['+q+'], noCache=true')
        fHttp(q);
      }
      else
        cache.get(q,(ret) => {
          var cached = (ret != undefined);
          log.info('Received query ['+q+'], fulfilling via '+(cached?'cache':'http'))
          if(cached)
            res.json(JSON.parse(ret));
          else
            fHttp(q)
        });
    };
    var fError = (code,json) => {
      __errorCount++
      res.status(code)
      res.json(json)
    }

    var fIntake = () => {
      if(req.method=="POST")
      {
        noCache = true;
        let body = [];
        req.on('data', (chunk) => {
          body.push(chunk);
        }).on('end', () => {
          body = Buffer.concat(body).toString();

          var ask = null;
          try {
            ask = JSON.parse(body)
          } catch(err) {
            fError(400,{ error: {
              message: "Content posted as request body could not be parsed as JSON."
            }})
          }
          if(ask == null) {}
          else {
            var q = undefined;
            if(ask.city)
              q = ask.city;
            else if(ask.query_encoded)
              q = ask.query_encoded;
            if(q!=undefined && (q+"").trim().length > 0)
              fProcess(q)
            else
            {
              fError(400,{ error: {
                message: "JSON body must contain either a 'city' or 'query_encoded' property with a non-empty value."
              }})
            }
          }
        });

      } else {
        fProcess(req.query.q)
      }
    }; // fIntake

    var fHttp = (q) => {
      __httpCount++

      request({
        url: 'https://nominatim.openstreetmap.org/search?format=json&q='+q,
        headers: {
          'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:63.0) Gecko/20100101 Firefox/63.0',
          'accept': 'application/json, text/plain, */*',
          'accept-language': 'en-US,en;q=0.5',
          'accept-encoding': 'gzip, deflate, br'
        }
      }, (err,resp,body) => {
        if(err)
        {
          log.debug(JSON.stringify(err))
          if(err.syscall=="getaddrinfo")
            fError(500,{ error: {
              message: 'Could not connect to the geo lookup 3rd party provider and query has not been cached.'
            }})
          else
            fError(500,{ error: err })
        }
        else
        {
          var d = null;
          var errdetail = null;
          if(body != null && (body+"").trim().indexOf('<')==0)
            errdetail = body;
          else
          {
            try { d = JSON.parse(body) }
            catch(ex) {
              errdetail = JSON.stringify(ex)
            }
          }
          if(errdetail != null) {
            fError(500,{ error: "Error from openstreetmaps: "+errdetail })
          } else {
            if(d != null) {
              if(d.length < 1)
              {
                fError(500,{ error: "No results satisfied query '" + q + "'." })
              }
              else
              {
                var result = {
                 latitude: d[0].lat,
                 longitude: d[0].lon,
                 _raw: d[0]
                };
                if(cache.isEnabled)
                  cache.set(q, JSON.stringify(result))
                res.json(result);
              }
            }
          }
        }
      });
    };

    fIntake()
  },
  clearCache: (req,res) => { cache.clear((ret) => { res.json(ret)}); },
  listCacheKeys: (req,res) => { cache.listKeys((ret) => { res.json(ret)}); },
  deleteNonPrefixKeys: (req,res) => { cache.deleteNonPrefixKeys((ret) => { res.json(ret)}); },
  __updateReadoutTimeoutId: 0,

  createOAuthToken: (req,res) => {
    res.json({"access_token":"4R1w16n8uDjpKyKSAIhmQ2MvGIgaxhi3RVxCMW0B","token_type":"Bearer","expires":1542036163,"expires_in":3600})
  },
  getPosts: (req,res) => {
    res.json({"allowed_privileges":["read","search"]})
  },
  getGeos: (req,res) => {
    fs.readFile(__dirname+'/../js/geojson.js', "utf8", function(err, data){
        if(err) throw err;
        res.json(JSON.parse(data));
    });
  },
};

function updateReadout(ctrl) {
  if(ctrl.__updateReadoutTimeoutId > 0) clearTimeout(ctrl.__updateReadoutTimeoutId);
  ctrl.__updateReadoutTimeoutId = setTimeout(() => {
    log.always('Incoming search count['+__searchCount+'], HTTP count['+__httpCount+'], error count['+__errorCount+']')
    updateReadout(ctrl);
  },10000,ctrl)
}
updateReadout(controller);

module.exports = controller;
