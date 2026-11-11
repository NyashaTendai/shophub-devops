
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
contents.

## Part 7: Containerising ShopHub with Docker

### What I built
- `Dockerfile`: starts from the official `nginx:alpine` image and copies the `site/` folder into it.
- The container replaced the Nginx that was installed directly on the server. It runs on port 80 with `--restart unless-stopped`.
- `scripts/deploy.sh` now builds a new image, replaces the container, and checks that the site answers.

### Dockerfile
```dockerfile
FROM nginx:alpine
COPY site/ /usr/share/nginx/html/
```

### How the cutover was done
1. Built the image and ran it on port 8080 first, then tested it with `curl`.
2. Checked who was using port 80 with `sudo ss -tlnp | grep ':80 '`.
3. Stopped the old Nginx (`sudo systemctl stop nginx`) and recreated the container on port 80.
4. Disabled the old Nginx so it cannot take port 80 back after a reboot (`sudo systemctl disable nginx`).
5. Closed port 8080 in both the server firewall (`ufw`) and the Google Cloud firewall.

Rollback plan: `sudo systemctl start nginx`, or run the previous image tag.

### Deploying a new version
```bash
./scripts/deploy.sh
```
The script:
1. pulls the latest code,
2. refuses to continue if `site/index.html` is smaller than 200 bytes,
3. builds an image tagged with the Git commit ID (for example `shophub:8a7fb20`),
4. stops and removes the old container and starts the new one,
5. requests the page with `curl` and fails if it does not answer.

### Reliability test: reboot
I rebooted the VM on purpose. Afterwards the container came back by itself (`Up 2 minutes` on a server that had been up for 3), the old Nginx stayed off, and `docker`, `cron` and `fail2ban` were running. Port 8080 stayed closed.

### Lessons learned
- A container is disposable. The image holds everything, so I delete and recreate it and never edit inside it.
- Tagging images with the commit ID shows exactly what is running and allows a rollback.
- `Deploy OK` means the steps ran, not that the content changed. Docker's `Using cache` and an unchanged image ID showed that one deploy changed nothing.
- Only one program can listen on a port. Check with `ss` before changing anything.
- Docker publishes ports by its own firewall rules, so `ufw` alone does not control what a container exposes. Check from outside, and keep the cloud firewall tight.
- Run server commands on the server. Several mistakes came from running `deploy.sh`, `git commit` and `git push` in the wrong terminal.
cat >> README.md <<'EOF'

## Part 8: CI/CD with GitHub Actions

Every push to `main` now tests and deploys ShopHub automatically.

**Pipeline** (`.github/workflows/deploy.yml`)
1. `check` job: fails if `site/index.html` is under 200 bytes (stops an empty or broken page).
2. `deploy` job (runs only if `check` passes): connects to the VM over SSH and runs `scripts/deploy.sh`, which rebuilds and restarts the Docker container.

**Security: least privilege**
- A dedicated ed25519 deploy key, separate from my personal key.
- On the VM the key is locked with a forced command in `authorized_keys`, so it can only run `deploy.sh` (no shell, no port forwarding, no PTY).
- The private key, VM address and username are stored as GitHub Actions secrets, not in the repo.

**Negative test**
I pushed a deliberately broken 5-byte page. The `check` job failed (`index.html is 5 bytes`), the deploy was skipped, and the live site kept serving the good page. I then ran `git revert` and the pipeline deployed the restored page.

**What I learned**
- CI (automatic testing) and CD (automatic deployment) are separate steps, and CD should depend on CI.
- A green tick is not proof. I verified the live site with `curl` after each deploy.
- Test your safety nets by breaking things on purpose.
EOF
