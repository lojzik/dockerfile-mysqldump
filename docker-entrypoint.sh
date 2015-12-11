#!/bin/sh
set -e
MYSQL_USER=$MYSQLDUMP_USER
MYSQL_PASS=$MYSQLDUMP_PASSWORD
MYSQL_HOST=$MYSQLDUMP_HOST
BACKUP_DIR="/backup/"
MYSQL_IMAGE=$MYSQLDUMP_IMAGE
MYSQL_CONTAINER=$MYSQLDUMP_CONTAINER
ZBYTEK=""
while [ "$#" != "0" ]; do

if [ "$1" = "-i" ]; then
MYSQL_IMAGE="$2"
shift
elif [ "$1" = "-u" ]; then
MYSQL_USER="$2"
shift
elif [ "$1" = "-p" ]; then
MYSQL_PASS="$2"
shift
elif [ "$1" = "-c" ]; then
MYSQL_CONTAINER="$2"
shift
elif [ "$1" = "-h" ]; then
MYSQL_HOST="$2"
shift
else
ZBYTE="$ZBYTEK $1"
fi
shift
done
echo "mysqldump image: $MYSQL_IMAGE"
echo "mysql host: $MYSQL_HOST"
#echo "mysql pass: $MYSQL_PASS"
echo "mysql container: $MYSQL_CONTAINER"
echo "mysql user: $MYSQL_USER"

ERR=0
if [ -z "$MYSQL_IMAGE" ];then
echo "image missing"
ERR=1
fi
if [ -z "$MYSQL_HOST" ];then
echo "host missing"
ERR=1
fi
if [ -z "$MYSQL_PASS" ];then
echo "password missing"
ERR=1
fi
if [ -z "$MYSQL_CONTAINER" ];then
echo "container missing"
ERR=1
fi
if [ -z "$MYSQL_USER" ];then
echo "user missing"
ERR=1
fi

if [ $ERR = 1 ]; then
echo "params: -u user -p password -i mysqldump_image -c mysql_container -h mysql_host"
exit 1
fi


mkdir -p $BACKUP_DIR
echo "SET autocommit=0;SET unique_checks=0;SET foreign_key_checks=0;" > tmp_sqlhead.sql
echo "SET autocommit=1;SET unique_checks=1;SET foreign_key_checks=1;" > tmp_sqlend.sql

if [ -z "$1" ]
  then
    echo "-- Dumping all DB ..."
    for I in $(docker run --rm --link $MYSQL_CONTAINER $MYSQL_IMAGE mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASS -e 'show databases' -s --skip-column-names); 
    do
      if [ "$I" = information_schema ] || [ "$I" =  mysql ] || [ "$I" =  phpmyadmin ] || [ "$I" =  performance_schema ]  # exclude this DB
      then
         echo "-- Skip $I ..."
       continue
      fi
      echo "-- Dumping $I ..."
      # Pipe compress and concat the head/end with the stoutput of mysqlump ( '-' cat argument)
      docker run --rm --link $MYSQL_CONTAINER $MYSQL_IMAGE mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASS $I | cat tmp_sqlhead.sql - tmp_sqlend.sql | gzip -fc > "$BACKUP_DIR$I.sql.gz" 
    done

else
      I=$1;
      echo "-- Dumping $I ..."
      # Pipe compress and concat the head/end with the stoutput of mysqlump ( '-' cat argument)
      docker run --rm --link $MYSQL_CONTAINER $MYSQL_IMAGE mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASS $I | cat tmp_sqlhead.sql - tmp_sqlend.sql | gzip -fc > "$BACKUP_DIR$I.sql.gz" 
fi

# remove tmp files
rm tmp_sqlhead.sql
rm tmp_sqlend.sql

echo "-- FINISH --"