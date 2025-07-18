# nginx-distroless

Минималистичный Docker-образ NGINX, собранный из исходников и основанный на [Distroless](https://github.com/GoogleContainerTools/distroless) для максимальной безопасности и компактности.

## Особенности
- Сборка NGINX 1.29.0 из исходников
- Базовый образ: `gcr.io/distroless/base-debian12`
- Только необходимые модули (HTTP/2, SSL, stream и др.)
- Запуск мастер-процесса от root, воркеры — от непривилегированного пользователя `nonroot`
- Логи проброшены в stdout/stderr (удобно для контейнеров)
- Размер итогового образа: ~35MB

## Сборка образа

```sh
git clone https://github.com/0FL01/nginx-distroless.git
cd nginx-distroless
docker build -t nginx-distroless:1.29.0 .
```

## Запуск контейнера

```sh
docker run -d -p 80:80 -p 443:443 --name nginx nginx-distroless:1.29.0
```

## Конфигурация
- Основной конфиг: `nginx.conf` (копируется в образ)
- Для расширения используйте директиву `include` внутри `nginx.conf`
- Все рабочие файлы и кэш: `/var/cache/nginx`
- Логи: `/var/log/nginx` (симлинки на stdout/stderr)

## Пользователь
- Воркеры NGINX работают от пользователя `nonroot` (uid/gid 65532)

## Пример вывода docker images

```
REPOSITORY         TAG     IMAGE ID       CREATED          SIZE
nginx-distroless   1.29.0  0dd96b4a4418   31 seconds ago   35MB
```