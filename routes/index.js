/*
  Central file for setting up all routes (we only have one for now)
*/

// Load API routes
const api = require('./api')

// This is how we connect the route handling to the central instance of ExpressJS
module.exports = (app) => {
  app.use('/api', api)
}