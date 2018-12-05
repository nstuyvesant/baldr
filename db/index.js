const { Pool } = require('pg').native
const pool = new Pool({
  max: 10, // default
  connectionString: 'postgresql://baldr@:5432/baldr'
})

// No need to do pool.end() because it's a single query
module.exports = {
  query: (text, params) => pool.query(text, params)
}