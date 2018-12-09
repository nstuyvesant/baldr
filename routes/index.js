/*
  Central place for setting up  routes (we only have one for now)
*/

// This is how we connect the route handling to the central instance of ExpressJS
module.exports = (app) => {
  app.use('/api', require('./api'))
}