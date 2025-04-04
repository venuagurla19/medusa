FROM node:18-alpine

WORKDIR /app

COPY . .

RUN npm install

RUN npm build

EXPOSE 9000

CMD ["npm", "run", "start"]