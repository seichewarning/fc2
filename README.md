# FC2 - Forecast Command and Control

---------------------------------------------------------------

### This script is mean to be run on a regular basis via a cron
### job and copy over the output files from the WRF model
### to an AWS S3 bucket.  It should
### be run on a separate instance than the model machine.
### Please see the heading of the fc2.rb file for constants that
### need to be configured.

---------------------------------------------------------------


FC2-MICRO:
This is the name for the EC2 mirco instance running the file
copying script.
When creating an image for this machine, it's best to create a 
medium or large one, other wise it might run out of memory installing
everything.


MODEL-M5:
This is the name for the large instance running the models.

----------------------------------------------------------------------


Instructions for setting up the MODEL-M5 instance:
  - ssh into the instance as user 'ubuntu'.  If its' set up
    as a different user simply replace 'ubuntu' with that
    user everywhere below.

  - run these commands
     ```bash
     sudo apt-get -y update && sudo apt-get -y upgrade
     sudo apt-get install -y awscli
     ```

  - configure AWS credentials, run
      ```bash
      aws configure
     ```
    then get give it the information it asks for.



----------------------------------------------------------------------


Instructions for setting up the FC2-MICRO instance:
  - ssh into the instance as user 'ubuntu'.  If its' set up
    as a different user simply replace 'ubuntu' with that
    user everywhere below.

  - run these commands
     ```bash
     sudo apt-get -y update && sudo apt-get -y upgrade
     sudo apt-get -y install ruby
     sudo apt-get install -y awscli
     sudo gem install aws-sdk-ec2 --verbose
     sudo gem install aws-sdk-s3 --verbose
     ```

  - configure AWS credentials, run
      ```bash
      aws configure
     ```
    then get give it the information it asks for.

  - run these commands
     ```bash
     git clone https://github.com/seichewarning/fc2.git ~/code/fc2
     ssh-keygen -t rsa -N "" -f ~/.ssh/fc2
     chmod 600 ~/.ssh/fc2
     touch ~/.ssh/config
     chmod 600 ~/.ssh/config
     echo 'IdentityFile ~/.ssh/fc2' > ~/.ssh/config
     cat ~/.ssh/fc2.pub
     ```

  - copy the output from the public key above.

  - ssh into the MODEL-M5 instance as user ubuntu and run
     ```bash
     cat > ~/.ssh/authorized_keys
     ```

  - the above command expects input, paste the public key
    into here.  Hit Enter, Hit ctrl+D when done to close and save the file.

  - ssh back into the FC2-MICRO instance.

  - verify you can ssh into the MODEL-M5 instance from the FC2-MICRO
    instance by running this.  Use the prive IP address, hit yes if asked
     ```bash
      ssh ubuntu@MODEL-M5.private-ip-address
     ```

  - edit the crontab logged in as 'ubuntu' via the command
      ```bash
      crontab -e
     ```
 
  - add the following line
      ```vim
      * * * * * /usr/bin/ruby /home/ubuntu/code/fc2/fc2.rb
     ```

  - the copying script should be running now and the logging and
    status of the script can be monitored via the file found at
       ```
       /home/ubuntu/code/fc2/out.log
     ```




