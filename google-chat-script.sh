#!/bin/bash
# Script to notify Google Chat of latest package changes in Ubuntu or
# CentOS.
#
# Based on original work by Rick Harrison available at:
# https://github.com/fortybelowzero/server-package-updates-to-slack
#
# Setup:
#  - Change values in the configuration section below
#  - Add this as a cron-job - we run it every 15 minutes with this cron entry as root:
#    */15 * * * * root  /bin/bash /usr/local/bin/notify_updates > /dev/null 2>&1
#

# ==== CONFIGURATION =========================================================

# How often you are running this in cron (must match the same frequency. This string needs to be in the format unix date command can parse, eg:
# 1 hour
# 2 hours
# 15 minutes
FREQUENCY="15 minutes"

# Google Chat WebHook Url to post the message to. Commented out here as I set it on the server as an environment variable, you could either do that or
# uncomment and add your own Google Chat API Hook url here:
#GCHAT_HOOK_URL="https://chat.googleapis.com/v1/spaces/XXXXXXXXX/messages?key=YYYYYYYYYY&token=ZZZZZZZZZZ"

# Other Google Chat config settings.

GCHAT_POST_THUMBNAIL_UBUNTU="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png"
GCHAT_POST_THUMBNAIL_CENTOS="https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/CentOS_logo.svg/500px-CentOS_logo.svg.png"
GCHAT_POST_THUMBNAIL=$GCHAT_POST_THUMBNAIL_UBUNTU

# Name of the server to use in the Google Chat message title. By default below we're using the servers' own hostname, feel free to swap it to a
# string if theres something you'd rather use to identify the server instead.
SERVERNAME=$(hostname)

# ==== END OF CONFIGURATION =========================================================

# distro-finding - try to work out what linux flavour we're under.
# Currently this script support redhat/centos and ubuntu. Feel free to PR amends to include other distros.
# Hat-tip: https://askubuntu.com/a/459425

UNAME=$(uname | tr "[:upper:]" "[:lower:]")
# If Linux, try to determine specific distribution
if [ "$UNAME" == "linux" ]; then
   # If available, use LSB to identify distribution
   if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
       export DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
   # Otherwise, use release info file
   else
       export DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
   fi
fi
# For everything else (or if above failed), just use generic identifier
[ "$DISTRO" == "" ] && export DISTRO=$UNAME
unset UNAME

# /distro-finding

LASTFREQUENCY=$(date -d "$FREQUENCY ago" +"%s")
NOWTIME=$(date -d 'NOW'  +"%F %H:%M:%S")


# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS REDHAT OR CENTOS ------------------

if [[ ${DISTRO,,} == *"redhat"* ]] || [[ ${DISTRO,,} == *"centos"* ]] ; then
   GCHAT_POST_THUMBNAIL=$GCHAT_POST_THUMBNAIL_CENTOS
   rpm -qa --last | head -30 | while read -a linearray ; do
       PACKAGE='<font color=\"#11111\">'${linearray[0]}'</font><br>'
       DATETIMESTR="${linearray[1]} ${linearray[2]} ${linearray[3]} ${linearray[4]} ${linearray[5]} ${linearray[6]}"
       INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
       if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
           echo "$PACKAGE" >> /tmp/package-updates-google-chat-announce.txt
       fi
   done

# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS UBUNTU ------------------

elif [[ ${DISTRO,,} == *"ubuntu"* ]] ; then
   GCHAT_POST_THUMBNAIL=$GCHAT_POST_THUMBNAIL_UBUNTU
   cat /var/log/dpkg.log | grep "\ installed\ " | tail -n 30 | while read -a linearray ; do
       PACKAGE='<font color=\"#11111\">'${linearray[4]}'</font> ~ <font color=\"#aaaaaa\">'${linearray[5]}'</font><br>'
       DATETIMESTR="${linearray[0]} ${linearray[1]}"
       INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
       if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
           echo "$PACKAGE" >> /tmp/package-updates-google-chat-announce.txt
       fi
   done

# --------------- OTHER LINUX DISTROS ARE UNTESTED - ABORT. ------------------
else
   echo "ERROR: Untested/unsupported linux distro - Centos/Redhat/Ubuntu currently supported, feel free to amend for other distros and submit a PR."
fi

# --------------- IF PACKAGED WERE INSTALLED (THERES A TEMPORARY FILE WITH THEM LISTED IN IT) THEN SEND A GOOGLE CHAT NOTIFICATION. -------------
if [ -f /tmp/package-updates-google-chat-announce.txt ]; then

   echo "$NOWTIME - notifying updates to Google Chat..."
   INSTALLATIONS=$(cat /tmp/package-updates-google-chat-announce.txt)
   curl -X POST -H 'Content-Type: application/json' $GCHAT_HOOK_URL -d '{"cards": [{"header": {"title": "'"$SERVERNAME"'","subtitle": "'"$NOWTIME"'","imageUrl": "'"$GCHAT_POST_THUMBNAIL"'","imageStyle": "IMAGE"},"sections": [{"widgets": [{"textParagraph": {"text": "'"$INSTALLATIONS"'"}}]}]}]}'
   rm -f /tmp/package-updates-google-chat-announce.txt
fi
