const express = require('express')
const Client = require('pg-native')
const app = express()
const path = require('path')
const pgConnectionString = 'postgresql://postgres@localhost:5432/vr'

// Generic HTTP GET uses /public for static content - test using localhost:3000/?fqdn=acme.perfectomobile.com&date=2018-06-12
app.get('/', express.static(path.join(__dirname, 'public')))

// Pass logo explicitly with correct MIME type
app.get('/perfecto-logo.svg', (req, res, next) => {
  res.setHeader('Content-Type', 'image/svg+xml');
  res.sendFile(path.join(__dirname, 'public/perfecto-logo.svg'));
});

// Simple API - test using http://localhost:3000/api/?cloud=acme.perfectomobile.com?date=2018-06-12
app.get('/api/', (req, res, next) => {
  let client = new Client()
  let cloud = req.query.cloud
  let snapshotDate = req.query.date
  client.connect(pgConnectionString, (err) => {
    if (err) throw err
    // TODO: Change cloud to pass uuid instead of fqdn to improve privacy
    let sql = `SELECT cloudSnapshot($1, $2::DATE)` // parameterized to prevent SQL injection
    client.query(sql, [cloud, snapshotDate], (err, rows)=> {
      if (err) throw err
      res.send(rows[0].cloudsnapshot)
    })
  })
})

app.listen(3000, () => console.log('Baldr listening on port 3000.'))