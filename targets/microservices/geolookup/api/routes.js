'use strict';

var controller = require('./controller');
var express = require('express')

module.exports = function(app) {
  app.route('/search')
     .get(controller.search)
     .post(controller.search)
  app.route('/clearCache')
    .get(controller.clearCache)
  app.route('/listCacheKeys')
    .get(controller.listCacheKeys)
  app.route('/deleteNonPrefixKeys')
    .get(controller.deleteNonPrefixKeys)

  app.use('/js', express.static(__dirname+'/../js')) // currently in the contxt of /api
  app.route('/platform/oauth/token')
    .post(controller.createOAuthToken)
  app.route('/platform/api/v3/posts')
     .get(controller.getPosts)
  app.route('/platform/api/v3/posts/geojson')
    .get(controller.getGeos)
};
