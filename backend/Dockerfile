FROM node:18-alpine

WORKDIR /usr/src/app

# Install dependencies
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY backend ./

EXPOSE 3000

CMD ["node", "server.js"] 