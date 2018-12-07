[![postgresql][postgresql]][postgresql-url]
[![express][express]][express-url]
[![node][node]][node-url]

![](https://vignette.wikia.nocookie.net/mythology/images/9/97/Baldr.jpg/revision/latest?cb=20170905010131)

# Perfecto Project Baldr
Named after the Norse God of Light, this server generates daily reports that increase visibility of automation obstacles. The server can be accessed at [https://baldr.perfecto.io/?cloud=FQDN&date=DATE-ISO-8601&securityToken=YOUR-SECURITY-TOKEN](https://baldr.perfecto.io/?cloud=demo.perfectomobile.com&date=2018-06-20&securityToken=) with the appropriate substitutions for the parameters listed. [This article](https://developers.perfectomobile.com/display/PD/Security+Token) explains how to request a security token.

## Getting Started

### Prerequisites for macOS

- [Homebrew](https://brew.sh) (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)
- [Git](https://git-scm.com/) (`brew install git`)
- [Node.js 10.14.1 and npm 6.4.1](nodejs.org) (`brew install node@10`)
- [PostgreSQL 11.1.0](http://postgresql.org) (`brew install postgresql`)
- [pgAdmin4 3.6](https://www.postgresql.org/download/) (download and install it)
- Perfecto security token from a US-hosted tenant such as demo.perfectomobile.com. See [this KnowledgeBase article](https://developers.perfectomobile.com/display/PD/Security+Token).

### Local Project Setup

1. Launch __Terminal__ on your Mac.

2. Make sure prerequisites are installed. If Homebrew was already installed, be sure to run `brew doctor` and address any issues before installing other brew packages.

3. Type `brew services start postgresql` to start PostgreSQL (if not already running)

4. From your main development directory (I use ~/dev), type `git clone https://github.com/nstuyvesant/baldr.git` to clone the project

5. Type `cd baldr && npm install` to connect to the directory and install NodeJS dependencies

6. Type `psql -d postgres -f db_create.sql` to create the baldr database and populate it with sample data for a cloud called demo.perfectomobile.com with a snapshot for 2018-06-20

7. Type `npm start`

### Testing

1. To retrieve a customer-facing report, go to [http://localhost:3000/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=) replacing YOUR-SECURITY-TOKEN with the value you got from the Prerequisite step

2. To view JSON returned by the API, go to [http://localhost:3000/api/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/api/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=) replacing YOUR-SECURITY-TOKEN with the value you got from the Prerequisite step

3. To edit previously submitted JSON directly in the editor, go to [http://localhost:3000/editor.html?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/editor.html?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=) replacing YOUR-SECURITY-TOKEN with the value you got from the Prerequisite step

4. To submit JSON via the API, go to [http://localhost:3000/editor.html?cloud=demo.perfectomobile.com&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/editor.html?cloud=demo.perfectomobile.com&securityToken=)  replacing YOUR-SECURITY-TOKEN with the value you got from the Prerequisite step

### Production Setup

1. To run in production on Ubuntu 18.04, login to your server then type `sudo useradd baldr` to create a low-privileged user.

2. Type `cd /home && sudo git clone https://github.com/nstuyvesant/baldr.git`

3. Type `sudo chown -R baldr:baldr /home/baldr`

4. Type `sudo chmod 755 /home/baldr && sudo chmod 744 -R /home/baldr/*`

5. Type `cd /home/baldr`

5. Type `su - postgres`

6. Type `psql -d postgres -f db_create.sql` to create the database then `exit`

7. Type `su - baldr` to open a shell as the baldr user

8. Type `npm install` to install project dependencies then `exit`

9. Type `sudo cp baldr.service /etc/systemd/system/` to copy the SystemD configuration file to the required directory

10. Type `sudo systemctl daemon-reload` to reload the list of daemons

11. Type `sudo systemctl start baldr` to start the Baldr Report Server on TCP port 3000

12. Type `sudo systemctl enable baldr` to enable it to run on startup

13. Setup a reverse proxy for http://fqdn:3000 with an SSL certificate

14. Test by typing `curl https://fqdn/editor.html`

15. Create a cron job for the report analyzer jar by adding this line to your crontab `0 0 * * *  cd /home/baldr/uploader/; java -jar ReportAnalyzer-3.0.jar` 

16. Create a cron job that populates the quality score `0 2 * * *  python /home/baldr/python/score_quality.py`


### Overview of files

- [db_create.sql](https://github.com/nstuyvesant/baldr/blob/master/db_create.sql) - Creates the PostgreSQL database, functions to generate JSON and populates with sample data

- [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js) - Web server using [ExpressJS](http://expressjs.com) with [pg-native](https://github.com/brianc/node-pg-native) to serve report's UI and API for required JSON

- [editor.html](https://github.com/nstuyvesant/baldr/blob/master/public/editor.html) - JSON editor page. Submissions from this page are stored in the underlying PostgreSQL database, vr, replacing any contents for the snapshot date.

- [sample-input.json](https://github.com/nstuyvesant/baldr/blob/master/public/sample-input.json) - JSON sample loaded by default in the editor. It represents the valid format for JSON snapshot upserts.

- [sample-output.json](https://github.com/nstuyvesant/baldr/blob/master/public/sample-output.json) - JSON sample returned by the HTTP GET handler in [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js). The difference from the input are the two properties: last7d and last14d. These are not part of the input as they are calculated from previous daily snapshots.

[express]: https://img.shields.io/badge/expressjs-4.16.4-red.svg
[express-url]: http://expressjs.com
[node]: https://img.shields.io/badge/nodejs-10.14.1-green.svg
[node-url]: https://nodejs.org
[postgresql]: https://img.shields.io/badge/postgresql-11.1.0-blue.svg
[postgresql-url]: https://www.postgresql.org
