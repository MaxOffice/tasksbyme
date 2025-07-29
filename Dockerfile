FROM node:22.17-alpine3.22
LABEL maintainer="Raj Chaudhuri <rajch@hotmail.com>" \
      org.opencontainers.image.title="Tasks by Me" \
      org.opencontainers.image.description="Tasks by Me is a web application that allows a Microsoft 365 user to have a unified view of all tasks that they have created or own, and have possibly assigned to other people, in one place." \
      org.opencontainers.image.licenses=MIT \
      org.opencontainers.image.source=https://github.com/maxoffice/tasksbyme \
      org.opencontainers.image.url=https://github.com/maxoffice/tasksbyme

ENV PORT=8080 NODE_ENV=production

WORKDIR /app
ENTRYPOINT [ "node", "server.js" ]
EXPOSE 8080

COPY . .
RUN npm ci
