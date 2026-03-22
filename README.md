# Trip Constructor Infra

## Что находится в репозитории

Этот репозиторий содержит инфраструктуру и orchestration для сервисов проекта:

* CI/CD через GitHub Actions
* Docker image build и push в Docker Hub
* деплой в Docker Swarm
* stack-файлы для `data`, `gate`, `apps`, `front`
* bootstrap PostgreSQL для сервисных баз
* подключение сервисов и frontend через git submodule

Основные каталоги:

* `services/` - backend-сервисы проекта
* `frontend/` - frontend-сабмодуль
* `infra/stacks/` - swarm stack-файлы
* `infra/configs/postgres/` - кастомный postgres image и init-скрипты
* `.github/workflows/` - CI/CD workflow для dev и prod

## Схема доставки

```text
developer
   |
   v
git push / git tag
   |
   v
GitHub Actions
   |
   +-- lint / tests
   +-- docker build
   +-- docker push
   |
   v
Docker Swarm
   |
   +-- deploy data
   +-- run migrations
   +-- deploy gate/apps/front
```

## Git и релизы

Текущая схема workflow:

* `pull_request -> main` - проверки backend-сервисов
* `push -> main` - dev build и deploy на стенд
* `push tag v*` - production release

Dev pipeline умеет собирать и деплоить `frontend` на стенд.

Релизный pipeline использует единую версию образов по тегу. Это значит, что при `push` тега собираются все релизные образы, участвующие в деплое.

## Клонирование

```bash
git clone git@github.com:RideTrip-tour/trip-constructor.git
cd trip-constructor
git submodule init
git submodule update --recursive
```

## Состав submodule

Подключены:

* `services/auth-service`
* `services/gateway-service`
* `frontend`

Если обновляется submodule, коммитить нужно в двух местах:

* внутри самого submodule
* в этом репозитории, чтобы обновить указатель на commit submodule

## Docker Swarm

### Инициализация кластера

```bash
docker swarm init
```

### Создание overlay-сетей

Workflow умеют создавать сети идемпотентно сами, но вручную это выглядит так:

```bash
docker network create --driver overlay --attachable data-network
docker network create --driver overlay --attachable internal-network
```

### Локальный пример deploy

```bash
export DOCKERHUB_NAMESPACE=ride2trip
export POSTGRES_IMAGE_VERSION=dev
export AUTH_SERVICE_VERSION=dev
export GATEWAY_SERVICE_VERSION=dev
export FRONTEND_VERSION=dev
export GATEWAY_PORT=8081
export ORIGIN=https://dev.trip.elmobil.ru
export LK_PATH=/users/me/
export REFRESH_TOKEN_PATH=/api/auth/refresh

envsubst < infra/stacks/data-stack.yml | docker stack deploy -c - data
envsubst < infra/stacks/gateway-stack.yml | docker stack deploy -c - gate
envsubst < infra/stacks/app-stack.yml | docker stack deploy -c - apps
envsubst < infra/stacks/frontend-stack.yml | docker stack deploy -c - front
```

### Ручной deploy скриптом

Файл:

* [deploy.sh](/home/viktor/PycharmProjects/trip-constructor/infra/deploy.sh)

Он последовательно деплоит:

* `data`
* `gate`
* `apps`
* `front`

## Frontend и внешний nginx

Frontend деплоится отдельным stack `front` и публикует порт `3000` через:

* [frontend-stack.yml](/home/viktor/PycharmProjects/trip-constructor/infra/stacks/frontend-stack.yml)

Frontend container не имеет доступа к внутренним сервисам по overlay-сетям. Маршрутизация делается внешним nginx:

* `/` -> frontend (`127.0.0.1:3000`)
* `/api/` -> gateway (`127.0.0.1:8081`)
* `/docs/` -> gateway (`127.0.0.1:8081`)

Это позволяет:

* оставить один публичный origin для браузера
* избежать CORS между UI и API
* не давать frontend прямой доступ к внутренним сервисам

Во frontend для production используется относительный API path:

* `VITE_API_URL=`
* `VITE_API_PREFIX=/api`

Файлы:

* [frontend/nginx.conf](/home/viktor/PycharmProjects/trip-constructor/frontend/nginx.conf)
* [frontend/src/api/baseUrl.ts](/home/viktor/PycharmProjects/trip-constructor/frontend/src/api/baseUrl.ts)
* [frontend/src/vite-env.d.ts](/home/viktor/PycharmProjects/trip-constructor/frontend/src/vite-env.d.ts)

## Docker Swarm secrets

Проверка:

```bash
docker secret ls
```

Создание одного секрета:

```bash
printf '%s' 'value' | docker secret create SECRET_NAME -
```

Массовое создание из `.env`:

* [create-secrets.sh](/home/viktor/PycharmProjects/trip-constructor/create-secrets.sh)

Важно:

* GitHub `secrets` и Docker Swarm `secrets` это разные сущности
* stack-файлы используют именно Docker Swarm `secrets`
* `GATEWAY_PORT` в CI/CD берется из GitHub Actions secrets

## PostgreSQL

Для Postgres используется отдельный образ:

