FROM node

ENV NPM_SCRIPT start

WORKDIR /geolookup

COPY ./targets/microservices/geolookup/package*.json ./
RUN npm install

COPY ./targets/microservices/geolookup/. .

EXPOSE 3000

RUN echo $NPM_SCRIPT

ENTRYPOINT npm run-script $NPM_SCRIPT
