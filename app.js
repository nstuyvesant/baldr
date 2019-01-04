/*
  This is the ExpressJS app (our server).

  It does the following:
  - configures Express
  - sets up handling of static files
  - loads routes
  - defines how errors will be handled (centrally)
  - starts ExpressJS listening for requests
*/

const express = require('express')
const path = require('path')
const compression = require('compression')
const helmet = require('helmet')
const loadRoutes = require('./routes')
const app = express()

// Express configuration
const port = process.env.NODE_PORT || 3000
app.use(helmet()) // basic security
app.use(compression()); // compress all routes
app.use(express.urlencoded({ extended: false })) // support URL-encoded querystrings
app.use(express.json()); // Enable JSON

// Serve up any content requested from /public
app.use(express.static(path.join(__dirname, 'public')))

// Load route handling (after Express configuration)
loadRoutes(app) // Alternatively, require('./routes').default(app);

// ExpressJS error handler for all routes - must be last
app.use((err, req, res, next) => { // <- Must have 4 parameters
  const status = err.status || err.statusCode || 500;
  const message = err.message || 'Something unexpected happened';
  const errors = err.errors || [];
  console.error(`\x1b[31mERROR ${status}: ${message}`); // display in red
  res.statusMessage = message;
  res.status(status).send({ status, message, errors });
})

// Start listening for requests
app.listen(port, () => console.log(`Baldr listening on port ${port}.`))
