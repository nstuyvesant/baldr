const express = require('express')
const Client = require('pg-native')
const app = express()

app.get('/', (req, res) => {
  let client = new Client()
  // Using connectSync and querySync for a web server is bad practice but perfect for report generation
  client.connectSync('postgresql://postgres@localhost:5432/vr')
  let rows = client.querySync("SELECT cloudSnapshots('2018-06-09'::DATE)")
  res.send(rows[0].cloudsnapshots)
  // res.send('Iterate through clouds, get JSON from function, merge with HTML, generate PDF, email.'))
})

app.listen(3000, () => console.log('Report server listening on port 3000.'))