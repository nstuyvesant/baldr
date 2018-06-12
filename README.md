[![postgresql][postgresql]][postgresql-url]
[![express][express]][express-url]
[![node][node]][node-url]

# Perfecto Reporting
Named after the Norse God of Light, this project will (eventually) generate emailed PDF reports to increase visibility of automation obstacles.

## Getting Started

### Prerequisites for macOS

- [Homebrew](https://brew.sh) (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)
- [Git](https://git-scm.com/) (`brew install git`)
- [Node.js 10.4.0 and npm 6.1.0](nodejs.org) (`brew install node`)
- [PostgreSQL 10.4.0](http://postgresql.org) (`brew install postgresql`)
- [pgAdmin4 3.0](https://www.postgresql.org/download/) (download and install it)

### Project setup

1. Launch __Terminal__ on your Mac.

2. Make sure prerequisites are installed. If Homebrew was already installed, be sure to run `brew doctor` and address any issues before installing other brew packages.

3. Type `git clone https://github.com/nstuyvesant/baldr.git && cd baldr && npm install` to clone the project and install dependencies

4. Type `brew services start postgresql` to start PostgreSQL (if not already running)

5. Type `psql -d postgres -f db_create.sql` to create the vr database and populate it with sample data

6. Type `npm start` then go to [http://localhost:3000](http://localhost:3000) to see the JSON output. This is an initial step. See __Backlog__ below.

### Overview of files

- [db_create.sql](https://github.com/nstuyvesant/baldr/blob/master/db_create.sql) - Creates the PostgreSQL database, functions to generate JSON and populates with sample data

- [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js) - Brief example of [ExpressJS](http://expressjs.com) with [pg-native](https://github.com/brianc/node-pg-native) to pass current date to get JSON array of clouds and display on page. See Backlog for next steps.

### Backlog

1. Ran and Uzi to write their summaries to vr database daily (cron)

2. Remove tests.age and modify cloudSnapshot() to use this query

3. Handle uuid and date parameters for HTTP GET in index.js or rewrite as PHP

4. Modify report.html to handle fqdn and date querystring params and $.get() to get JSON from REST service

5. Tzvika to add hyperlink to Digitalzoom that passes MCM FQDN and current date to report.html

[express]: https://img.shields.io/badge/expressjs-4.16.3-red.svg
[express-url]: http://expressjs.com
[node]: https://img.shields.io/badge/nodejs-10.4.0-green.svg
[node-url]: https://nodejs.org
[postgresql]: https://img.shields.io/badge/postgresql-10.4.0-blue.svg
[postgresql-url]: https://www.postgresql.org