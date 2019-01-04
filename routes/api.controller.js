/*
  Controller for the /api route

  Separating controller functions from the routes promotes better
  security (export only what you need), more readable code, and
  code that's easier to test.

  Server unit tests should call this file.
*/

// Get our centralized database interface
const db = require('../db')

// HTTP GET /api handler (returns promise)
async function get(req, res) {
    const { cloud, date } = req.query
    const { rows } = await db.query('SELECT cloudsnapshot($1, $2::DATE)', [cloud, date])
    res.status(200).send(rows[0].cloudsnapshot) // Already JSON (stringify not necessary)
}

// HTTP POST /api handler (ditto)
async function post(req, res) {
    // Check if snapshot posted
    if(!req.body.snapshot) throw new Error('Did not receive JSON from client.')

    // Check whether snapshot's fqdn is same as cloud querystring
    authorizedToUpsert = req.query.cloud === req.body.snapshot.fqdn
    if (!authorizedToUpsert) throw new Error(`The fqdn in your submitted JSON (${req.body.snapshot.fqdn}) must match the cloud querystring parameter (${req.query.cloud}).`)

    // Send snapshot to PostgreSQL
    const { rows } = await db.query('SELECT json_snapshot_upsert($1::json)', [req.body.snapshot])
    res.status(200).json({ message: 'JSON received and processed.' })
}

// Explicitly publish functions to be used elsewhere
module.exports.get = get
module.exports.post = post