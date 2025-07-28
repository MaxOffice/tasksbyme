FROM node:22.17-alpine3.22
LABEL maintainer="Raj Chaudhuri <rajch@hotmail.com>"

ENV TENANT_ID= \
    CLIENT_ID= \
    CLIENT_SECRET= \
    SESSION_SECRET= \
    PORT=8080
ENV NODE_ENV=production \
    REDIRECT_URI=http://localhost:${PORT}/auth/callback

WORKDIR /app
ENTRYPOINT [ "node", "server.js" ]
EXPOSE 8080

COPY . .
RUN npm ci

