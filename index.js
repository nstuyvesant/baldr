const express = require('express')
const Client = require('pg-native')
const app = express()

app.get('/', (req, res) => {
  let client = new Client()
  // Using connectSync and querySync for a web server is bad practice but perfect for report generation
  client.connectSync('postgresql://postgres@localhost:5432/vr')

  // We can either let node calculate the date or get it from the bash shell script that invokes this
  // const today = new Date().toISOString().split('T')[0]
  // let rows = client.querySync(`SELECT cloudSnapshots('${today}'::DATE)`)

  // For now, pass the date for the test data we know to be there
  let rows = client.querySync("SELECT cloudSnapshots('acme.perfectomobile.com', '2018-06-12'::DATE)")
  let clouds = rows[0].cloudsnapshots
  res.send(clouds)
  // TODO: iterate through clouds array, merge with report.html, generate PDF, email 
})

app.listen(3000, () => console.log('Report server listening on port 3000.'))