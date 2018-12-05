// Initialize ExpressJS and glue everything together

const express = require('express')
const path = require('path')
const compression = require('compression')
const helmet = require('helmet')
const loadRoutes = require('./routes')

const port = process.env.NODE_PORT || 3000
const app = express()

loadRoutes(app)

app.use(helmet()) // basic security
app.use(compression()); // compress all routes

// Allow ExpressJS to support JSON but not URL-encoded bodies
app.use(express.urlencoded({ extended: false }))
app.use(express.json());

// Serve up any content requested from /public
app.use(express.static(path.join(__dirname, 'public')))

// Listen for requests
app.listen(port, () => console.log(`Baldr listening on port ${port}.`))
