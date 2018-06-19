const express = require('express')
const Client = require('pg-native')
const app = express()
const path = require('path')
const pgConnectionString = 'postgresql://postgres@localhost:5432/vr'
const bodyParser = require('body-parser');
const compression = require('compression');
const helmet = require('helmet')

// Allow ExpressJS to support JSON and URL-encoded bodies
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Add some basic security
app.use(helmet())

//Compress all routes
app.use(compression());

// Serve up any content requested from /public
app.use(express.static(path.join(__dirname, 'public')))

// Call PostgreSQL function and write JSON to response
app.get('/api', (req, res, next) => {
  let client = new Client()
  let cloud = req.query.cloud
  let snapshotDate = req.query.date
  let missingParams = !cloud || !snapshotDate
  if (!missingParams) {
    client.connect(pgConnectionString, (err) => {
      if (err) {
        res.status(502).send('Not able to connect to database to retrieve snapshot.')
        return
      }
      let sql = `SELECT cloudSnapshot($1, $2::DATE)` // parameterized to prevent SQL injection
      client.query(sql, [cloud, snapshotDate], (err, rows)=> {
        if (err) {
          res.status(503).send('Not able to retrieve snapshot from database (but connected successfully).')
          return
        }
        res.send(rows[0].cloudsnapshot)
      })
    })
  } else res.status(501).send('Missing parameter(s): cloud and date are required.')
})

app.post('/api', (req, res, next) => {
  if(req.body) {
    console.log('Received JSON request.')
    jsonSnapshot = JSON.stringify(req.body)
    let client = new Client()
    client.connect(pgConnectionString, (err) => {
      if (err) {
        res.status(502).send('{ "success": false, "message": "Not able to connect to database to submit snapshot."')
        return
      }
      let sql = `SELECT json_snapshot_upsert($1::json)` // parameterized to prevent SQL injection
      client.query(sql, [jsonSnapshot], (err, rows)=> {
        if (err) {
          res.status(503).send('{ "success": false, "message": "Not able to submit snapshot to database (but connected successfully)."')
          return
        }
        console.log('Processed JSON request.')
        res.send('{ "success": true, "message": "JSON received and processed." }')
      })
    })
  } else {
    res.status(504).send('{ "success": false, "message": "No JSON received." }')
  }
})

app.listen(80, () => console.log('Baldr listening on port 80.'))