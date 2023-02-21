#!/bin/sh

# installer_install_rivendell.sh
#
# Install Rivendell 4.x on a CentOS 7 system
#

#
# Site Defines
#
REPO_HOSTNAME="software.paravelsystems.com"

#
# Get Target Mode
#
if test $1 ; then
    case "$1" in
	--client)
	    MODE="client"
	    ;;

	--server)
	    MODE="server"
	    IP_ADDR=$2
	    ;;

	--standalone)
	    MODE="standalone"
	    ;;

	*)
	    echo "USAGE: ./install_rivendell.sh --client|--server|--standalone"
	    exit 256
            ;;
    esac
else
    MODE="standalone"
fi

#
# Configure Repos
#
yum -y install epel-release
wget http://$REPO_HOSTNAME/CentOS/7com/Paravel-Commercial.repo -P /etc/yum.repos.d/

#
# Install XFCE4
#
yum -y groupinstall "X window system"
yum -y groupinstall xfce
systemctl set-default graphical.target

#
# Install Dependencies
#
yum -y install patch evince telnet lwmon nc samba paravelview ntp emacs twolame libmad nfs-utils cifs-utils samba-client ssvnc xfce4-screenshooter net-tools alsa-utils cups tigervnc-server-minimal pygtk2 cups system-config-printer gedit ntfs-3g ntfsprogs autofs

if test $MODE = "server" ; then
    #
    # Install MariaDB
    #
    yum -y install mariadb-server
    systemctl start mariadb
    systemctl enable mariadb

    #
    # Enable DB Access for localhost
    #
    echo "CREATE DATABASE Rivendell;" | mysql -u root
    echo "CREATE USER 'rduser'@'localhost' IDENTIFIED BY 'letmein';" | mysql -u root
    echo "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,CREATE TEMPORARY TABLES,LOCK TABLES ON Rivendell.* TO 'rduser'@'localhost';" | mysql -u root

    #
    # Enable DB Access for all remote hosts
    #
    echo "CREATE USER 'rduser'@'%' IDENTIFIED BY 'letmein';" | mysql -u root
    echo "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,CREATE TEMPORARY TABLES,LOCK TABLES ON Rivendell.* TO 'rduser'@'%';" | mysql -u root

    #
    # Enable NFS Access for all remote hosts
    #
    echo "/var/snd *(rw,no_root_squash)" >> /etc/exports
    echo "/home/rd/rd_xfer *(rw,no_root_squash)" >> /etc/exports
    echo "/home/rd/music_export *(rw,no_root_squash)" >> /etc/exports
    echo "/home/rd/music_import *(rw,no_root_squash)" >> /etc/exports
    echo "/home/rd/traffic_export *(rw,no_root_squash)" >> /etc/exports
    echo "/home/rd/traffic_import *(rw,no_root_squash)" >> /etc/exports
    systemctl enable rpcbind
    systemctl enable nfs-server

    #
    # Enable CIFS File Sharing
    #
    systemctl enable smb
    systemctl enable nmb
fi

if test $MODE = "standalone" ; then
    #
    # Install MariaDB
    #
    yum -y install mariadb-server
    systemctl start mariadb
    systemctl enable mariadb
    mkdir -p /etc/systemd/system/mariadb.service.d/
    cp /usr/share/rhel-rivendell-installer/limits.conf /etc/systemd/system/mariadb.service.d/
    systemctl daemon-reload

    #
    # Enable DB Access for localhost
    #
    echo "CREATE DATABASE Rivendell;" | mysql -u root
    echo "CREATE USER 'rduser'@'localhost' IDENTIFIED BY 'letmein';" | mysql -u root
    echo "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,CREATE TEMPORARY TABLES,LOCK TABLES ON Rivendell.* TO 'rduser'@'localhost';" | mysql -u root

    #
    # Enable CIFS File Sharing
    #
    systemctl enable smb
    systemctl enable nmb
fi

