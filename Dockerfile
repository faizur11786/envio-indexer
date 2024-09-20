ARG ARCH=
FROM ${ARCH}mcr.microsoft.com/devcontainers/javascript-node:20-bookworm
WORKDIR /app/base

RUN npm install -g npm@latest
COPY . .

ENV PNPM_HOME /usr/local/binp
RUN npm install --global pnpm

RUN rm -rf generated

RUN pnpm install

RUN pnpm envio codegen


RUN chmod +x ./envio-entrypoint.sh
ENTRYPOINT ["/bin/sh", "./envio-entrypoint.sh"]
