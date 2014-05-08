#!/bin/sh

echo
echo "Enter the hostname or IP address of the Amazon Linux EC2 server."
echo "Examples: 11.111.11.111 or ec2-11-111-11-111.us-west-2.compute.amazonaws.com"
read -e -p "Host: " APP_HOST
echo
echo "Enter the path to your EC2 .pem file on this machine."
read -e -p "Key file: " EC2_PEM_FILE

SSH_HOST="ec2-user@$APP_HOST"
SSH_OPT="-i $EC2_PEM_FILE"

echo "Preparing server..."
ssh $SSH_OPT $SSH_HOST <<EOL
    echo "Updating..."
    sudo yum update -q -y

    echo "Installing prerequisites..."
    sudo yum install -q -y gcc gcc-c++ make git openssl-devel freetype-devel fontconfig-devel

    echo "Installing Node and NPM..."
    sudo yum install -q -y nodejs npm --enablerepo=epel

    echo "Installing docker and starting docker daemon..."
    sudo yum install -q -y docker
    sudo service docker start

    echo "Installing or updating Meteor..."
    sudo -H curl https://install.meteor.com | /bin/sh

    echo "Installing or updating Meteorite..."
    sudo -H npm install -g meteorite
EOL