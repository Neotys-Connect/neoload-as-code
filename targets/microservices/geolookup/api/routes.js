'use strict';

var controller = require('./controller');

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
};
