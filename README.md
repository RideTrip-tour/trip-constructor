# Trip Constructor Infra

## Что находится в репозитории

Этот репозиторий содержит инфраструктуру и orchestration для сервисов проекта:

* CI/CD через GitHub Actions
* Docker image build и push в Docker Hub
* деплой в Docker Swarm
* stack-файлы для `data`, `gate`, `apps`
* bootstrap PostgreSQL для сервисных баз

Основные каталоги:

* `services/` - сервисы проекта
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
   +-- deploy gate/apps
```

## Git и релизы

Текущая схема workflow:

* `pull_request -> main` - проверки сервисов
* `push -> main` - dev build и deploy
* `push tag v*` - production release

Релизный pipeline использует единую версию образов по тегу. Это значит, что при `push` тега собираются все релизные образы, участвующие в деплое.

## Требования к сервису

Минимально новый сервис должен содержать:

* `Dockerfile`
* `requirements.txt`
* `main.py`
* `/health` endpoint

Если сервис живет в отдельном репозитории, в нем должен быть свой workflow `pr-checks.yml`, который запускает:

* `ruff`
* `pytest`

для `pull_request` в `dev` и `main`.

## Локальный запуск

### Клонирование

```bash
git clone git@github.com:RideTrip-tour/trip-constructor.git
cd trip-constructor
git submodule init
git submodule update --recursive
```

### Docker Compose

```bash
docker-compose up --build
```

Остановка:

```bash
docker-compose down
```

### Docker Swarm

Локальный пример запуска:

```bash
docker network create --driver overlay --attachable data-network
docker network create --driver overlay --attachable internal-network

export DOCKERHUB_NAMESPACE=ride2trip
export POSTGRES_IMAGE_VERSION=dev
export AUTH_SERVICE_VERSION=dev
export GATEWAY_SERVICE_VERSION=dev
export GATEWAY_PORT=8081
export ORIGIN=https://dev.trip.elmobil.ru
export LK_PATH=/users/me/
export REFRESH_TOKEN_PATH=/api/auth/refresh

envsubst < infra/stacks/data-stack.yml | docker stack deploy -c - data
envsubst < infra/stacks/gateway-stack.yml | docker stack deploy -c - gate
envsubst < infra/stacks/app-stack.yml | docker stack deploy -c - apps
```

## Docker Swarm bootstrap

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

### Создание secrets

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

* определяет измененные части репозитория
* на PR в `main` запускает `ruff` и `pytest`
* на push в `main` собирает нужные dev-образы
* создает swarm-сети при необходимости
* деплоит `data`
* ждет готовности Postgres
* запускает миграции
* деплоит `gate` и `apps`

### Release Prod

Файл:

* [release-prod.yml](/home/viktor/PycharmProjects/trip-constructor/.github/workflows/release-prod.yml)

Что делает:

* запускается по тегу `v*`
* всегда собирает все релизные образы
* деплоит `data`
* ждет готовности Postgres
* запускает миграции
* деплоит `gate` и `apps`

## Ручная проверка деплоя

Перед CI/CD полезно уметь проверить deploy вручную.

Порядок:

```bash
envsubst < infra/stacks/data-stack.yml | docker stack deploy -c - data
docker service ls
docker service logs data_postgres

envsubst < infra/stacks/gateway-stack.yml | docker stack deploy -c - gate
envsubst < infra/stacks/app-stack.yml | docker stack deploy -c - apps
docker service ls
```

Если ручной deploy не работает, CI/CD тоже не будет работать.

## Добавление нового сервиса

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

### 5. Если сервису нужны миграции

Логика запуска migration job вынесена в:

* [run-swarm-migrations.sh](/home/viktor/PycharmProjects/trip-constructor/infra/run-swarm-migrations.sh)

Но список сервисов с миграциями сейчас хранится явно в workflow, то есть новый migration-step нужно добавлять вручную в:

* [ci-dev.yml](/home/viktor/PycharmProjects/trip-constructor/.github/workflows/ci-dev.yml)
* [release-prod.yml](/home/viktor/PycharmProjects/trip-constructor/.github/workflows/release-prod.yml)

Пример для `orders-service`:

```yaml
- name: Run orders migrations
  run: |
    set -euo pipefail
    bash infra/run-swarm-migrations.sh \
      swarm \
      "$GITHUB_RUN_ID" \
      orders \
      "${DOCKERHUB_NAMESPACE}/orders-service:${ORDERS_SERVICE_VERSION}"
```

`service_key` должен совпадать с database secret prefix:

* `orders` -> `DB_ORDERS_SERVICE_*`
* `auth` -> `DB_AUTH_SERVICE_*`

Также migration image должен уметь запускаться в режиме миграций, например через `APP_MODE=migrate`.

### 6. Проверить сервис вручную

После добавления сервиса полезно проверить:

```bash
docker service ls
docker service logs <service-name>
docker secret ls
docker network ls
```

## Полезные команды

Удалить stack:

```bash
docker stack rm apps gate data
```

Удалить volume Postgres:

```bash
docker volume rm data_postgres-data
```

Удалить secrets:

```bash
docker secret ls
docker secret rm SECRET_NAME
```

Создать сервисную БД вручную:

```bash
docker exec -it <postgres-container> /usr/local/bin/create-service-db.sh auth
```

## Важные замечания

* `init-multi-db.sh` выполняется только на пустом Postgres volume
* добавление нового сервиса не создает БД автоматически в уже существующем окружении
* новый сервис с миграциями нужно явно добавить в `ci-dev.yml` и `release-prod.yml`
* production release ожидает, что все нужные образы существуют с одним и тем же release tag
