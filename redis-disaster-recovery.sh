#!/bin/bash

#./redis-dr release 6382 

env=$1
REDIS_PORT=$2


if [ -n "$1" ]; then
  echo "Installing redis for $env environment"
else
  echo "Environment parameter not supplied while running script"
  exit;
fi

if [ -n "$2" ]; then
  echo "Redis Port is $REDIS_PORT"
else
  echo "Redis Port parameter not supplied while running script"
  exit;
fi

echo "Enter path for pem file"
read PEM_PATH

aws configure set aws_access_key_id 
aws configure set aws_secret_access_key 

aws autoscaling update-auto-scaling-group --auto-scaling-group-name Redis-DR --min-size 1 --max-size 1
echo "Waiting for EC2 Instance to start..."
sleep 180

aws --output text --query "Reservations[*].Instances[*].PrivateIpAddress" ec2 describe-instances --instance-ids `aws --output text --query "AutoScalingGroups[0].Instances[*].InstanceId" autoscaling describe-auto-scaling-groups --auto-scaling-group-names "Redis-DR"`> /tmp/masterIP
IP=$( cat /tmp/masterIP )
echo "IP address of EC2 instance is $IP"
echo "Starting with deployment"

cd /tmp
git clone $repo
cd $repo
git checkout redis-ec2
git pull --all
cd ansible/adhoc-playbooks

rm -f ../vars/redis_cluster_$env && touch ../vars/redis_cluster_$env
echo "[master]
$IP ansible_port=22" >> ../vars/redis_cluster_$env
ssh-keyscan -H $IP >> ~/.ssh/known_hosts

ansible-playbook redis_cluster.yml --vault-password-file ../.vault -i ../vars/redis_cluster_$env  --private-key $PEM_PATH -e "ansible_user=ec2-user role=master is_sentinel=true env=$env redis_master_ip=$IP"

echo "Redis installed, now restoring from backup"

aws configure set aws_access_key_id 
aws configure set aws_secret_access_key xfM4H++KaPMbprkqhW
bash -c "aws s3 ls $bucket/${env}_redis/ --recursive | sort | tail -n 1 > /tmp/metadata"
awk '{print $4}' /tmp/metadata  > /tmp/backupname
backupname=$( cat /tmp/backupname)

echo "Restoring from backup $backupname"

ssh ec2-user@$IP -i $PEM_PATH "aws configure set aws_access_key_id $aws_access_key_id"
ssh ec2-user@$IP -i $PEM_PATH "aws configure set aws_secret_access_key $aws_secret_access_key"
ssh ec2-user@$IP -i $PEM_PATH "aws s3 cp s3://$bucket/$backupname /tmp/dump.rdb"
ssh ec2-user@$IP -i $PEM_PATH "cp /tmp/dump.rdb /home/ec2-user/redis_sentinel_$env/data"

ssh ec2-user@$IP -i $PEM_PATH "/home/ec2-user/redis_sentinel_$env/redis-7.0.4/src/redis-server /home/ec2-user/redis_sentinel_$env/data/redis.conf &" 

echo "Waiting for redis to load keys in memory"
sleep 90
echo "Checking if redis is up after restore"
if redis-cli -h $IP -p $REDIS_PORT --no-auth-warning -a $password "ping"
then
   echo "Backup has been restored!"
   DBSIZE=$(redis-cli -h $IP -p $REDIS_PORT --no-auth-warning -a $password "DBSIZE")
   echo "Total number of keys in DB are $DBSIZE"
else 
   echo "Restore failed"
   exit
fi  



