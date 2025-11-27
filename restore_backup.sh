#!/bin/bash

# Script to restore MongoDB backup for Hive Smart Contracts
# Usage: ./restore_backup.sh <backup_archive_file>
# Example: ./restore_backup.sh hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive

set -e  # Exit on error

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Error: Backup archive file not provided"
    echo "Usage: $0 <backup_archive_file>"
    echo "Example: $0 hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found"
    exit 1
fi

# Extract block number from filename
# Pattern: hsc_DATE_HASH_bBLOCKNUMBER.archive
# Extract the number after _b and before .archive
BLOCK_NUMBER=$(echo "$BACKUP_FILE" | sed -n 's/.*_b\([0-9]*\)\.archive$/\1/p')

if [ -z "$BLOCK_NUMBER" ]; then
    echo "Error: Could not extract block number from filename '$BACKUP_FILE'"
    echo "Expected pattern: hsc_DATE_HASH_bBLOCKNUMBER.archive"
    echo "Example: hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive"
    exit 1
fi

echo "Extracted block number: $BLOCK_NUMBER"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose not found. Please install Docker Compose."
    exit 1
fi

echo "=========================================="
echo "Hive Smart Contracts - Database Restore"
echo "=========================================="
echo "Backup file: $BACKUP_FILE"
echo ""

# Pre-flight checks: Ensure MongoDB is running and replica set is initialized
echo "Checking MongoDB service status..."
if ! docker-compose ps he-mongo | grep -q "Up"; then
    echo "MongoDB service is not running. Starting MongoDB..."
    docker-compose up -d he-mongo
    echo "Waiting for MongoDB to start..."
    sleep 5
    # Wait for MongoDB to be ready
    until docker-compose exec -T he-mongo mongo --eval 'db.runCommand("ping").ok' --quiet > /dev/null 2>&1; do
        echo "  Waiting for MongoDB..."
        sleep 2
    done
    echo "✓ MongoDB is running"
else
    echo "✓ MongoDB service is running"
fi
echo ""

# Check if replica set is initialized
echo "Checking replica set status..."
RS_STATUS=$(docker-compose exec -T he-mongo mongo --quiet --eval 'rs.status().ok' 2>/dev/null || echo "0")

if [ "$RS_STATUS" != "1" ]; then
    echo "Replica set rs0 is not initialized. Initializing..."
    docker-compose exec -T he-mongo mongo --quiet <<EOF
rs.initiate({
  _id: "rs0",
  members: [{ _id: 0, host: "he-mongo:27017" }]
})
EOF
    echo "Waiting for replica set to initialize..."
    sleep 5
    # Wait for replica set to be ready
    until docker-compose exec -T he-mongo mongo --quiet --eval 'rs.status().ok' 2>/dev/null | grep -q "1"; do
        echo "  Waiting for replica set..."
        sleep 2
    done
    echo "✓ Replica set rs0 initialized"
else
    echo "✓ Replica set rs0 is already initialized"
fi
echo ""

# Step 1: Stop the app
echo "[1/7] Stopping application..."
docker-compose stop he-app
echo "✓ Application stopped"
echo ""

# Step 2: Drop the database
echo "[2/7] Dropping existing database..."
docker-compose exec -T he-mongo mongo hsc --quiet <<EOF
db.dropDatabase()
quit()
EOF
echo "✓ Database dropped"
echo ""

# Step 3: Copy backup file into container
echo "[3/7] Copying backup file into container..."
docker-compose cp "$BACKUP_FILE" he-mongo:/tmp/hsc_restore.archive
echo "✓ Backup file copied"
echo ""

# Step 4: Restore the database
echo "[4/7] Restoring database from backup..."
docker-compose exec he-mongo mongorestore --gzip --archive=/tmp/hsc_restore.archive
echo "✓ Database restored"
echo ""

# Step 5: Restart MongoDB container (to ensure clean state)
echo "[5/7] Restarting MongoDB container..."
docker-compose restart he-mongo
echo "✓ MongoDB restarted"
echo ""

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
sleep 5
until docker-compose exec -T he-mongo mongo --eval 'db.runCommand("ping").ok' --quiet > /dev/null 2>&1; do
    echo "  Waiting for MongoDB..."
    sleep 2
done
echo "✓ MongoDB is ready"

# Verify replica set is still initialized after restart
echo "Verifying replica set status..."
RS_STATUS=$(docker-compose exec -T he-mongo mongo --quiet --eval 'try { rs.status().ok } catch(e) { 0 }' 2>/dev/null || echo "0")
if [ "$RS_STATUS" != "1" ]; then
    echo "Replica set lost after restart. Re-initializing..."
    docker-compose exec -T he-mongo mongo --quiet <<EOF
rs.initiate({
  _id: "rs0",
  members: [{ _id: 0, host: "he-mongo:27017" }]
})
EOF
    sleep 5
    until docker-compose exec -T he-mongo mongo --quiet --eval 'rs.status().ok' 2>/dev/null | grep -q "1"; do
        echo "  Waiting for replica set..."
        sleep 2
    done
    echo "✓ Replica set rs0 re-initialized"
else
    echo "✓ Replica set rs0 is active"
fi
echo ""

# Step 6: Update config.json with block number
echo "[6/7] Updating config.json with block number $BLOCK_NUMBER..."
if [ ! -f "config.json" ]; then
    echo "Error: config.json not found"
    exit 1
fi

# Check if jq is available for JSON manipulation
if command -v jq &> /dev/null; then
    # Use jq to update the JSON file
    jq ".startHiveBlock = $BLOCK_NUMBER" config.json > config.json.tmp && mv config.json.tmp config.json
    echo "✓ config.json updated using jq"
else
    # Fallback to sed for JSON manipulation (less reliable but works)
    # This assumes the JSON format is consistent
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed
        sed -i '' "s/\"startHiveBlock\": [0-9]*/\"startHiveBlock\": $BLOCK_NUMBER/" config.json
    else
        # Linux sed
        sed -i "s/\"startHiveBlock\": [0-9]*/\"startHiveBlock\": $BLOCK_NUMBER/" config.json
    fi
    echo "✓ config.json updated using sed"
    echo "  Note: Install 'jq' for more reliable JSON updates"
fi
echo ""

# Step 7: Restart the app
echo "[7/7] Starting application..."
docker-compose start he-app
echo "✓ Application started"
echo ""

echo "=========================================="
echo "Restore completed successfully!"
echo "=========================================="
echo ""
echo "✓ Database restored from: $BACKUP_FILE"
echo "✓ Block number set to: $BLOCK_NUMBER"
echo "✓ Application restarted"
echo ""
echo "View logs with: docker-compose logs -f he-app"

