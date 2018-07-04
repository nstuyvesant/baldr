const express = require('express')
const Client = require('pg-native')
const app = express()
const path = require('path')
const pgConnectionString = 'postgresql://baldr@:5432/vr'
const compression = require('compression');
const helmet = require('helmet')
const https = require('https')
const port = process.env.NODE_PORT || 3000;

// Middleware function to check for and validate cloud and securityToken
const authenticate = (req, res, next) => {
  const { cloud, securityToken, user, password } = req.query
  // Check if parameters are present - bail out if not
  const missingParams = !(cloud && (securityToken || (user && password)))
  if (missingParams) {
    res.status(401).json({ message: 'Not authorized: cloud, securityToken or user/password parameters missing.' })
    return
  }

  // Enable either tokens or user/password for authentication
  const securityParams = securityToken ? `securityToken=${securityToken}` : `user=${user}&password=${password}`
  // Perform REST API operation that returns the smallest amount of JSON (reservations for no one)
  https.get(`https://${cloud}/services/reservations/?operation=list&reservedTo=noone&${securityParams}`, getResponse => {
    const { statusCode } = getResponse
    if (statusCode !== 200) {
      getResponse.resume() // consume getResponse to free up memory
      if (statusCode === 401) {
        console.log('Did not authenticate successfully')
        res.status(401).json({ message: 'Not authorized: cloud/securityToken (or user/password) did not authenticate. Is your token or user/password combination correct or could your token have expired?' })
        return
      }
      res.status(statusCode).json({ message: `Request to cloud failed (${statusCode}).` })
      return
    }
    getResponse.setEncoding('utf8')
    let rawData = ''
    getResponse.on('data', (chunk) => {
      rawData += chunk
    })
    getResponse.on('end', () => {
      const response = JSON.parse(rawData)
      if (response.info) { // Authenticated successfully
        console.log(`Successfully authenticated to ${cloud}`)
        return next()
      } else {
        res.status(417).json({ message: 'Received unexpected response from cloud.' })
      }
    })
  }).on('error', (e) => {
    console.error(`Got error: ${e.message}`)
    res.status(424).json({ message: 'Could not connect to that cloud. Did you specify a valid fully-qualified domain name?' })
  })
}

// Add some basic security
app.use(helmet())

// Compress all routes
app.use(compression());

// Allow ExpressJS to support JSON but not URL-encoded bodies
app.use(express.urlencoded({ extended: false }))
app.use(express.json());

// Serve up any content requested from /public
app.use(express.static(path.join(__dirname, 'public')))

// Handle HTTP GET to retrieve the snapshot
app.get('/api', authenticate, (req, res) => {
  const client = new Client()
  const { cloud, date } = req.query
  const missingParams = !(cloud || date)
  if (missingParams) {
    res.status(400).json({ message: 'Missing parameter(s): cloud and date are required.' })
    return
  }
  // Try connecting to PostgreSQL
  client.connect(pgConnectionString, err => {
    if (err) {
      res.status(401).json({ message: 'Not able to connect to database to retrieve snapshot.' })
      return
    }
    // Run parameterized query to prevent SQL injection
    client.query(`SELECT cloudSnapshot($1, $2::DATE)`, [cloud, date], (err, rows)=> {
      if (err) {
        res.status(424).json({ message: 'Not able to retrieve snapshot from database (but connected successfully).' })
        return
      }
      const { cloudsnapshot } = rows[0]
      if (!cloudsnapshot) {
        res.status(404).json({ message: 'No snapshot for that cloud/date combination.' })
      }
      res.status(200).send(cloudsnapshot) // Already JSON (stringify not necessary)
    })
  })
})

// Handle HTTP POST of JSON to /api
app.post('/api', authenticate, (req, res) => {
  console.log('req.body', req.body)
  console.log('req.body.snapshot', req.body.snapshot)
  if(!req.body) { // Is there content?
    res.status(444).json({ message: 'Nothing received.' })
    return
  }
  console.log('Received JSON request.')
  authorizedToUpsert = req.query.cloud === req.body.fqdn
  if (!authorizedToUpsert) {
    res.status(401).json({ message: 'You tried to update a different cloud (via JSON) from the one specified by the cloud querystring parameter.' })
    return
  }
  jsonSnapshot = JSON.stringify(req.body) // convert the body back to JSON
  let client = new Client()
  client.connect(pgConnectionString, (err) => {
    if (err) {
      res.status(401).json({ message: 'Not able to connect to database to submit snapshot.' })
      return
    }
    let sql = `SELECT json_snapshot_upsert($1::json)` // parameterized to prevent SQL injection
    console.log('jsonSnapshot', jsonSnapshot)
    client.query(sql, [jsonSnapshot], (err)=> {
      if (err) {
        console.log(err)
        res.status(424).json({ message: 'Not able to submit snapshot to database (but connected successfully).' })
        return
      }
      console.log('JSON received and processed.')
      res.status(200).json({ message: 'JSON received and processed.' })
    })
  })
})

// Listen for requests
app.listen(port, () => console.log(`Baldr listening on port ${port}.`))