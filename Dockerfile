# Этап 1: Сборка
FROM debian:12-slim AS builder

ARG NGINX_VERSION=1.29.0
ARG NGINX_USER_UID=65532
ARG NGINX_USER_GID=65532
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpcre3-dev \
        zlib1g-dev \
        libssl-dev \
        wget \
        ca-certificates && \
    groupadd --system --gid ${NGINX_USER_GID} nonroot && \
    useradd --system --no-create-home --gid nonroot --uid ${NGINX_USER_UID} nonroot && \
    cd /tmp && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nonroot \
        --group=nonroot \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/nginx-${NGINX_VERSION}.tar.gz /tmp/nginx-${NGINX_VERSION} && \
    apt-get purge -y --auto-remove build-essential wget && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/cache/nginx && \
    chown -R nonroot:nonroot /var/cache/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Подготовка директории с зависимостями для копирования
RUN mkdir -p /dist && \
    ldd /usr/sbin/nginx | grep '=> /' | awk '{print $3}' | xargs -I '{}' cp -v --parents '{}' /dist && \
    cp -v --parents /lib/x86_64-linux-gnu/libnss_files.so.2 /dist

# Этап 2: Финальный образ
FROM gcr.io/distroless/base-debian12

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder --chown=nonroot:nonroot /var/cache/nginx /var/cache/nginx
COPY --from=builder /var/log/nginx /var/log/nginx

# Копирование всех зависимостей из подготовленной директории
COPY --from=builder /dist/ /

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]