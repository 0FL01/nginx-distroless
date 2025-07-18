FROM debian:12 AS builder

# Устанавливаем переменную окружения для неинтерактивной установки
ARG DEBIAN_FRONTEND=noninteractive
ARG NGINX_VERSION=1.29.0
ARG NGINX_USER_UID=65532
ARG NGINX_USER_GID=65532

# Установка зависимостей для сборки
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя и группу, чтобы потом скопировать их в финальный образ
RUN groupadd --system --gid ${NGINX_USER_GID} nonroot && \
    useradd --system --no-create-home --gid nonroot --uid ${NGINX_USER_UID} nonroot

# Загрузка и распаковка исходников nginx
WORKDIR /tmp
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz

# Конфигурация и компиляция nginx
WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN ./configure \
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
    --with-stream_ssl_preread_module

RUN make -j$(nproc) && make install

# Создаем директории и выставляем права для пользователя nonroot
RUN mkdir -p /var/cache/nginx && \
    chown -R nonroot:nonroot /var/cache/nginx

# Перенаправляем логи в stdout/stderr для удобства в контейнерах
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# ---
# Этап 2: Финальный образ на базе distroless
FROM gcr.io/distroless/base-debian12

# Копируем созданных пользователя и группу
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Копируем бинарник и конфигурацию
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx

# Копируем директории, которыми будет владеть nonroot
COPY --from=builder --chown=nonroot:nonroot /var/cache/nginx /var/cache/nginx

# Копируем директорию с логами (и симлинками внутри)
COPY --from=builder /var/log/nginx /var/log/nginx

# Копируем необходимые системные библиотеки
COPY --from=builder /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]