* [infra/configs/postgres/Dockerfile](/home/viktor/PycharmProjects/trip-constructor/infra/configs/postgres/Dockerfile)

В него встроены:

* [init-multi-db.sh](/home/viktor/PycharmProjects/trip-constructor/infra/configs/postgres/init-multi-db.sh)
* [create-service-db.sh](/home/viktor/PycharmProjects/trip-constructor/infra/configs/postgres/create-service-db.sh)

### Что делает init-multi-db.sh

Скрипт выполняется только при первом старте Postgres на пустом volume и создает сервисные базы из списка `POSTGRES_MULTIPLE_DATABASES`.

Это bootstrap-механизм, а не способ дальнейшей эволюции схемы.

### Что делает create-service-db.sh

Это идемпотентный скрипт создания роли и базы для одного сервиса.

Пример:

```bash
docker exec -it <postgres-container> /usr/local/bin/create-service-db.sh orders
```

Для `orders` внутри swarm должны существовать secrets:

```text
DB_ORDERS_SERVICE_NAME
DB_ORDERS_SERVICE_USER
DB_ORDERS_SERVICE_PASS
```

Если Postgres уже инициализирован и volume существует, новый сервис нужно добавлять именно через `create-service-db.sh`, а не ждать повторного выполнения `init-multi-db.sh`.

## CI/CD workflow

### CI Dev

Файл:

* [ci-dev.yml](/home/viktor/PycharmProjects/trip-constructor/.github/workflows/ci-dev.yml)

Что делает:

* определяет измененные части репозитория, включая `frontend`
* на PR в `main` запускает `ruff` и `pytest` для backend-сервисов
* на push в `main` собирает нужные dev-образы
* публикует `frontend:dev` при изменениях во `frontend`
* создает swarm-сети при необходимости
* деплоит `data`
* ждет готовности Postgres
* запускает миграции
* деплоит `gate`, `apps`, `front`

### Release Prod

Файл:

* [release-prod.yml](/home/viktor/PycharmProjects/trip-constructor/.github/workflows/release-prod.yml)

Что делает сейчас:

* запускается по тегу `v*`
* собирает и деплоит backend-часть релиза
* деплоит `data`
* ждет готовности Postgres
* запускает миграции
* деплоит `gate` и `apps`

Если нужно, frontend можно добавить в production pipeline отдельно.

## Ручная проверка deploy

Перед CI/CD полезно уметь проверить deploy вручную.

Порядок:

```bash
envsubst < infra/stacks/data-stack.yml | docker stack deploy -c - data
docker service ls
docker service logs data_postgres

envsubst < infra/stacks/gateway-stack.yml | docker stack deploy -c - gate
envsubst < infra/stacks/app-stack.yml | docker stack deploy -c - apps
envsubst < infra/stacks/frontend-stack.yml | docker stack deploy -c - front
docker service ls
```

Если ручной deploy не работает, CI/CD тоже не будет работать.

## Добавление нового backend-сервиса

При добавлении нового сервиса недостаточно только положить код в `services/`. Нужно обновить deploy-конфигурацию, secrets и при необходимости схему миграций.

### 1. Добавить код сервиса

Минимум:

* `Dockerfile`
* `requirements.txt`
* `main.py`
* `health` endpoint

### 2. Добавить сервис в stack

Обычно сервис описывается в:

* [app-stack.yml](/home/viktor/PycharmProjects/trip-constructor/infra/stacks/app-stack.yml)

Нужно задать:

* `image`
* `secrets`
* `environment`
* `networks`
* `deploy.restart_policy`

### 3. Добавить swarm secrets

Если сервис использует runtime secrets, их нужно создать в Swarm заранее.

Пример:

```bash
printf '%s' 'value' | docker secret create SECRET_NAME -
```

### 4. Если сервису нужна своя PostgreSQL база

Нужно создать secrets:

```text
DB_<SERVICE>_SERVICE_NAME
DB_<SERVICE>_SERVICE_USER
DB_<SERVICE>_SERVICE_PASS
```

При необходимости также:

```text
DB_<SERVICE>_SERVICE_HOST
DB_<SERVICE>_SERVICE_PORT
```

Пример для `orders`:

```bash
printf '%s' 'postgres' | docker secret create DB_ORDERS_SERVICE_HOST -
printf '%s' '5432' | docker secret create DB_ORDERS_SERVICE_PORT -
printf '%s' 'orders_db' | docker secret create DB_ORDERS_SERVICE_NAME -
printf '%s' 'orders_user' | docker secret create DB_ORDERS_SERVICE_USER -
printf '%s' 'strong-password' | docker secret create DB_ORDERS_SERVICE_PASS -
```

Если это новый пустой environment и база создается при первом старте Postgres, добавь ключ сервиса в `POSTGRES_MULTIPLE_DATABASES` в:

* [data-stack.yml](/home/viktor/PycharmProjects/trip-constructor/infra/stacks/data-stack.yml)

Если Postgres уже был инициализирован раньше, создай БД вручную:

```bash
docker exec -it <postgres-container> /usr/local/bin/create-service-db.sh orders
```
