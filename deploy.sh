#!/bin/bash
# ==============================================================================
# GymGuide Production Web SPA Deployer Script
# ==============================================================================
set -e

echo "🚀 Starting Production VPS Deployment..."

# 1. Generate Static SEO Shells
echo "🌐 Generating Static SEO Shells..."
python3 scripts/build_seo_shells.py

# 2. Sync compiled files to VPS web root
echo "📦 Uploading assets to VPS via rsync..."
rsync -avz --delete build/web/ root@72.61.195.109:/var/www/gymguide/web/

# 3. Reload Nginx to apply all routing rules
echo "🔄 Reloading Nginx server..."
scp gymguide_vps.conf root@72.61.195.109:/etc/nginx/conf.d/gymguide_vps.conf
ssh root@72.61.195.109 "systemctl reload nginx"

echo "✅ Production Deployment successfully completed!"
