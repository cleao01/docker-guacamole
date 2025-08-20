Guacamole
====

Dockerfile for Guacamole 1.6.0 with embedded oe external MariaDB (MySQL), LDAP, DUO, CAS, OPENID, TOTP, QUICKCONNECT, HEADER and SAML authentication

Guacamole is a clientless remote desktop gateway. It supports standard protocols like VNC and RDP.

---
Author
===

Based on the work of Zuhkov zuhkov@gmail.com⁠, aptalca and Jason Bean, updated by cleao to 1.6.0 version of guacamole

---
Building
===

Build from docker file:

```
git clone git@github.com⁠:cleao01/docker-guacamole.git
docker build -t cleao/guacamole .
```

You can also obtain it via:  

```
docker pull cleao/guacamole
```

---
Running
===

Create your guacamole config directory (which will contain both the properties file and the database).

To run using MariaDB for user authentication, launch with the following:

```
docker run -d -v /your-config-location:/config -p 8080:8080 -e OPT_MYSQL=Y cleao/guacamole
```

If using an external Mysql/MariaDB, change guacamole.properties and provide de database:
Expl. to create and provide schema to an MariaDB external database:
docker exec -i DatabaseName sh -c 'mariadb -uroot -p"RootPassword" -e"CREATE DATABASE DatabaseName"'
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql | docker exec -i DatabaseName sh -c 'mariadb -uroot -p"RootPassword" DatabaseName'

Browse to http://your-host-ip:8080 and login with user and password `guacadmin`
---
Credits
===

Apache Guacamole copyright The Apache Software Foundation, Licenced under the Apache License, Version 9.0.

This docker image is built upon the baseimage made by phusion and forked from hall/guacamole, and further forked from Zuhkov/docker-containers and then aptalca/docker-containers and then jason-bean/docker-guacamole
