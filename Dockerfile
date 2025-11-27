FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install dependencies for isolated-vm (build tools)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create directory for logs
RUN mkdir -p /app/logs

# Expose ports
EXPOSE 5000 5001 5002

# Set Node.js memory limit and flags for isolated-vm
ENV NODE_OPTIONS="--max-old-space-size=8192 --no-node-snapshot"

# Start the application
CMD ["node", "app.js"]

