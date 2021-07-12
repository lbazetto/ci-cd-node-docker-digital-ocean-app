FROM node:14-alpine
ENV NODE_ENV=production

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --only=production

COPY . .
EXPOSE 80
CMD ["node", "index.js"]