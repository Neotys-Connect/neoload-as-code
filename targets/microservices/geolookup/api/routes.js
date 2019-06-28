'use strict';

var controller = require('./controller');

module.exports = function(app) {
   app.route('/search')
       .get(controller.search);
};
