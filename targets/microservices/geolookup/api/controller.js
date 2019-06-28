'use strict';

var properties = require('../package.json')
const request = require('request');

var controllers = {
  search: function(req, res) {
    var q = req.params.q

    request({
      url: 'https://nominatim.openstreetmap.org/search?format=json&q='+q,
      headers: {
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:63.0) Gecko/20100101 Firefox/63.0',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'en-US,en;q=0.5',
        'accept-encoding': 'gzip, deflate, br'
      }
    }, (err,resp,body) => {
        var d = JSON.parse(body)
        if(d.length < 1)
        {
          res.status(500)
          res.render('error', { error: "No results satisfied query '" + q + "'." })
        }
        else
        {
          var result = {
           latitude: d[0].lat,
           longitude: d[0].lon,
           _raw: d[0]
          };
          res.json(result);
        }
      });
  }
};

module.exports = controllers;
