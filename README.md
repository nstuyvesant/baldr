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

3. Type `brew services start postgresql` to start PostgreSQL (if not already running)

4. Type `git clone https://github.com/nstuyvesant/baldr.git` to clone the project

5. Type `cd baldr && npm install` to connect to the directory and install NodeJS dependencies

6. Type `psql -d postgres -f db_create.sql` to create the vr database and populate it with sample data for a cloud called acme.perfectomobile.com with a snapshot for 2018-06-12

7. Type `sudo npm start` (must use sudo npm start on macOS because we're using TCP port 80)

### Testing

1. To see report populated from the database, go to [http://localhost:3000/?cloud=acme.perfectomobile.com&date=2018-06-12](http://localhost:3000/?cloud=acme.perfectomobile.com&date=2018-06-12)

2. To view JSON returned by the API, go to [http://localhost:3000/api/?cloud=acme.perfectomobile.com&date=2018-06-12](http://localhost:3000/api/?cloud=acme.perfectomobile.com&date=2018-06-12)

3. To experiment submitting JSON to the API, go to [http://localhost:3000/test.html](http://localhost:3000/test.html)

### Overview of files

- [db_create.sql](https://github.com/nstuyvesant/baldr/blob/master/db_create.sql) - Creates the PostgreSQL database, functions to generate JSON and populates with sample data

- [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js) - Web server using [ExpressJS](http://expressjs.com) with [pg-native](https://github.com/brianc/node-pg-native) to serve report's UI and API for required JSON

### Backlog

1. Ran and Uzi to write records to vr database daily using PostgreSQL functions: cloud_upsert(), snapshot_add(), device_add(), test_add(), recommendation_add()

2. Replace use of FQDN with UUID in PostgreSQL function cloudSnapshot() to improve security (give list of UUIDs to Michael)

3. Establish FQDN and SSL certificate for this server on AWS

4. Tzvika to have Michael add hyperlink to Digitalzoom that passes UUID for MCM and current date (ISO 8601 format) to appropriate URL

[express]: https://img.shields.io/badge/expressjs-4.16.3-red.svg
[express-url]: http://expressjs.com
[node]: https://img.shields.io/badge/nodejs-10.4.1-green.svg
[node-url]: https://nodejs.org
[postgresql]: https://img.shields.io/badge/postgresql-10.4.0-blue.svg
[postgresql-url]: https://www.postgresql.org