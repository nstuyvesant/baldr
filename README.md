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

6. Type `psql -d postgres -f db_create.sql` to create the vr database and populate it with sample data for a cloud called demo.perfectomobile.com with a snapshot for 2018-06-20

7. Type `npm start`

### Testing

1. To see report populated from the database, go to [http://localhost:3000/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=)

2. To view JSON returned by the API, go to [http://localhost:3000/api/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/api/?cloud=demo.perfectomobile.com&date=2018-06-19&securityToken=)

3. To experiment submitting JSON to the API, go to [http://localhost:3000/test.html?cloud=demo.perfectomobile.com&securityToken=YOUR-SECURITY-TOKEN](http://localhost:3000/test.html?cloud=demo.perfectomobile.com&securityToken=)

### Production

1. To run in production on Ubuntu 18.04, login to your server then type `sudo useradd baldr` to create a low-privileged user.

2. Type `cd /home && git clone https://github.com/nstuyvesant/baldr.git`

3. Type `sudo chown -R baldr:baldr /home/baldr`

4. Type `sudo chmod 755 /home/baldr && sudo chmod 744 -R /home/baldr/*`

5. Type `sudo cp baldr.service /etc/systemd/system/` to copy the SystemD configuration file to the required directory

6. Type `sudo systemctl daemon-reload` to reload the list of daemons

7. Type `sudo systemctl start baldr` to start the Baldr Report Server on TCP port 3000

8. Type `sudo systemctl enable baldr` to enable it to run on startup

9. Type `sudo apt install nginx` to install nginx

10. Type `sudo nano /etc/nginx/sites-available/default` to modify the nginx configuration file

11. Comment out the lines with `root /var/www/html;`, `index index.html index.htm... etc.;`, and `try_files $uri $uri/ =404;`

12. Within `location / {...}`, add `
		proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;` then save

13. Check your configuration by typing `sudo nginx -t` and fix any errors

14. Type `sudo systemctl restart nginx` to restart nginx with the new configuration

15. Test everything works by typing `curl http://localhost/test.html`

### Overview of files

- [db_create.sql](https://github.com/nstuyvesant/baldr/blob/master/db_create.sql) - Creates the PostgreSQL database, functions to generate JSON and populates with sample data

- [index.js](https://github.com/nstuyvesant/baldr/blob/master/index.js) - Web server using [ExpressJS](http://expressjs.com) with [pg-native](https://github.com/brianc/node-pg-native) to serve report's UI and API for required JSON

### Backlog

1. Deploy on baldr.perfectomobile.com with pm2, nginx and an SSL certificate

[express]: https://img.shields.io/badge/expressjs-4.16.3-red.svg
[express-url]: http://expressjs.com
[node]: https://img.shields.io/badge/nodejs-10.4.1-green.svg
[node-url]: https://nodejs.org
[postgresql]: https://img.shields.io/badge/postgresql-10.4.0-blue.svg
[postgresql-url]: https://www.postgresql.org