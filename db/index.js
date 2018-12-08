/*
  Interface to PostgreSQL

  All database interactions use this because:
  - centralized loading of pg and configuration
  - if we want to add logging, we can do it here

  Note: this is setup for single query operation (no transactions);
    calling pool.end() is not needed.
*/

const { Pool } = require('pg').native
const pool = new Pool({
  max: 10, // default
  connectionString: 'postgresql://baldr@:5432/baldr'
})

// No need to do pool.end() because it's a single query
module.exports = {
  query: (text, params) => pool.query(text, params)
}