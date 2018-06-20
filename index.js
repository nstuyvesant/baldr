const express = require('express')
const Client = require('pg-native')
const app = express()
const path = require('path')
const pgConnectionString = 'postgresql://postgres@localhost:5432/vr'
const bodyParser = require('body-parser');
const compression = require('compression');
const helmet = require('helmet')
const http = require('http')
const https = require('https')

const authenticate = (fqdn, securityToken) => {
  const options = {
    host: fqdn,
    port: 443,
    path: `/services/groups/?operation=list&securityToken=${securityToken}`,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  }
  // Will either return
  // {"groups":[..],"info":{"creationTime":{"formatted":"2018-06-20T02:53:14Z","millis":"1529463194307"},"items":"14","modelVersion":"2.10.0.0","productVersion":"18.7","time":"2018-06-20T02:53:14Z"}}
  // or {"errorMessage":"Failed to list groups - Access denied - bad credentials"} if bad authentication
  let port = options.port == 443 ? https : http
  let req = port.request(options, res => {
    let output = ''
    console.log(options.host + ':' + res.statusCode)
    res.setEncoding('utf8')

    res.on('data', chunk => {
      output += chunk
    });

    res.on('end', () => {
      let obj = JSON.parse(output)
      onResult(res.statusCode, obj)
    });
  })

  req.on('error', err => {
    //res.send('error: ' + err.message);
  });

  req.end();
}

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

app.listen(3000, () => console.log('Baldr listening on port 3000.'))