const Router = require('express-promise-router')
const authenticate = require('../middleware/authenticate')
const db = require('../db')
const router = new Router()

router.get('/', authenticate, async (req, res, next) => {
  try {
    const { cloud, date } = req.query
    const { rows } = await db.query('SELECT cloudSnapshot($1, $2::DATE)', [cloud, date])
    res.status(200).send(rows[0].cloudsnapshot) // Already JSON (stringify not necessary)
  } catch(err) {
    res.status(400).json(err)
    next(err)
  }
})

router.post('/', authenticate, async (req, res, next) => {
  try {
    // Check for content
    if(!req.body.snapshot) throw Error('Nothing received.')

    // Check authorization
    authorizedToUpsert = req.query.cloud === req.body.snapshot.fqdn
    if (!authorizedToUpsert) throw Error('You tried to update a different cloud (via JSON) from the one specified by the cloud querystring parameter.')

    const { rows } = await db.query('SELECT json_snapshot_upsert($1::json)', [req.body.snapshot])
    res.status(200).json({ message: 'JSON received and processed.' })

  } catch(err) {
    res.status(400).json(err)
    next(err)
  }
})

module.exports = router
