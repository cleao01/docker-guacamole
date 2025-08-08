### Dockerfile for guacamole
### Includes the mysql authentication module preinstalled

ARG GUAC_VER=1.6.0

########################
### Get Guacamole Server
FROM guacamole/guacd:${GUAC_VER} AS server

########################
### Get Guacamole Client
FROM guacamole/guacamole:${GUAC_VER} AS client


####################
### Build Main Image

###############################
### Build image without MariaDB
FROM alpine:3.18 AS nomariadb
ARG GUAC_VER
LABEL version=$GUAC_VER

ARG PREFIX_DIR=/opt/guacamole

### Set correct environment variables.
ENV HOME=/config
ENV LC_ALL=C.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info
ENV LOGBACK_LEVEL=info
ENV GUACAMOLE_HOME=/config/guacamole

### Copy build artifacts into this stage
COPY --from=server ${PREFIX_DIR} ${PREFIX_DIR}
COPY --from=client ${PREFIX_DIR} ${PREFIX_DIR}

ARG RUNTIME_DEPENDENCIES="  \
    ca-certificates         \
    ghostscript             \
    netcat-openbsd          \
    shadow                  \
    terminus-font           \
    ttf-dejavu              \
    ttf-liberation          \
    util-linux-login        \
    openjdk11-jre-headless  \
    supervisor              \
    pwgen                   \
    tzdata                  \
    procps                  \
    logrotate               \
    wget                    \
    bash                    \
    tini"

ADD image /

### Install packages and clean up in one command to reduce build size

RUN apk add --no-cache ${RUNTIME_DEPENDENCIES}                                                                                                                                      && \
    xargs apk add --no-cache < ${PREFIX_DIR}/DEPENDENCIES                                                                                                                           && \
    adduser -h /config -s /bin/nologin -u 99 -D abc                                                                                                                                 && \
    adduser -h /opt/tomcat -s /bin/false -D tomcat                                                                                                                                  && \
    TOMCAT_VERSION=$(wget -qO- https://tomcat.apache.org/download-80.cgi | grep "8\.5\.[0-9]\+</a>" | sed -e 's|.*>\(.*\)<.*|\1|g')                                                 && \
    wget https://dlcdn.apache.org/tomcat/tomcat-8/v"$TOMCAT_VERSION"/bin/apache-tomcat-"$TOMCAT_VERSION".tar.gz                                                                     && \
    tar -xf apache-tomcat-"$TOMCAT_VERSION".tar.gz                                                                                                                                  && \
    mv apache-tomcat-"$TOMCAT_VERSION"/* /opt/tomcat                                                                                                                                && \
    rmdir apache-tomcat-"$TOMCAT_VERSION"                                                                                                                                           && \
    find /opt/tomcat -type d -print0 | xargs -0 chmod 700                                                                                                                           && \
    chmod +x /opt/tomcat/bin/*.sh                                                                                                                                                   && \
    mkdir -p /var/lib/tomcat/webapps /var/log/tomcat                                                                                                                                && \
    ln -s ${PREFIX_DIR}/guacamole.war /var/lib/tomcat/webapps/ROOT.war                                                                                                              && \
    chmod +x /etc/firstrun/*.sh                                                                                                                                                     && \
    mkdir -p /config/guacamole /config/log/tomcat /var/lib/tomcat/temp /var/run/tomcat                                                                                              && \
    ln -s /opt/tomcat/conf /var/lib/tomcat/conf                                                                                                                                     && \
    ln -s /config/log/tomcat /var/lib/tomcat/logs                                                                                                                                   && \
    sed -i '/<\/Host>/i \        <Valve className=\"org.apache.catalina.valves.RemoteIpValve\"\n               remoteIpHeader=\"x-forwarded-for\" />' /opt/tomcat/conf/server.xml

EXPOSE 8080

VOLUME ["/config"]

CMD [ "/etc/firstrun/firstrun.sh" ]


############################
### Build image with MariaDB 
FROM nomariadb
ARG GUAC_VER
LABEL version=$GUAC_VER

RUN apk add mariadb mariadb-client

ADD image-mariadb /

RUN chmod +x /etc/firstrun/mariadb.sh

### END
### To make this a persistent guacamole container, you must map /config of this container
### to a folder on your host machine.
###
