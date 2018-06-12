const express = require('express')
const Client = require('pg-native')
const app = express()

app.get('/', (req, res) => {
  let client = new Client()
  client.connectSync('postgresql://postgres@localhost:5432/vr')
  let rows = client.querySync("SELECT cloudSnapshots('acme.perfectomobile.com', '2018-06-12'::DATE)")
  // TODO: Get fqdn (fully-qualified domain name) and date from a querystring and pass as variables to the line above
})

app.listen(3000, () => console.log('Report server listening on port 3000.'))