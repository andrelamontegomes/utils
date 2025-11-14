#!/bin/bash
# Local database refresh script - downloads and imports latest dev backup
# This file is gitignored and for local use only
# Usage: ./refresh-db.sh [--most-recent] [--app-name=NAME]

set -e  # Exit on error

# Parse command line arguments
SKIP_DOWNLOAD=false
APP_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --most-recent)
            SKIP_DOWNLOAD=true
            shift
            ;;
        --app-name=*)
            APP_NAME="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./refresh-db.sh [--most-recent] [--app-name=NAME]"
            exit 1
            ;;
    esac
done

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "Error: gum is not installed. Install it with: brew install gum"
    exit 1
fi

gum style --foreground 212 --border-foreground 212 --border double --padding "1 2" --margin "1" "Database Refresh" "Downloads and imports latest dev backup"

# Load APP_NAME from .env if not provided as flag
if [ -z "$APP_NAME" ]; then
    if [ -f .env ]; then
        export $(grep -v '^#' .env | grep APP_NAME | xargs)
    fi

    # APP_NAME is required if not set
    if [ -z "$APP_NAME" ]; then
        gum style --foreground 196 "✗ APP_NAME not found in .env"
        echo "Please add APP_NAME to your .env file or use --app-name flag"
        exit 1
    else
        gum style --foreground 212 "✓ Using APP_NAME from .env: $APP_NAME"
    fi
else
    gum style --foreground 212 "✓ Using APP_NAME from flag: $APP_NAME"
fi

# Check if MySQL container is running
if ! docker ps --format '{{.Names}}' | grep -q 'mysql'; then
    gum style --foreground 214 "⚠ MySQL container is not running"
    if gum confirm "Would you like to start the containers now?"; then
        gum spin --spinner dot --title "Starting containers..." -- ./vendor/bin/sail up -d
        gum style --foreground 212 "✓ Containers started"
    else
        gum style --foreground 196 "✗ Cannot proceed without MySQL container"
        exit 1
    fi
fi

# Download database backup unless --most-recent flag is used
if [ "$SKIP_DOWNLOAD" = false ]; then
    # Load environment variables to get DEV_DB_PASSWORD if set
    if [ -f .env ]; then
        export $(grep -v '^#' .env | grep DEV_DB_PASSWORD | xargs)
    fi

    # Check if password is set in environment
    if [ -z "$DEV_DB_PASSWORD" ]; then
        gum style --foreground 214 "⚠ DEV_DB_PASSWORD not set in .env"
        echo "To automate fully, add this to your .env file:"
        echo "DEV_DB_PASSWORD=your_password_here"
        echo ""

        gum spin --spinner dot --title "Downloading database backup..." -- vendor/bin/dep database:download dev-job
    else
        gum style --foreground 212 "✓ Using DEV_DB_PASSWORD from .env"

        # Run deployer with password from environment
        echo "$DEV_DB_PASSWORD" | gum spin --spinner dot --title "Downloading database backup..." -- vendor/bin/dep database:download dev-job
    fi
else
    gum style --foreground 212 "» Skipping download, using most recent local backup"
fi

# Find the most recent backup file
LATEST_BACKUP=$(ls -t database/backups/backup_*.sql 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    gum style --foreground 196 "✗ Error: No backup file found in database/backups/"
    exit 1
fi

gum style --foreground 212 "✓ Found backup: $LATEST_BACKUP"

# Import the database
gum spin --spinner dot --title "Importing database..." -- bash -c "./vendor/bin/sail mysql -u root $APP_NAME < \"$LATEST_BACKUP\""

gum style --foreground 212 --bold "✓ Database refresh complete!"
echo "Imported: $LATEST_BACKUP"

# Optional: Clean up old backups (keep last 5)
BACKUP_COUNT=$(ls -1 database/backups/backup_*.sql 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 5 ]; then
    gum style --foreground 214 "» Cleaning up old backups (keeping last 5)..."
    ls -t database/backups/backup_*.sql | tail -n +6 | xargs rm -f
    gum style --foreground 212 "✓ Cleanup complete"
fi
