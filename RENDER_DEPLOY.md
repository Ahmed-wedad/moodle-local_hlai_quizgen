# Render Deployment (Moodle + local_hlai_quizgen)

This repo now contains a Docker image definition that extends the same Moodle image you use locally and copies this plugin into:

`/bitnami/moodle/local/hlai_quizgen`

## 1) Push to GitHub

Push this repository (with `Dockerfile`, `.dockerignore`, `render.yaml`) to GitHub.

## 2) Create the Moodle web service on Render

1. In Render: New + -> Blueprint
2. Select this GitHub repo
3. Render reads `render.yaml` and creates `moodle-hlai-quizgen`
4. In service settings, add **Persistent Disk**:
   - Mount path: `/bitnami/moodledata`
   - Size: 5GB+ (choose based on expected usage)

## 3) Create MariaDB on Render (private service)

Render does not provide managed MariaDB by default in all plans/regions, so run MariaDB as a private service:

1. New + -> Private Service
2. Environment: Docker image
3. Image: `mariadb:10.11`
4. Add env vars:
   - `MARIADB_DATABASE=moodle`
   - `MARIADB_USER=moodle`
   - `MARIADB_PASSWORD=<strong-password>`
   - `MARIADB_ROOT_PASSWORD=<strong-root-password>`
5. Add persistent disk:
   - Mount path: `/var/lib/mysql`

## 4) Wire Moodle to DB

Set these env vars on `moodle-hlai-quizgen` service:

- `MOODLE_URL=https://<your-render-domain>`
- `MOODLE_DB_HOST=<mariadb-private-host>`
- `MOODLE_DB_PORT=3306`
- `MOODLE_DB_NAME=moodle`
- `MOODLE_DB_USER=moodle`
- `MOODLE_DB_PASSWORD=<same-as-mariadb-user-password>`

Then redeploy the Moodle web service.

## 5) First-time install/upgrade

1. Open your Render Moodle URL
2. Complete Moodle installation if prompted
3. Login as admin
4. Go to notifications/upgrade page to install plugin DB schema:
   - Site administration -> Notifications

## 6) Cron on Render

Create a Render Cron Job pointing to the same repo/image and run:

`/opt/bitnami/php/bin/php /bitnami/moodle/admin/cli/cron.php`

Recommended schedule: every 1-5 minutes.

## 7) Verify plugin

1. Check plugin appears in Site administration -> Plugins -> Local plugins
2. Open plugin pages and run a small generation/test flow
3. Confirm scheduled tasks are running in Site administration -> Server -> Scheduled tasks

## Troubleshooting

- Blank page/500: verify `MOODLE_URL` exactly matches Render URL.
- DB connect error: verify private host, credentials, and MariaDB service health.
- Data lost after redeploy: confirm persistent disks are attached at correct paths.
