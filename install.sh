#!/bin/bash
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
print ""

##### MYSQL DATABASE CREATION #####
# Initialize variables
sitemysqldb=$site"wpdb"
sitemysqlpassword=$site"pw"
sitemysqlscript=$site".sql"
sitemysqluser=$site"user"

print "MySQL database" "underline"
print "Creating a new MySQL database named "$sitemysqldb
print ""

# Create a script file with the MySql commands
echo "CREATE DATABASE IF NOT EXISTS "$sitemysqldb";" > $sitemysqlscript
#echo "CREATE USER IF NOT EXISTS "$sitemysqluser"@localhost IDENTIFIED BY '"$sitemysqlpassword"';" >> $sitemysqlscript
echo "GRANT ALL PRIVILEGES ON "$sitemysqldb".* TO "$sitemysqluser"@localhost IDENTIFIED BY '"$sitemysqlpassword"';" >> $sitemysqlscript
echo "FLUSH PRIVILEGES;" >> $sitemysqlscript

# Set up a trap that will ensure the script is always deleted, even in case
# of an error
trap "rm "$sitemysqlscript EXIT

# Run the script file using the MySql command line utility
mysql -u root < $sitemysqlscript

##### WORDPRESS DOWNLOAD *****
print "WordPress download" "underline"
print "Downloading latest WordPress installation"
print ""

# Download the file and create a link to the local version. The link and
# -N option prevents downloading the file again if the remote is no newer
wpzipname="latest.tar.gz"
wget -qN http://wordpress.org/$wpzipname

# Extract the file to the requested directory
if ! [ -d $rootdir"/"$site ]
then mkdir $rootdir"/"$site
fi

tar xzf latest.tar.gz --directory $rootdir"/"$site --strip-components=1
