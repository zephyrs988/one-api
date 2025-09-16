FROM --platform=$BUILDPLATFORM node:16 AS builder

WORKDIR /web
COPY ./VERSION .
COPY ./web .

# 设置 Node.js 内存限制
ENV NODE_OPTIONS="--max-old-space-size=1536"

# 分别安装和构建每个目录，使用更激进的内存管理
RUN cd /web/default && \
    npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && \
    npm cache clean --force && \
    DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat /web/VERSION) npm run build && \
    rm -rf node_modules && \
    npm cache clean --force

RUN cd /web/berry && \
    npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && \
    npm cache clean --force && \
    DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat /web/VERSION) npm run build && \
    rm -rf node_modules && \
    npm cache clean --force

RUN cd /web/air && \
    npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && \
    npm cache clean --force && \
    DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat /web/VERSION) npm run build && \
    rm -rf node_modules && \
    npm cache clean --force


FROM golang:alpine AS builder2

RUN apk add --no-cache \
    gcc \
    musl-dev \
    sqlite-dev \
    build-base

ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux

WORKDIR /build

ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=builder /web/build ./web/build

RUN go build -trimpath -ldflags "-s -w -X 'github.com/songquanpeng/one-api/common.Version=$(cat VERSION)' -linkmode external -extldflags '-static'" -o one-api

FROM alpine:latest

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder2 /build/one-api /

EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]