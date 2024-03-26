#!/bin/bash


set -x
filename="/nodelist.sh"
image="linux-image-5.13.0-1019-aws"

while read line; do
   echo Draining node $line
   kubectl drain $line --delete-emptydir-data --ignore-daemonsets
   echo Upgrading kernel on $line
   ssh -n root@$line "apt update; apt upgrade $image -y; shutdown -r now"; 
   sleep 60
   if ping -c 1 $line &> /dev/null
   then
     echo "Upgrade completed for $line"
     kubectl uncordon $line
   else
    echo Host is down, try again
    exit;
   fi
done < $filename

