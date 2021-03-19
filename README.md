# Server package updates/installs sent as Mattermost or Google Chat Notifications

Cron-able Bash Scripts to identify new [ yum | apt-get ] updates and installations on a server and send them as a notification to Mattermost or Google Chat.

These scripts help track when package updates are automatically installed on a server, with a view to spotting when a service or server needs restarting to make use of security updates etc.

Note that the scripts idenfity packages that HAVE been installed/updated, not ones that could be - it assumes you have automatic updating set up on your server.

## Pre-requistes

These scripts will run under RHEL/Centos and Ubuntu (they will detect which and use either rpm (Yum on Redhat/Centos) or /var/log/dpkg.log (apt-get on Ubuntu). Other Distros are not supported, although feel free to send a Pull request on Rick Harrison's source code if you'd like.

You need to have your server configured to automatically download and apply updates already (eg yum-cron). This script will not restart services/servers itself - its just notifying you that you may need to restart things yourself.

Additionally, you will need to have cron & curl on your system.

## Installation

Place either script somewhere suitable - i.e. /usr/local/bin/notify_updates

Change the configuration settings in the script. If currently expects MM_HOOK_URL or GCHAT_HOOK_URL to be an environment variable on your server, but you can uncomment and define it in the script if you so wish. Make a note of the frequence (default is every 15 mins).

Set up the script as a cron job. Note that the cron frequency needs to match the frequency setting in the script config.

I use the following cron entry at /etc/cron.d/send_update_notifications:

```
*/15 * * * * root  /bin/bash /usr/local/bin/notify_updates > /dev/null 2>&1
```

## Credits

Written by Rick Harrison : https://www.fortybelowzero.com ( @sovietuk on twitter )

Modified by Unai Goikoetxeta
