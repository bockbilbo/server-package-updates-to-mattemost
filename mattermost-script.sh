#!/bin/bash
# Script to notify Mattermost of latest package changes in Ubuntu or
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

# Mattermost Hook Url to post the message to. Commented out here as I set it on the server as an environment variable, you could either do that or
# uncomment and add your own Mattermost API Hook url here:
# MM_HOOK_URL="https://mattermost.domain.gbl/hooks/XXXXXXXXXXXX"


# Other Mattermost config settings.
MM_CHANNEL_NAME="#server-updates"
MM_POST_THUMBNAIL_UBUNTU="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png"
MM_POST_THUMBNAIL_CENTOS="https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/CentOS_logo.svg/500px-CentOS_logo.svg.png"
MM_POST_THUMBNAIL=$MM_POST_THUMBNAIL_UBUNTU

MM_POST_USERNAME="update-notifier"
MM_POST_USERNAME_ICON="https://icons-for-free.com/download-icon-refresh+reload+update+icon-1320191166843452904_512.png"

# Name of the server to use in the mattermost message title. By default below we're using the servers' own hostname, feel free to swap it to a
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
NOWTIME=$(date -d 'NOW'  +"%F")

# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS REDHAT OR CENTOS ------------------

if [[ ${DISTRO,,} == *"redhat"* ]] || [[ ${DISTRO,,} == *"centos"* ]] ; then
    MM_POST_THUMBNAIL=$MM_POST_THUMBNAIL_CENTOS
    rpm -qa --last | head -30 | while read -a linearray ; do
        PACKAGE=${linearray[0]}
        DATETIMESTR="${linearray[1]} ${linearray[2]} ${linearray[3]} ${linearray[4]} ${linearray[5]} ${linearray[6]}"
        INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
        if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
            echo "$PACKAGE    ($DATETIMESTR)\n" >> /tmp/package-updates-mattermost-announce.txt
        fi
    done

# --------------- DEAL WITH PACKAGES INSTALLED IF LINUX DISTRIBUTION IS UBUNTU ------------------

elif [[ ${DISTRO,,} == *"ubuntu"* ]] ; then
    MM_POST_THUMBNAIL=$MM_POST_THUMBNAIL_UBUNTU
    cat /var/log/dpkg.log | grep "\ installed\ " | tail -n 30 | while read -a linearray ; do
        PACKAGE="${linearray[3]} ${linearray[4]} ${linearray[5]}"
        DATETIMESTR="${linearray[0]} ${linearray[1]}"
        INSTALLTIME=$(date --date="$DATETIMESTR" +"%s")
        if [ "$INSTALLTIME" -ge "$LASTFREQUENCY" ]; then
            echo "$PACKAGE    ($DATETIMESTR)\n" >> /tmp/package-updates-mattermost-announce.txt
        fi
    done

# --------------- OTHER LINUX DISTROS ARE UNTESTED - ABORT. ------------------
else
    echo "ERROR: Untested/unsupported linux distro - Centos/Redhat/Ubuntu currently supported, feel free to amend for other distros and submit a PR."
fi

# --------------- IF PACKAGED WERE INSTALLED (THERES A TEMPORARY FILE WITH THEM LISTED IN IT) THEN SEND A MATTERMOST NOTIFICATION. -------------
if [ -f /tmp/package-updates-mattermost-announce.txt ]; then

    echo "$NOWTIME - notifying updates to mattermost..."
    INSTALLATIONS=$(cat /tmp/package-updates-mattermost-announce.txt)
    curl -X POST --data-urlencode 'payload={"channel": "'"$MM_CHANNEL_NAME"'", "username": "'"$MM_POST_USERNAME"'", "icon_url": "'"$MM_POST_USERNAME_ICON"'", "attachments": [ { "fallback": "'"$INSTALLATIONS"'", "color": "good", "title": "UPDATES APPLIED ON '"$SERVERNAME"'", "text": "Packages Updated:\n\n'"$INSTALLATIONS"'", "thumb_url": "'"$MM_POST_THUMBNAIL"'" } ] }' $MM_HOOK_URL
    rm -f /tmp/package-updates-mattermost-announce.txt
fi
