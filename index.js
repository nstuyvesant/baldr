const express = require('express')
const Client = require('pg-native')
const app = express()

app.get('/', (req, res) => {
  let client = new Client()
  client.connect('postgresql://postgres@localhost:5432/vr', (err) => {
    if (err) throw err
    client.query("SELECT cloudSnapshots('acme.perfectomobile.com', '2018-06-12'::DATE)", (err, rows)=> {
      res.send(rows[0])
    })
  })
  
  // TODO: Get fqdn (fully-qualified domain name) and date from a querystring and pass as variables to the line above
})

app.listen(3000, () => console.log('Report server listening on port 3000.'))