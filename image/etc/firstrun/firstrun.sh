#!/bin/bash

EXT_STORE="/opt/guacamole"
GUAC_EXT="/config/guacamole/extensions"
TOMCAT_LOG="/config/log/tomcat"
CHANGES=false
JCONNECTOR="9.4.0"

# Create user
PUID=${PUID:-99}
PGID=${PGID:-100}

groupmod -o -g "$PGID" abc
usermod -o -u "$PUID" abc

echo "----------------------"
echo "User UID: $(id -u abc)"
echo "User GID: $(id -g abc)"
echo "----------------------"

chown -R abc:abc /config
chown -R abc:abc /opt/tomcat /var/run/tomcat /var/lib/tomcat

# Check if logback.xml exists and set the log level based on LOGBACK_LEVEL value
#if [ ! -f "$GUACAMOLE_HOME"/logback.xml ]; then
#  unzip -o -j /opt/guacamole/webapp/guacamole.war WEB-INF/classes/logback.xml -d "$GUACAMOLE_HOME" > /dev/null
#  unzip -o -j /opt/guacamole/webapp/guacamole.war WEB-INF/classes/logback.xml -d "$GUACAMOLE_HOME" > lixo
#fi
#sed -i 's/ level="[^"]*"/ level="'$LOGBACK_LEVEL'"/' "$GUACAMOLE_HOME"/logback.xml

OPTMYSQL=${OPT_MYSQL:-N}

# Check if properties file exists. If not, copy in the starter database
if [ -f /config/guacamole/guacamole.properties ]; then
  echo "Using existing properties file."
  if [ ! -d "$TOMCAT_LOG" ]; then
    echo "Creating log directory."
    mkdir -p "$TOMCAT_LOG"
    chown -R abc:abc "$TOMCAT_LOG"
  fi
