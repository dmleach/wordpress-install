#!/bin/bash
adminemail=dave@daveleach.work

function print () {
    # Was a second parameter provided? (Is $2 zero length)
    if [ -z $2 ]
    then echo -e $1
    else
        case $2 in
            "bold") echo -e "\e[1m"$1"\e[0m";;
            "underline") echo -e "\e[4m"$1"\e[0m";;
            "reverse") echo -e "\e[7m"$1"\e[0m";;
        esac
    fi
}

function installpackage() {
    if ! [ -z $1 ]
    then
        if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]
        then apt-get install $1
        fi
    fi
}

print "WordPress installation" "bold"

print ""
print "Site name" "underline"
print "This script refers to the new WordPress site by a single, short"
print "string that will be used to name the installation directory,"
print "database, user account, and more."
print ""
print "What is the identifying string for the new site?"
read site
print "In what directory should the new WordPress folder be created?"
print "(e.g. to install to /files/wp/"$site", enter '/files/wp')"
read rootdir

##### PACKAGE INSTALLATION #####
print ""
print "Installing needed packages" "underline"

installpackage "php5-gd"
installpackage "libssh2-php"

##### MYSQL DATABASE CREATION #####
print ""
print "MySQL database" "underline"
print "Creating a new MySQL database named "$sitemysqldb

# Initialize variables
sitemysqldb=$site"wpdb"
sitemysqlpassword="$(openssl rand -base64 10)"
sitemysqlscript=$site".sql"
sitemysqluser=$site"user"

# Create a script file with the MySql commands. Since there is no DROP USER
# IF EXISTS syntax in MySQL, granting usage to the user adds a record if one
# doesn't already exist. We can then drop the user with no error
echo "GRANT USAGE ON *.* TO '"$sitemysqluser"'@'localhost' IDENTIFIED BY 'password';" > $sitemysqlscript
echo "DROP USER '"$sitemysqluser"'@'localhost';" >> $sitemysqlscript
echo "DROP DATABASE IF EXISTS "$sitemysqldb";" >> $sitemysqlscript
echo "CREATE DATABASE "$sitemysqldb";" >> $sitemysqlscript
echo "GRANT ALL PRIVILEGES ON "$sitemysqldb".* TO "$sitemysqluser"@localhost IDENTIFIED BY '"$sitemysqlpassword"';" >> $sitemysqlscript
echo "FLUSH PRIVILEGES;" >> $sitemysqlscript

# Set up a trap that will ensure the script is always deleted, even in case
# of an error
trap "rm "$sitemysqlscript EXIT

# Run the script file using the MySql command line utility
mysql -u root < $sitemysqlscript

##### WORDPRESS DOWNLOAD #####
print ""
print "WordPress download" "underline"
print "Downloading latest WordPress installation"

# Initialize variables
wpsitedir=$rootdir"/"$site

# Download the file and create a link to the local version. The link and
# -N option prevents downloading the file again if the remote is no newer
wpzipname="latest.tar.gz"
wget -qN http://wordpress.org/$wpzipname

# Extract the file to the requested directory
if ! [ -d $wpsitedir ]
then mkdir $wpsitedir
fi

tar xzf latest.tar.gz --directory $wpsitedir --strip-components=1

##### WORDPRESS CONFIGURATION #####
print ""
print "WordPress configuration" "underline"
print "Creating configuration files"

# Initialize variables
wpconfigdir=$wpsitedir".config"
wpconfigpath=$wpconfigdir"/"wp-config.php
wpconfigredirect=$wpsitedir"/"wp-config.php

# Create the directory that will hold the config file
if ! [ -d $wpconfigdir ]
then mkdir $wpconfigdir
fi

# Check to see if the wp-config file already exists
if [ -e $wpconfigpath ]
then rm $wpconfigpath
fi

# Create the wp-config file with values for the site
echo "<?php" > $wpconfigpath
echo "" >> $wpconfigpath
echo "define('DB_NAME', '"$sitemysqldb"');" >> $wpconfigpath
echo "define('DB_USER', '"$sitemysqluser"');" >> $wpconfigpath
echo "define('DB_PASSWORD', '"$sitemysqlpassword"');" >> $wpconfigpath
echo "define('DB_HOST', 'localhost');" >> $wpconfigpath
echo "define('DB_CHARSET', 'utf8mb4');" >> $wpconfigpath
echo "define('DB_COLLATE', 'utf8mb4_general_ci');" >> $wpconfigpath
echo "" >> $wpconfigpath
curl -s 1 https://api.wordpress.org/secret-key/1.1/salt >> $wpconfigpath
echo "" >> $wpconfigpath
echo "\$table_prefix  = 'tbl_';" >> $wpconfigpath
echo "define('WP_DEBUG', true);" >> $wpconfigpath

# Create a wp-config file in the site's directory that redirects to the
# real one in the config directory
echo "<?php" > $wpconfigredirect
echo "/** Absolute path to the WordPress directory. */" >> $wpconfigredirect
echo "if ( !defined('ABSPATH') )" >> $wpconfigredirect
echo "    define('ABSPATH', dirname(__FILE__) . '/');" >> $wpconfigredirect
echo "/** Location of your WordPress configuration. */" >> $wpconfigredirect
echo "require_once(dirname(dirname(__FILE__)) . '/newsite.config/wp-config.php');" >> $wpconfigredirect
echo "require_once(ABSPATH . 'wp-settings.php');" >> $wpconfigredirect

##### WORDPRESS INSTALLATION #####
print ""
print "WordPress installation" "underline"

# Download the file and create a link to the local version. The link and
# -N option prevents downloading the file again if the remote is no newer
wpcliname="wp-cli.phar"
wget -qN https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/$wpcliname

wpcliconfig="wp-cli.local.yml"
wpurl="http://programming/"$site
wpadminuser="cinc"$site
wpadminpassword="$(openssl rand -base64 10)"
wpeditoruser=$site
wpeditorpassword="$(openssl rand -base64 10)"

# Build the YML file used by the CLI program
echo "path: "$wpsitedir > $wpcliconfig
echo "user: "$wpadminuser >> $wpcliconfig
echo "color: true" >> $wpcliconfig
echo "debug: true" >> $wpcliconfig
echo "quiet: true" >> $wpcliconfig
echo "" >> $wpcliconfig
echo "core install:" >> $wpcliconfig
echo "	url: "$wpurl >> $wpcliconfig
echo "	title: "$sitename >> $wpcliconfig
echo "	admin_user: "$wpadminuser >> $wpcliconfig
echo "	admin_password: "$wpadminpassword >> $wpcliconfig
echo "	admin_email: "$adminemail >> $wpcliconfig
echo "" >> $wpcliconfig
echo "plugin update:" >> $wpcliconfig
echo "	all: true" >> $wpcliconfig
echo "" >> $wpcliconfig
echo "user create:" >> $wpcliconfig
echo "  role: editor" >> $wpcliconfig

print "Installing WordPress"
php $wpcliname core install
print "Updating plugins"
php $wpcliname plugin update
print "Creating users"
php $wpcliname user create $wpeditoruser $adminemail

##### SUCCESS #####
print ""
print "Installation successful" "bold"
print "Access the new site at:"
print "  "$wpurl
print "User accounts and passwords are:"
print "  Administrator: "$wpadminuser", "$wpadminpassword
print "  Editor: "$wpeditoruser", "$wpeditorpassword
