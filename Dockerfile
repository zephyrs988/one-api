FROM --platform=$BUILDPLATFORM node:16 AS builder

WORKDIR /web
COPY ./VERSION .
COPY ./web .

# 设置 Node.js 内存限制
ENV NODE_OPTIONS="--max-old-space-size=2048"

# 分别安装每个目录的依赖，并在安装后清理缓存以节省内存
RUN cd /web/default && npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && npm cache clean --force
RUN cd /web/berry && npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && npm cache clean --force  
RUN cd /web/air && npm install --legacy-peer-deps --no-audit --no-fund --prefer-offline && npm cache clean --force

# 分别构建每个项目，构建后立即清理 node_modules 以节省空间
RUN cd /web/default && DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat ./VERSION) npm run build && rm -rf node_modules
RUN cd /web/berry && DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat ./VERSION) npm run build && rm -rf node_modules
RUN cd /web/air && DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat ./VERSION) npm run build && rm -rf node_modules


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