#!/bin/bash
# ==============================================================================
# GymGuide Production Web SPA Deployer Script
# ==============================================================================
set -e

echo "🚀 Starting Production VPS Deployment..."

# 1. Sync compiled files to VPS web root
echo "📦 Uploading assets to VPS via rsync..."
rsync -avz --delete build/web/ root@72.61.195.109:/var/www/gymguide/web/

# 2. Reload Nginx to apply all routing rules
echo "🔄 Reloading Nginx server..."
ssh root@72.61.195.109 "systemctl reload nginx"

echo "✅ Production Deployment successfully completed!"
