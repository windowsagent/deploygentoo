#!/bin/bash
#this puts some things in place like your make.conf, aswell as package.use
LIGHTGREEN='\033[1;32m'
LIGHTRED='\033[1;91m'
WHITE='\033[1;97m'
MAGENTA='\033[1;35m'
CYAN='\033[1;96m'
cd ..
start_dir=$(pwd)
printf ${MAGENTA}"MAKE SURE YOUR ROOT PARTITION IS THE 2ND ONE ON THE DEVICE YOU'LL BE INSTALLING TO\n\n"
fdisk -l >> devices
ifconfig -s >> nw_devices
cut -d ' ' -f1 nw_devices >> network_devices
rm -rf nw_devices
sed -e "s/lo//g" -i network_devices
sed -e "s/Iface//g" -i network_devices
sed '/^$/d' network_devices
sed -e '\#Disk /dev/ram#,+5d' -i devices
sed -e '\#Disk /dev/loop#,+5d' -i devices

done
#copying files into place
cd /mnt/gentoo/deploygentoo-master

printf "enter a number for the stage 3 you want to use\n"
printf "0 = regular hardened\n1 = hardened musl\n2 = vanilla musl\n>"
read stage3select
printf ${CYAN}"Enter the username for your NON ROOT user\n>"
#There is a possibility this won't work since the handbook creates a user after rebooting and logging as root
read username
username="${username,,}"
printf ${CYAN}"Enter the Hostname you want to use\n>"
read hostname
printf ${CYAN}"Do you want to replace OpenSSL with LibreSSL (recommended) in your system?(yes or no)\n>"
read sslanswer
sslanswer="${sslanswer,,}"
printf ${CYAN}"Do you want to do performance optimizations. LTO -O3 and Graphite?(yes or no)\n>"
read performance_opts
performance_opts="${performance_opts,,}"
printf ${LIGHTGREEN}"Beginning installation, this will take several minutes\n"
install_vars=/mnt/gentoo/deploygentoo-master/install_vars
cpus=$(grep -c ^processor /proc/cpuinfo)
pluscpus=$((cpus+1))
echo "$disk" >> "$install_vars"
echo "$username" >> "$install_vars"
echo "$kernelanswer" >> "$install_vars"
echo "$hostname" >> "$install_vars"
echo "$sslanswer" >> "$install_vars"
echo "$cpus" >> "$install_vars"
echo "$part_3" >> "$install_vars"
echo "$part_1" >> "$install_vars"
echo "$part_2" >> "$install_vars"
echo "$part_4" >> "$install_vars"
echo "$performance_opts" >> "$install_vars"
cat network_devices >> "$install_vars"
case $stage3select in
  0)
    GENTOO_TYPE=latest-stage3-amd64-hardened
    ;;
  1)
    GENTOO_TYPE=latest-stage3-amd64-musl-hardened
    ;;
  2)
    GENTOO_TYPE=latest-stage3-amd64-musl-vanilla
    ;;
esac

STAGE3_PATH_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$GENTOO_TYPE.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_PATH
touch /mnt/gentoo/gentootype.txt
echo $GENTOO_TYPE >> /mnt/gentoo/gentootype.txt
cd /mnt/gentoo/
while [ 1 ]; do
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 $STAGE3_URL
	if [ $? = 0 ]; then break; fi;
	sleep 1s;
done;
check_file_exists () {
	file=$1
	if [ -e $file ]; then
		exists=true
	else
		printf "%s doesn't exist\n" $file
		wget --tries=20 $STAGE3_URL
		exists=false
		$2
	fi
}

check_file_exists /mnt/gentoo/stage3*
stage3=$(ls /mnt/gentoo/stage3*)
tar xpvf $stage3 --xattrs-include='*.*' --numeric-owner
printf "unpacked stage 3\n"

#rm -rf /mnt/gentoo/etc/portage
cd /mnt/gentoo/deploygentoo-master/gentoo/
cp -a /mnt/gentoo/deploygentoo-master/gentoo/portage/package.use/. /mnt/gentoo/etc/portage/package.use/
cd /mnt/gentoo/
mkdir /mnt/gentoo/etc/portage/backup/
mv /mnt/gentoo/etc/portage/make.conf /mnt/gentoo/etc/portage/backup/
printf "moved old make.conf to /backup/\n"
##copies our pre-made make.conf over
cp /mnt/gentoo/deploygentoo-master/gentoo/portage/make.conf /mnt/gentoo/etc/portage/
printf "copied new make.conf to /etc/portage/\n"
printf "there are %s cpus\n" $cpus
sed -i "s/MAKEOPTS=\"-j3\"/MAKEOPTS=\"-j$pluscpus -l$cpus\"/g" /mnt/gentoo/etc/portage/make.conf
sed -i "s/--jobs=3  --load-average=3/--jobs=$cpus  --load-average=$cpus/g" /mnt/gentoo/etc/portage/make.conf
printf "moved portage files into place\n"

cp /mnt/gentoo/deploygentoo-master/gentoo/portage/linux_drivers /mnt/gentoo/etc/portage/
cp /mnt/gentoo/deploygentoo-master/gentoo/portage/nvidia_package.license /mnt/gentoo/etc/portage/
cp /mnt/gentoo/deploygentoo-master/gentoo/portage/package.license /mnt/gentoo/etc/portage
cp /mnt/gentoo/deploygentoo-master/gentoo/portage/package.accept_keywords /mnt/gentoo/etc/portage/
cp -r /mnt/gentoo/deploygentoo-master/gentoo/portage/profile /mnt/gentoo/etc/portage/

mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
printf "copied gentoo repository to repos.conf\n"
#
##copy DNS info
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
printf "copied over DNS info\n"

cp /mnt/gentoo/deploygentoo-master/post_chroot.sh /mnt/gentoo/
cp /mnt/gentoo/deploygentoo-master/install_vars /mnt/gentoo/
printf "copied post_chroot.sh to /mnt/gentoo\n"
chmod +x /mnt/gentoo/post_chroot.sh

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

cd /mnt/gentoo/
chroot /mnt/gentoo ./post_chroot.sh
