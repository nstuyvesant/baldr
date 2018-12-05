const { Pool } = require('pg')
const pool = new Pool({ connectionString: 'postgresql://baldr@:5432/baldr' })

// No need to do pool.end() because it's a single query
module.exports = {
  query: (text, params) => pool.query(text, params)
}