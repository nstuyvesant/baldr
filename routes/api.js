/*
  Route file for /api

  Using the express-promise-router makes Express 4 more like 5 - supporting
  promises and simpler error handling.

  Putting the connection between the routes and controller in this file
  allows us to visualize mappings easier, inject middleware (like authenticate),
  and have an entry point for integration testing.

  Server integration tests (using supertest) should call this file.
*/

const Router = require('express-promise-router')
const authenticate = require('../middleware/authenticate')
const apiController = require('./api.controller')

const router = new Router()

// HTTP GET /api handler (returns promise)
router.get('/', authenticate, apiController.get)
router.post('/', authenticate, apiController.post)

module.exports = router
