# ShopHub DevOps Project

A hands-on DevOps portfolio. I deploy and secure the ShopHub web app on a Linux server in Google Cloud.

## What I build
- Linux VM on Google Cloud (Debian 12, e2-micro)
- Nginx web server
- SSH key login, firewall and fail2ban
- Automated backups with Bash and cron

## Status
In progress. I update this as I go.

## Part 5: Automated backups
- `scripts/backup.sh` compresses `/var/www/html` into a dated `.tar.gz` file, logs it, and keeps the newest 7.
- Scheduled with cron: `0 2 * * *` (02:00 UTC every night).
- Lessons learned:
  - A script that runs without errors can still back up the wrong thing, so I list the archive contents.
  - A wildcard matching two files breaks `tar -t`, so I select the newest file first.
  - A command glued to a comment in `crontab -e` fails silently. Use `printf '...\n' | crontab -` instead.
  - I tested a full restore into a scratch folder.
