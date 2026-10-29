
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

## Part 6: Deploying ShopHub from GitHub
- The site lives in `site/` in this repo. The server pulls it from GitHub and Nginx serves it from `/var/www/shophub`.
- `scripts/deploy.sh` runs the deployment in one command: `git pull`, a file-size check, copy, `nginx -t`, `reload`, and a final `curl`.
- The script stops with exit code 1 if `index.html` is too small, so a broken page can't be deployed.

## Troubleshooting story: the 19-byte page
**Symptom:** the site returned `200 OK` but showed almost nothing (`Content-Length: 19`).

**Method:** I checked each layer of the path in turn and compared the file size at each stage:

| Layer | Check | Result |
|---|---|---|
| VM | `gcloud compute instances list` | Running |
| Web server | `curl -I` | 200 OK, 19 bytes |
| Source file in repo | `wc -c site/index.html` | 19 bytes (root cause) |
| Deployed file | `wc -c /var/www/shophub/index.html` | 19 bytes (faithful copy) |

**Root cause:** the source file contained a placeholder (`...the web page...`) instead of HTML.

**Fix:** corrected the file in the repo, pushed to GitHub, pulled on the server, redeployed.

**Lessons:**
- `200 OK` means a file was sent, not that the content is right.
- Fix problems at the source (the repo), not on the server.
- Add an automated check (the size test in `deploy.sh`) so the same mistake cannot go live again.
- The backup script was still backing up the old folder, so I updated it to `/var/www/shophub` and checked the archive contents.