else
  echo "Creating properties from template."
  mkdir -p "$GUAC_EXT" /config/guacamole/lib "$TOMCAT_LOG"
  cp /etc/firstrun/templates/* "$GUACAMOLE_HOME"
  chown -R abc:abc /config/guacamole "$TOMCAT_LOG"
  if [ "$OPTMYSQL" = "Y" ] && [ -f /etc/firstrun/mariadb.sh ]; then
    echo "Creating Database folders"
    mkdir -p /config/databases
    chown abc:abc /config/databases
  fi
  PW=$(pwgen -1snc 32)
  sed -i -e 's/some_password/'$PW'/g' /config/guacamole/guacamole.properties
  CHANGES=true
fi

if [ "$OPTMYSQL" = "Y" ] ; then
  # Check if SQL extension file exists. Copy or upgrade if necessary.
  if [ -f "$GUAC_EXT"/*jdbc-mysql*.jar ]; then
    oldMysqlFiles=( "$GUAC_EXT"/*jdbc-mysql*.jar )
    newMysqlFiles=( "$EXT_STORE"/extensions/guacamole-auth-jdbc/mysql/*jdbc-mysql*.jar )

    if diff ${oldMysqlFiles[0]} ${newMysqlFiles[0]} >/dev/null ; then
      echo "Using existing MySQL extension."
      if [ ! -d /config/mysql-schema ]; then
        mkdir /config/mysql-schema
        cp -R /root/mysql/* /config/mysql-schema
        CHANGES=true
      fi
    else
      echo "Upgrading MySQL extension and update schema files"
      rm "$GUAC_EXT"/*jdbc-mysql*.jar
      cd /config/guacamole/lib
      rm mysql-connector*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-jdbc/mysql/*jdbc-mysql*.jar "$GUAC_EXT"
	  wget -q https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${JCONNECTOR}.tar.gz
	  tar -xzf mysql-connector-j-${JCONNECTOR}.tar.gz
	  mv mysql-connector-j-${JCONNECTOR}/mysql-connector*.jar /config/guacamole/lib
	  rm -r mysql-connector-j-${JCONNECTOR}
      rm -R /config/mysql-schema/*
      cp -R "$EXT_STORE"/extensions/guacamole-auth-jdbc/mysql/schema/* /config/mysql-schema
      CHANGES=true
    fi
  else
    echo "Copying MySQL extension and SQL schema files"
    cp "$EXT_STORE"/extensions/guacamole-auth-jdbc/mysql/*jdbc-mysql*.jar "$GUAC_EXT"
    wget -q https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${JCONNECTOR}.tar.gz
	tar -xzf mysql-connector-j-${JCONNECTOR}.tar.gz
	mv mysql-connector-j-${JCONNECTOR}/mysql-connector*.jar /config/guacamole/lib
	rm -r mysql-connector-j-${JCONNECTOR}	
    mkdir /config/mysql-schema
    cp -R "$EXT_STORE"/extensions/guacamole-auth-jdbc/mysql/schema/* /config/mysql-schema
    CHANGES=true
  fi
elif [ "$OPTMYSQL" = "N" ] ; then
  # Delete SQL related files
  if [ -f "$GUAC_EXT"/*jdbc-mysql*.jar ]; then
    echo "Removing MySQL extension."
    rm "$GUAC_EXT"/*jdbc-mysql*.jar
    cd /config/guacamole/lib
	echo "Removing MySQL connector."
    rm mariadb-java-client-*.jar
    rm -R /config/mysql-schema
  fi
fi

OPTSQLSERVER=${OPT_SQLSERVER:-N}
if [ "$OPTSQLSERVER" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*sqlserver*.jar ]; then
    oldSqlServerFiles=( "$GUAC_EXT"/*sqlserver*.jar )
    newSqlServerFiles=( "$EXT_STORE"/extensions/guacamole-auth-jdbc/sqlserver/*sqlserver*.jar )

    if diff ${oldSqlServerFiles[0]} ${newSqlServerFiles[0]} >/dev/null ; then
    	echo "Using existing SQL Server extension."
    else
    	echo "Upgrading SQL Server extension."
    	rm "$GUAC_EXT"/*sqlserver*.jar
    	cp "$EXT_STORE"/extensions/guacamole-auth-jdbc/sqlserver/*sqlserver*.jar "$GUAC_EXT"
      rm -R /config/sqlserver-schema/*
      cp -R "$EXT_STORE"/extensions/guacamole-auth-jdbc/sqlserver/schema/* /config/sqlserver-schema
      CHANGES=true
    fi
  else
    echo "Copying SQL Server extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-jdbc/sqlserver/*sqlserver*.jar "$GUAC_EXT"
    mkdir /config/sqlserver-schema
    cp -R "$EXT_STORE"/extensions/guacamole-auth-jdbc/sqlserver/schema/* /config/sqlserver-schema
    CHANGES=true
  fi
elif [ "$OPTSQLSERVER" = "N" ]; then
  if [ -f "$GUAC_EXT"/*sqlserver*.jar ]; then
    echo "Removing SQL Server extension."
    rm "$GUAC_EXT"/*sqlserver*.jar
    rm -R /config/sqlserver-schema
  fi
fi

OPTLDAP=${OPT_LDAP:-N}
if [ "$OPTLDAP" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*ldap*.jar ]; then
    oldLDAPFiles=( "$GUAC_EXT"/*ldap*.jar )
    newLDAPFiles=( "$EXT_STORE"/extensions/guacamole-auth-ldap/*ldap*.jar )

    if diff ${oldLDAPFiles[0]} ${newLDAPFiles[0]} >/dev/null ; then
    	echo "Using existing LDAP extension."
    else
    	echo "Upgrading LDAP extension."
    	rm "$GUAC_EXT"/*ldap*.jar
    	rm -R /config/ldap-schema/*
    	cp "$EXT_STORE"/extensions/guacamole-auth-ldap/*ldap*.jar "$GUAC_EXT"
    	cp -R "$EXT_STORE"/extensions/guacamole-auth-ldap/schema/*.ldif /config/ldap-schema
      CHANGES=true
    fi
  else
    echo "Copying LDAP extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-ldap/*ldap*.jar "$GUAC_EXT"
    mkdir /config/ldap-schema
    cp -R "$EXT_STORE"/extensions/guacamole-auth-ldap/schema/*.ldif /config/ldap-schema
    CHANGES=true
  fi
elif [ "$OPTLDAP" = "N" ]; then
  if [ -f "$GUAC_EXT"/*ldap*.jar ]; then
    echo "Removing LDAP extension."
    rm "$GUAC_EXT"/*ldap*.jar
    rm -R /config/ldap-schema
  fi
fi

OPTDUO=${OPT_DUO:-N}
if [ "$OPTDUO" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*duo*.jar ]; then
    oldDuoFiles=( "$GUAC_EXT"/*duo*.jar )
    newDuoFiles=( "$EXT_STORE"/extensions/guacamole-auth-duo/*duo*.jar )

    if diff ${oldDuoFiles[0]} ${newDuoFiles[0]} >/dev/null ; then
      echo "Using existing Duo extension."
    else
      echo "Upgrading Duo extension."
      rm "$GUAC_EXT"/*duo*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-duo/*duo*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Duo extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-duo/*duo*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTDUO" = "N" ]; then
  if [ -f "$GUAC_EXT"/*duo*.jar ]; then
    echo "Removing Duo extension."
    rm "$GUAC_EXT"/*duo*.jar
  fi
fi

OPTCAS=${OPT_CAS:-N}
if [ "$OPTCAS" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*cas*.jar ]; then
    oldCasFiles=( "$GUAC_EXT"/*cas*.jar )
    newCasFiles=( "$EXT_STORE"/extensions/guacamole-auth-sso/cas/*cas*.jar )

    if diff ${oldCasFiles[0]} ${newCasFiles[0]} >/dev/null ; then
      echo "Using existing CAS extension."
    else
      echo "Upgrading CAS extension."
      rm "$GUAC_EXT"/*cas*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-sso/cas/*cas*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying CAS extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-sso/cas/*cas*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTCAS" = "N" ]; then
  if [ -f "$GUAC_EXT"/*cas*.jar ]; then
    echo "Removing CAS extension."
    rm "$GUAC_EXT"/*cas*.jar
  fi
fi

OPTOPENID=${OPT_OPENID:-N}
if [ "$OPTOPENID" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*openid*.jar ]; then
    oldOpenidFiles=( "$GUAC_EXT"/*openid*.jar )
    newOpenidFiles=( "$EXT_STORE"/extensions/guacamole-auth-sso/openid/*openid*.jar )

    if diff ${oldOpenidFiles[0]} ${newOpenidFiles[0]} >/dev/null ; then
      echo "Using existing OpenID extension."
    else
      echo "Upgrading OpenID extension."
      rm "$GUAC_EXT"/*openid*.jar
      find ${EXT_STORE}/extensions/guacamole-auth-sso/openid/ -name "*.jar" | awk -F/ '{print $NF}' | xargs -I '{}' cp "${EXT_STORE}/extensions/guacamole-auth-sso/openid/{}" "${GUAC_EXT}/1-{}"
      CHANGES=true
    fi
  else
    echo "Copying OpenID extension."
    find ${EXT_STORE}/extensions/guacamole-auth-sso/openid/ -name "*.jar" | awk -F/ '{print $NF}' | xargs -I '{}' cp "${EXT_STORE}/extensions/guacamole-auth-sso/openid/{}" "${GUAC_EXT}/1-{}"
    CHANGES=true
  fi
elif [ "$OPTOPENID" = "N" ]; then
  if [ -f "$GUAC_EXT"/*openid*.jar ]; then
    echo "Removing OpenID extension."
    rm "$GUAC_EXT"/*openid*.jar
  fi
fi

OPTTOTP=${OPT_TOTP:-N}
if [ "$OPTTOTP" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*totp*.jar ]; then
    oldTotpFiles=( "$GUAC_EXT"/*totp*.jar )
    newTotpFiles=( "$EXT_STORE"/extensions/guacamole-auth-totp/*totp*.jar )

    if diff ${oldTotpFiles[0]} ${newTotpFiles[0]} >/dev/null ; then
      echo "Using existing TOTP extension."
    else
      echo "Upgrading TOTP extension."
      rm "$GUAC_EXT"/*totp*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-totp/*totp*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying TOTP extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-totp/*totp*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTTOTP" = "N" ]; then
  if [ -f "$GUAC_EXT"/*totp*.jar ]; then
    echo "Removing TOTP extension."
    rm "$GUAC_EXT"/*totp*.jar
  fi
fi

OPTQUICKCONNECT=${OPT_QUICKCONNECT:-N}
if [ "$OPTQUICKCONNECT" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*quickconnect*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*quickconnect*.jar )
    newQCFiles=( "$EXT_STORE"/extensions/guacamole-auth-quickconnect/*quickconnect*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing Quick Connect extension."
    else
      echo "Upgrading Quick Connect extension."
      rm "$GUAC_EXT"/*quickconnect*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-quickconnect/*quickconnect*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Quick Connect extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-quickconnect/*quickconnect*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTQUICKCONNECT" = "N" ]; then
  if [ -f "$GUAC_EXT"/*quickconnect*.jar ]; then
    echo "Removing Quick Connect extension."
    rm "$GUAC_EXT"/*quickconnect*.jar
  fi
fi

OPTHEADER=${OPT_HEADER:-N}
if [ "$OPTHEADER" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*header*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*header*.jar )
    newQCFiles=( "$EXT_STORE"/extensions/guacamole-auth-header/*header*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing Header extension."
    else
      echo "Upgrading Header extension."
      rm "$GUAC_EXT"/*header*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-header/*header*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying Header extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-header/*header*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTHEADER" = "N" ]; then
  if [ -f "$GUAC_EXT"/*header*.jar ]; then
    echo "Removing Header extension."
    rm "$GUAC_EXT"/*header*.jar
  fi
fi

OPTSAML=${OPT_SAML:-N}
if [ "$OPTSAML" = "Y" ]; then
  if [ -f "$GUAC_EXT"/*saml*.jar ]; then
    oldQCFiles=( "$GUAC_EXT"/*saml*.jar )
    newQCFiles=( "$EXT_STORE"/extensions/guacamole-auth-sso/saml/*saml*.jar )

    if diff ${oldQCFiles[0]} ${newQCFiles[0]} >/dev/null ; then
      echo "Using existing SAML extension."
    else
      echo "Upgrading SAML extension."
      rm "$GUAC_EXT"/*saml*.jar
      cp "$EXT_STORE"/extensions/guacamole-auth-sso/saml/*saml*.jar "$GUAC_EXT"
      CHANGES=true
    fi
  else
    echo "Copying SAML extension."
    cp "$EXT_STORE"/extensions/guacamole-auth-sso/saml/*saml*.jar "$GUAC_EXT"
    CHANGES=true
  fi
elif [ "$OPTSAML" = "N" ]; then
  if [ -f "$GUAC_EXT"/*saml*.jar ]; then
    echo "Removing SAML extension."
    rm "$GUAC_EXT"/*saml*.jar
  fi
fi

if [ "$CHANGES" = true ]; then
  echo "Updating user permissions."
  chown abc:abc -R /config/guacamole
  chmod 755 -R /config/guacamole
else
  echo "No permissions changes needed."
fi

if [ "$OPTMYSQL" = "Y" ] && [ -f /etc/firstrun/mariadb.sh ]; then
  /etc/firstrun/mariadb.sh
  exec /sbin/tini -s -- /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord-mariadb.conf
else
  exec /sbin/tini -s -- /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
fi
