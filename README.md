[![postgresql][postgresql]][postgresql-url]
[![express][express]][express-url]
[![node][node]][node-url]

# Perfecto Reporting
Named after the Norse God of Light, this project generates emailed PDF reports to increase visibility of barriers to automation.

## Getting Started

### Prerequisites for macOS

- [Homebrew](https://brew.sh) (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)
- [Git](https://git-scm.com/) (`brew install git`)
- [Node.js 9.7.1 and npm 5.7.1](nodejs.org) (`brew install node`)
- [PostgreSQL 10.3.0](http://postgresql.org) (`brew install postgresql`)
- [pgAdmin4](https://www.postgresql.org/download/)

### Project setup

1. Launch _Terminal_ on macOS.

2. Make sure prerequisites are installed for your operating system (commands above are for macOS). If Homebrew was already installed, be sure to run `brew doctor` and address any issues before installation of the other brew packages.

3. Type `git clone https://github.com/nstuyvesant/baldr.git && cd baldr && npm install` to clone the project and install dependencies

4. Type `brew services start postgresql` to start PostgreSQL

5. Type `psql -d postgres -f db_create.sql` to create the vr database and populate it with sample data

6. Type `npm start` then go to [http://localhost:3000](http://localhost:3000) to see the JSON output

### Overview of files

- [db_create.sql](https://github.com/nstuyvesant/baldr/blob/master/db_create.sql) - Creates the PostgreSQL database, functions to generate JSON and populates with sample data

- [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js) - Brief example using pg-native to pass current date to get JSON array of clouds and display on page. See Backlog for next steps.

### Backlog

1. Iterate through array of clouds to merge each element with [report.html](https://github.com/nstuyvesant/baldr/blob/master/report.html)

2. Generate a PDF from each

3. Email PDF to list of addresses in emailRecipients property

4. Create bash shell script to start node and request [http://localhost:3000](http://localhost:3000) via curl once a day using cron

[express]: https://img.shields.io/badge/expressjs-4.16.3-blue.svg
[express-url]: http://expressjs.com
[node]: https://img.shields.io/badge/nodejs-10.4.0-green.svg
[node-url]: https://nodejs.org
[postgresql]: https://img.shields.io/badge/postgresql-10.4.0-blue.svg
[postgresql-url]: https://www.postgresql.org