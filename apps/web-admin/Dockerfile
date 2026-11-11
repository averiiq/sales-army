FROM node:20-alpine
WORKDIR /app

# Copy package definitions and install dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source files
COPY . .

# Default web port
ENV PORT=3000
EXPOSE 3000

# Start SalesArmy Super Admin Server
CMD ["node", "server.js"]