#
# Install Rivendell
#
patch -p0 /etc/rsyslog.conf /usr/share/rhel-rivendell-installer/rsyslog.conf.patch
cp -f /usr/share/rhel-rivendell-installer/selinux.config /etc/selinux/config
systemctl disable firewalld
yum -y remove chrony openbox
systemctl start ntpd
systemctl enable ntpd
rm -f /etc/asound.conf
cp /usr/share/rhel-rivendell-installer/asihpi.conf /etc/modprobe.d/
cp /usr/share/rhel-rivendell-installer/asound.conf /etc/
cp /usr/share/rhel-rivendell-installer/Reyware.repo /etc/yum.repos.d/
cp /usr/share/rhel-rivendell-installer/RPM-GPG-KEY-Reyware /etc/pki/rpm-gpg/
mkdir -p /usr/share/pixmaps/rivendell
cp /usr/share/rhel-rivendell-installer/rdairplay_skin.png /usr/share/pixmaps/rivendell/
cp /usr/share/rhel-rivendell-installer/rdpanel_skin.png /usr/share/pixmaps/rivendell/
mv /etc/samba/smb.conf /etc/samba/smb-original.conf
cp /usr/share/rhel-rivendell-installer/smb.conf /etc/samba/
cp /usr/share/rhel-rivendell-installer/no_screen_blank.conf /etc/X11/xorg.conf.d/
mkdir -p /etc/skel/Desktop
cp /usr/share/rhel-rivendell-installer/skel/paravel_support.pdf /etc/skel/Desktop/First\ Steps.pdf
ln -s /usr/share/rivendell/opsguide.pdf /etc/skel/Desktop/Operations\ Guide.pdf
tar -C /etc/skel -zxf /usr/share/rhel-rivendell-installer/xfce-config.tgz
adduser -c Rivendell\ Audio --groups audio,wheel rd
chown -R rd:rd /home/rd
chmod 0755 /home/rd
patch /etc/gdm/custom.conf /usr/share/rhel-rivendell-installer/autologin.patch
yum -y remove alsa-firmware alsa-firmware-tools
yum -y install lame rivendell

if test $MODE = "server" ; then
    #
    # Initialize Automounter
    #
    cp -f /usr/share/rhel-rivendell-installer/auto.misc.template /etc/auto.misc
    systemctl enable autofs

    #
    # Create Rivendell Database
    #
    rddbmgr --create --generate-audio
    echo "update STATIONS set REPORT_EDITOR_PATH=\"/usr/bin/gedit\"" | mysql -u rduser -pletmein Rivendell

    #
    # Create common directories
    #
    mkdir -p /home/rd/rd_xfer
    chown rd:rd /home/rd/rd_xfer

    mkdir -p /home/rd/music_export
    chown rd:rd /home/rd/music_export

    mkdir -p /home/rd/music_import
    chown rd:rd /home/rd/music_import

    mkdir -p /home/rd/traffic_export
    chown rd:rd /home/rd/traffic_export

    mkdir -p /home/rd/traffic_import
    chown rd:rd /home/rd/traffic_import
fi

if test $MODE = "standalone" ; then
    #
    # Initialize Automounter
    #
    cp -f /usr/share/rhel-rivendell-installer/auto.misc.template /etc/auto.misc
    systemctl enable autofs

    #
    # Create Rivendell Database
    #
    rddbmgr --create --generate-audio
    echo "update STATIONS set REPORT_EDITOR_PATH=\"/usr/bin/gedit\"" | mysql -u rduser -pletmein Rivendell

    #
    # Create common directories
    #
    mkdir -p /home/rd/rd_xfer
    chown rd:rd /home/rd/rd_xfer

    mkdir -p /home/rd/music_export
    chown rd:rd /home/rd/music_export

    mkdir -p /home/rd/music_import
    chown rd:rd /home/rd/music_import

    mkdir -p /home/rd/traffic_export
    chown rd:rd /home/rd/traffic_export

    mkdir -p /home/rd/traffic_import
    chown rd:rd /home/rd/traffic_import
fi

if test $MODE = "client" ; then
    #
    # Initialize Automounter
    #
    rm -f /etc/auto.rd.audiostore
    cat /usr/share/rhel-rivendell-installer/auto.rd.audiostore.template | sed s/@IP_ADDRESS@/$IP_ADDR/g > /etc/auto.rd.audiostore

    rm -f /home/rd/rd_xfer
    ln -s /misc/rd_xfer /home/rd/rd_xfer
    rm -f /home/rd/music_export
    ln -s /misc/music_export /home/rd/music_export
    rm -f /home/rd/music_import
    ln -s /misc/music_import /home/rd/music_import
    rm -f /home/rd/traffic_export
    ln -s /misc/traffic_export /home/rd/traffic_export
    rm -f /home/rd/traffic_import
    ln -s /misc/traffic_import /home/rd/traffic_import
    rm -f /etc/auto.misc
    cat /usr/share/rhel-rivendell-installer/auto.misc.client_template | sed s/@IP_ADDRESS@/$IP_ADDR/g > /etc/auto.misc
    systemctl enable autofs

    #
    # Configure Rivendell
    #
    cat /etc/rd.conf | sed s/localhost/$IP_ADDR/g > /etc/rd-temp.conf
    rm -f /etc/rd.conf
    mv /etc/rd-temp.conf /etc/rd.conf
fi

#
# Finish Up
#
echo
echo "Installation of Rivendell is complete.  Reboot now."
echo
echo "IMPORTANT: Be sure to see the FINAL DETAILS section in the instructions"
echo "           to ensure that your new Rivendell system is properly secured."
echo
