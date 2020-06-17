#!/bin/bash



echo "use_proxy=yes" >> ~/.wgetrc
echo "http_proxy=x.x.x.x.:8080" >> ~/.wgetrc
echo "https_proxy=x.x.x.x:8080" >> ~/.wgetrc

 Find the Major Version

  if  grep -q -i "Red Hat Enterprise Linux Server" /etc/redhat-release
   then

    export  major_version=$(rpm -q --queryformat '%{RELEASE}' rpm | grep -o [[:digit:]]*\$)

  else

    echo -e "The OS is not REDHAT, please check and OS and act accordingly !!!\n"
    exit

  fi

# Install wget on the Vanilla system in case it is not there

  which wget > /dev/null 2>&1
  if [ $? -ne 0 ]
    then
     echo -e "Installing wget\n"

     yum install wget -y > /dev/null 2>&1

  fi

# Repo check for EPEL

  yum repolist | grep -q -i "^epel"

if [ $? -ne 0 ]
then


  if [ $major_version -eq 7 ]
    then

       echo -e "Downloading and installing EPEL repository for RHEL7\n"

       cd /tmp
       wget -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
       ls -lrt /tmp/epel*rpm
       echo -e "\n"

       echo -e "Installing the package EPEL\n"

       cd /tmp


       yum install epel-release-latest-7.noarch.rpm -y & > /dev/null 2>&1


  elif [ $major_version -eq 6 ]
      then

       echo -e "Checking the Architecture of the system\n"
       arch=$(/usr/bin/getconf LONG_BIT)

       if [ $arch -eq 64 ]
         then

           echo -e "Downloading and installing 64 bit EPEL repository for RHEL 6\n"


           cd /tmp
           wget -q http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
           ls -lrt /tmp/epel*rpm
           echo -e "\n"

           yum install epel-release-6-8.noarch.rpm -y > /dev/null 2>&1


       else

           echo -e "Downloading and installing 32 bit EPEL repository for RHEL 6\n"

           cd /tmp
           wget -q http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
           ls -lrt /tmp/epel*rpm
           echo -e "\n"


           yum install epel-release-6-8.noarch.rpm -y  > /dev/null 2>&1


      fi

  fi

fi


echo -e "Installing Nagios agent\n"

yum install nrpe nagios-plugins-all openssl -y > /dev/null 2>&1





echo -e "Taking a backup of NRPE config\n"

 cp /etc/nagios/nrpe.cfg /etc/nagios/nrpe.cfg.PreUp.`date +%F`

 ## Setting the env as per the region


       AWSREG=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')

       if [ "$AWSREG" == "eu-west-1" ]
         then

           export  NAGSERV="10.26.8.8"

       elif [ "$AWSREG" == "ap-southeast-2" ]
          then

            export NAGSERV="192.168.245.25"

      fi


 cat << EOF > /etc/nagios/nrpe.cfg
log_facility=daemon
pid_file=/var/run/nrpe/nrpe.pid
server_port=5666
nrpe_user=nrpe
nrpe_group=nrpe
allowed_hosts=127.0.0.1,$NAGSERV
dont_blame_nrpe=1
allow_bash_command_substitution=0
debug=0
command_timeout=60
connection_timeout=300
include_dir=/etc/nrpe.d/
EOF



# DOWNLOAD AND POPULATE THE NAGIOS COMMANDS



 arch=$(/usr/bin/getconf LONG_BIT)

 if  [ $arch -eq 64 ]
  then

     cd /usr/lib64/nagios/plugins/
     wget https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_mem/check_mem.pl
     mv check_mem.pl check_mem
     chmod +x check_mem

     echo "command[check_load]=/usr/lib64/nagios/plugins/check_load -w 15,10,5 -c 30,25,20" >> /etc/nagios/nrpe.cfg
     echo "command[check_zombie_procs]=/usr/lib64/nagios/plugins/check_procs -w 5 -c 6 -s Z" >> /etc/nagios/nrpe.cfg
     echo "command[check_total_procs]=/usr/lib64/nagios/plugins/check_procs -w 150 -c 200" >>   /etc/nagios/nrpe.cfg
     echo "command[check_mem]=/usr/lib64/nagios/plugins/check_mem -f -w 20 -c 10 -C" >> /etc/nagios/nrpe.cfg
     echo "command[check_disk]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /" >> /etc/nagios/nrpe.cfg

    ## Populating Disk Info

    for i in `df -Plh | grep "VolGroup00" | awk '{print $6}'| grep -v "^/$"| sed ':a;N;$!ba;s/\n/ /g' | sed -e "s/$/  \/boot/g"`
      do
        VAL=`echo "$i" | sed 's@^/@@g' | sed 's@/@_@g'`
        MOUNT=`df -h $i |  tail -n 1 | awk '{print $1}'`
       echo "command[check_disk_$VAL]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p $MOUNT" >> /etc/nagios/nrpe.cfg
    done

  else

        cd /usr/lib/nagios/plugins/
     wget https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_mem/check_mem.pl
     mv check_mem.pl check_mem
     chmod +x check_mem

     echo "command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20" >> /etc/nagios/nrpe.cfg
     echo "command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z" >> /etc/nagios/nrpe.cfg
     echo "command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 150 -c 200" >>   /etc/nagios/nrpe.cfg
     echo "command[check_mem]=/usr/lib/nagios/plugins/check_mem -f -w 20 -c 10 -C" >> /etc/nagios/nrpe.cfg
     echo "command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /" >> /etc/nagios/nrpe.cfg
    ## Populating Disk Info

    for i in `df -Plh | grep "VolGroup00" | awk '{print $6}'| grep -v "^/$" | sed ':a;N;$!ba;s/\n/ /g'| sed -e "s/$/  \/boot/g"`
      do
       VAL=`echo "$i" | sed 's@^/@@g' | sed 's@/@_@g'`
       MOUNT=`df -h $i |  tail -n 1 | awk '{print $1}'`
       echo "command[check_disk_$VAL]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p $MOUNT" >> /etc/nagios/nrpe.cfg
    done
fi


#sed -i "s/allowed_hosts=127.0.0.1,/allowed_hosts=127.0.0.1,$NAGSERV" /etc/nagios/nrpe.cfg

 ##  Starting the service

if [ $major_version -eq 7 ]
    then

        systemctl stop nrpe
        systemctl start nrpe
        systemctl enable nrpe.service


elif [ $major_version -eq 6 ]
      then

       /etc/init.d/nrpe start
       chkconfig --level 35 nrpe on

fi
