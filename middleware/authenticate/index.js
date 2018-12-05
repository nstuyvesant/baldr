const https = require('https')

module.exports =  (req, res, next) => {
  const { cloud, securityToken, user, password } = req.query

  // Check if parameters are present - bail out if not
  const missingParams = !(cloud && (securityToken || (user && password)))
  if (missingParams) {
    res.status(401).json({ message: 'Not authorized: cloud, securityToken or user/password parameters missing.' })
    return
  }

  let fqdn
  if (user && user.includes('@perfectomobile.com')) {
    fqdn = 'demo.perfectomobile.com'
  } else {
    fqdn = cloud
  }

  // Enable either tokens or user/password for authentication
  const securityParams = securityToken ? `securityToken=${securityToken}` : `user=${user}&password=${password}`

  // Perform REST API operation that returns the smallest amount of JSON (reservations for no one)
  https.get(`https://${fqdn}/services/reservations/?operation=list&reservedTo=noone&${securityParams}`, getResponse => {
    const { statusCode } = getResponse
    if (statusCode !== 200) {
      getResponse.resume() // consume getResponse to free up memory
      if (statusCode === 401) {
        // console.log('Did not authenticate successfully')
        res.status(401).json({ message: 'Not authorized: cloud/securityToken (or user/password) did not authenticate. Is your token or user/password combination correct or could your token have expired?' })
        return
      }
      res.status(statusCode).json({ message: `Request to cloud failed (${statusCode}).` })
      return
    }
    getResponse.setEncoding('utf8')
    let rawData = ''
    getResponse.on('data', (chunk) => {
      rawData += chunk
    })
    getResponse.on('end', () => {
      const response = JSON.parse(rawData)
      if (response.info) { // Authenticated successfully
        // console.log(`Successfully authenticated to ${fqdn}`)
        return next()
      } else {
        res.status(417).json({ message: 'Received unexpected response from cloud.' })
      }
    })
  }).on('error', (e) => {
    // console.error(`Got error: ${e.message}`)
    res.status(424).json({ message: 'Could not connect to that cloud. Did you specify a valid fully-qualified domain name?' })
  })
}
