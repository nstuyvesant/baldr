const Router = require('express-promise-router')
const authenticate = require('../middleware/authenticate')
const db = require('../db')
const router = new Router()

// HTTP GET /api handler (returns promise)
router.get('/', authenticate, async (req, res) => {
    console.log('GET!!!!!!')
    const { cloud, date } = req.query
    const { rows } = await db.query('SELECT cloudsnapshot($1, $2::DATE)', [cloud, date])
    res.status(200).send(rows[0].cloudsnapshot) // Already JSON (stringify not necessary)
})

// HTTP POST /api handler (ditto)
router.post('/', authenticate, async (req, res) => {
    // Check for content
    if(!req.body.snapshot) throw new Error('Did not receive JSON from client.')

    // Check authorization
    authorizedToUpsert = req.query.cloud === req.body.snapshot.fqdn
    if (!authorizedToUpsert) throw new Error('The fqdn in your submitted JSON must match the cloud querystring parameter.')

    const { rows } = await db.query('SELECT json_snapshot_upsert($1::json)', [req.body.snapshot])
    res.status(200).json({ message: 'JSON received and processed.' })
})

module.exports = router
