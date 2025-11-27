# Hive Smart Contracts [![Build Status](https://app.travis-ci.com/hive-engine/hivesmartcontracts.svg?branch=main)](https://app.travis-ci.com/github/hive-engine/hivesmartcontracts)

 ## 1.  What is it?

Hive Smart Contracts is a sidechain powered by Hive, it allows you to perform actions on a decentralized database via the power of Smart Contracts.

 ## 2.  How does it work?

This is actually pretty easy, you basically need a Hive account and that's it. To interact with the Smart Contracts you simply post a message on the Hive blockchain (formatted in a specific way), the message will then be catched by the sidechain and processed.

 ## 3.  Sidechain specifications
- run on [node.js](https://nodejs.org)
- database layer powered by [MongoDB](https://www.mongodb.com/)
- Smart Contracts developed in Javascript
- Smart Contracts run in a sandboxed Javascript Virtual Machine called [VM2](https://github.com/patriksimek/vm2)
- a block on the sidechain is produced only if transactions are being parsed in a Hive block

## 4. Setup a Hive Smart Contracts node

### Docker Setup (Recommended)

The easiest way to run Hive Smart Contracts is using Docker and Docker Compose. This setup includes:
- MongoDB 4.4 with replica set configuration (required for transactions)
- Node.js application with all dependencies
- Automatic initialization of MongoDB replica set

#### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) installed
- [Docker Compose](https://docs.docker.com/compose/install/) installed

#### Quick Start

1. **Clone the repository** (if you haven't already):
   ```bash
   git clone <repository-url>
   cd hivesmartcontracts
   ```

2. **Create configuration file**:
   ```bash
   cp config.example.json config.json
   ```

3. **Update `config.json`**:
   - Set `databaseURL` to `"mongodb://he-mongo:27017"` (Docker service name)
   - Configure other settings as needed (startHiveBlock, streamNodes, etc.)

4. **Create `.env` file** (if needed for P2P/witness features):
   ```bash
   # Optional: Only needed if witnessEnabled is true in config.json
   ACCOUNT=your_account_name
   ACTIVE_SIGNING_KEY=your_private_key
   ```

5. **Start the services**:
   ```bash
   docker-compose up -d
   ```

6. **View logs**:
   ```bash
   # All services
   docker-compose logs -f
   
   # Just the app
   docker-compose logs -f he-app
   
   # Just MongoDB
   docker-compose logs -f he-mongo
   ```

7. **Stop the services**:
   ```bash
   docker-compose down
   ```

#### Docker Commands

- **Start services**: `docker-compose up -d`
- **Stop services**: `docker-compose down`
- **Restart services**: `docker-compose restart`
- **View logs**: `docker-compose logs -f [service-name]`
- **Rebuild after code changes**: `docker-compose up -d --build`
- **Access MongoDB shell**: `docker-compose exec he-mongo mongo`
- **Access app container**: `docker-compose exec he-app sh`

#### Important Notes

- MongoDB replica set is automatically initialized by the `he-mongo-init` service
- Data persistence: MongoDB data is stored in Docker volumes (`mongodb_data` and `mongodb_config`)
- Ports exposed:
  - `5000`: RPC server
  - `5001`: P2P server
  - `5002`: WebSocket server
- MongoDB is only accessible within the Docker network (not exposed to host) to avoid port conflicts
- The application automatically uses `--no-node-snapshot` flag for Node.js (required for isolated-vm on Node 20+)
- Configuration file (`config.json`) is mounted as read-only volume
- Log files are persisted in `./logs` directory and `./node_app.log`

### DB Backup and Restore (Docker)

**Backup current state** (track current hive block in config):
```bash
docker-compose exec he-mongo mongodump -d=hsc --gzip --archive=/tmp/hsc_backup.archive
docker-compose cp he-mongo:/tmp/hsc_backup.archive ./hsc_backup.archive
```

**Restore state** (when you have a backup archive file):

Backup files follow this pattern: `hsc_DATE_HASH_bBLOCKNUMBER.archive`
- Example: `hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive`
- The block number is extracted from the filename (e.g., `101546800` from `_b101546800.archive`)

**Recommended: Use the restore script** (handles all steps automatically):
```bash
./restore_backup.sh hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive
```

The script will:
1. Stop the application
2. Drop the existing database
3. Copy the backup file into the container
4. Restore the database from backup
5. Restart MongoDB container
6. **Automatically update `config.json`** with the extracted block number (`startHiveBlock`)
7. Start the application

The script automatically extracts the block number from the filename and updates `config.json`, so no manual configuration is needed.

**Manual restore method** (if you prefer to do it step by step):

1. **Stop the application**:
   ```bash
   docker-compose stop he-app
   ```

2. **Drop the existing database**:
   ```bash
   docker-compose exec he-mongo mongo hsc --eval "db.dropDatabase()"
   ```

3. **Copy the backup archive into the MongoDB container**:
   ```bash
   docker-compose cp ./hsc_11-27-2025_6e2ff48438807790f8051efb4f67c7c8_b101546800.archive he-mongo:/tmp/hsc_backup.archive
   ```

4. **Restore the database**:
   ```bash
   docker-compose exec he-mongo mongorestore --gzip --archive=/tmp/hsc_backup.archive
   ```

5. **Restart MongoDB container**:
   ```bash
   docker-compose restart he-mongo
   ```

6. **Extract block number from filename** and **update `config.json`**:
   - Extract the number after `_b` in the filename (e.g., `101546800` from `_b101546800.archive`)
   - Update `startHiveBlock` in `config.json` to this number

7. **Start the application again**:
   ```bash
   docker-compose start he-app
   ```

### Manual Setup (Alternative)

For manual setup without Docker, see wiki: https://github.com/hive-engine/hivesmartcontracts-wiki

**Requirements for manual setup:**
- MongoDB 4.4+ running in replica set mode (replSetName: "rs0")
- Node.js >= v18.17.0
- MongoDB replica set must be initialized: `rs.initiate()`
- See MongoDB documentation for replica set setup: https://docs.mongodb.com/manual/tutorial/convert-standalone-to-replica-set/
## 5. Tests
* npm run test

## 6. Usage/docs

* see wiki: https://github.com/hive-engine/hivesmartcontracts-wiki
