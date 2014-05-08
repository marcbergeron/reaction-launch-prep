reaction-launch-prep
====================

A script to run manually to set up a newly launched instance of the Amazon Linux AMI on EC2, such that
it can then be used to host Reaction Commerce store containers. This is a manual solution for now, which
will most likely eventually become a NodeJS app or in some way be part of the Reaction Launcher.

## Install reactionlp

To install reactionlp on your workstation (Mac or Linux), run this command in your terminal:

```bash
$ sudo -H curl https://raw.github.com/ongoworks/reaction-launch-prep/master/install | sh
```

If it doesn't work, the commands to do the installation yourself are something like this:

```bash
$ git clone https://github.com/ongoworks/reaction-launch-prep.git ~/.reactionlp
$ sudo ln -s ~/.reactionlp/reactionlp.sh /usr/local/bin/reactionlp
```

## First Steps

Before launching an EC2 instance or using the reactionlp script, log into the AWS Console and create a new
security group. It must:

* allow SSH from anywhere (or at least from your workstation's public IP address)
* allow TCP from anywhere on ports `49000 - 49900`

Create and configure this security group and note its name.

## Launching and Setting Up a New EC2 Instance

1. Launch a new Amazon Linux EC2 server. Accept the defaults in the wizard, and at the end, select the security group you created in the "First Steps" section. Select or create a `.pem` file that you have on your workstation.
2. SSH into the EC2 instance (click the "Connect" button on the "Instances" tab in AWS Console for instructions if you don't know how).
3. Enter `sudo visudo`. Near the bottom, press I to switch to insert mode and insert a ! before `requiretty`. This is necessary for the reactionlp script to work correctly. Press ESC and enter `:w!`. Now enter `:q` to quit. (TODO I think this can be done upon launch with a cloudinit script. Need to investigate.)
4. On your workstation, open a Terminal session and enter `reactionlp`. Answer the prompts. The host is the IP address displayed for the EC2 instance in AWS Console, and the key file is the `.pem` file you selected or created.

When the script completes, the EC2 instance should be ready to run docker containers.

## (Temporary) Creating a Store Image and Running A Store Container

These steps are for getting this done manually for now. The eventual process will be different.

### Create a Store Image

The idea here is to create one docker image per release of the main `reaction` app. Eventually this should be done on a developer's workstation and then we should export the image and store the archive somewhere, probably in an S3 bucket. But for now, we can build the image right on the EC2 instance on which we are going to run it:

1. SSH into the EC2 instance. (We're assuming you've already run `reactionlp` to set it up.)
2. `cd ~`
3. `git clone https://github.com/ongoworks/reaction.git` (or pull it if you've already cloned it)
4. `cd reaction`
5. Possibly switch to another branch, commit, or tag. Whatever you want to build the docker image from.
6. `mrt install`
7. `meteor bundle bundle.tar.gz`
8. `sudo docker build -t reaction/store .` ("reaction/store" is the desired name for the docker image and should ideally indicate the release or the branch from which it was built, for example, "reaction/store_v1.0")
9. Enter `sudo docker images` to verify that your image shows up.

### Run a Store Container

When you run an image, it creates a container based on that image. So the idea here is that we will eventually run many containers (based on the same or different image) on each EC2 instance, and only spawn a new EC2 instance when we hit the max # of containers on all instances (whatever that may be based on memory, CPU, etc.).

For each "store instance" we want:

```bash
$ sudo docker run -d -e "MONGO_URL=<mongo_url>" -e "ROOT_URL=<root_url>" -p 8080 --name="store1234" reaction/store
```

Details:

* The root URL will be whatever is the canonical root URL for the store (http(s)://store1234.reactioncommerce.com or http(s)://customdomain.com depending on plan, certs).
* The MONGO_URL will also be either a shared DB or custom depending on plan. If developer access is required, we can't use a shared URL.
* By default, the container will be running the reaction app on the internal container port 8080. The `-p 8080` option here tells docker to map this container port to a random port on the host. We can lookup that port after.
* "reaction/store" is the name of the image to use. Eventually, we would be choosing between various versioned images such as "reaction/store_v1.0"
* The `--name` option names the container for easier access. We will name them after the subdomain that store is assigned, I think.
* The `-d` option keeps the container running as a daemon. It will also restart when the EC2 instance is restarted. It will *not* restart if the container dies because the reaction app dies. (TODO We can use supervisor to do restarts on error.)

Now we can find out what external port this container app is available on:

```bash
$ docker port store1234 8080
```

This will print a port number between 49000 and 49900. Let's say it is 49555 and your EC2 instance has the IP address 11.111.11.111. You can now test that it's working by going to the following in your browser: `http://11.111.11.111:49555`

(TODO) Eventually we will want to do additional DNS tasks, mapping subdomains and custom domains to the EC2 instance. We will also need a proxy solution, so that port 80 can be used and we route to the specific port (e.g., 49555) based on the requested hostname. Also, we can launch ELBs to terminate SSL and support custom certs.