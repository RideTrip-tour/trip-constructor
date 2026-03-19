
# Архитектура доставки


Стек:

* CI/CD: GitHub Actions
* Registry: Docker Hub
* Оркестрация: Docker Swarm

Схема:

```
developer
   │
   ▼
git push
   │
   ▼
GitHub Actions
   │
   ├ tests
   ├ build docker image
   ├ push → DockerHub
   │
   ▼
Docker Swarm deploy
```

---

# Git-стратегия

```
main      → production
develop   → staging
feature/* → разработка
```

Процесс:

```
feature branch
     │
     ▼
merge → develop
     │
     ▼
deploy staging
     │
     ▼
tag release
     │
     ▼
deploy production
```

---

# Требования к сервисам

Каждый сервис должен иметь:

* Dockerfile
* health endpoint
* одинаковую схему запуска

Пример Dockerfile:

```
FROM python:3.12

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---


# Подготовка Docker Swarm инфраструктуры

Создать кластер:

```bash
docker swarm init
```

Создать overlay network:

```bash
docker network create \
  --driver overlay \
  <Имя_сети>
```

---

# Как проверить ручной деплой


Перед CI/CD нужно убедиться, что **деплой работает вручную**.

```
docker stack deploy \
  -c docker-compose.prod.yml \
  <Имя_сети>
```

Если ручной деплой не работает — CI/CD тоже не будет работать.

---


### Локальный запуск SWARM

```bash
sudo docker stack deploy -c infra/stacks/data-stack.yml data
GATEWAY_SERVICE_VERSION=0.8
envsubst < infra/stacks/gateway-stack.yml | sudo docker stack deploy -c - gate
export AUTH_SERVICE_VERSION=0.6.4
envsubst < infra/stacks/app-stack.yml | sudo docker stack deploy -c - apps
```

### Локальный запуск Compose


### Запуск проекта

#### 1. Клонировать репозиторий

```bash
git clone git@github.com:RideTrip-tour/trip-constructor.git
cd trip-constructor
git submodule init
git submodule update --recursive
```

#### 2. Установить Docker и Docker Compose

Проект использует Docker для контейнеризации микросервисов. Для запуска используйте Docker Compose.

#### 3. Запуск с использованием Docker Compose

Для запуска всех сервисов, включая базы данных и очереди, используйте команду:

```bash
docker-compose up --build
```

#### 4. Остановка сервисов

Чтобы остановить все сервисы, используйте:

```bash
docker-compose down
```

#### 5. Настройка переменных окружения

Для корректной работы проекта необходимо настроить следующие переменные окружения:

- `DATABASE_URL` — URL подключения к базе данных PostgreSQL.
- `REDIS_URL` — URL подключения к Redis.
- `JWT_SECRET_KEY` — Секретный ключ для JWT.
- Другие параметры можно найти в `.env.example`.

---

# Добавление нового сервиса

При добавлении нового сервиса недостаточно только положить код в `services/`. Нужно обновить инфраструктуру, секреты и, если сервис использует PostgreSQL, создать для него отдельную БД и роль.

### 1. Добавить код сервиса

Минимально сервис должен содержать:

* `Dockerfile`
* `requirements.txt`
* `main.py`
* `/health` endpoint

Если сервис живет в отдельном репозитории, добавьте для него свой workflow:

* `.github/workflows/pr-checks.yml`

Он должен запускать `ruff` и `pytest` для `pull_request` в `dev` и `main`.

### 2. Добавить образ в деплой

Если сервис должен запускаться в Swarm, его нужно описать в stack-файле:

* либо в существующем `infra/stacks/app-stack.yml`
* либо в отдельном stack-файле, если сервис логически самостоятельный

Нужно задать:

* `image`
* `secrets`
* `environment`
* `networks`
* `deploy.restart_policy`

### 3. Добавить swarm secrets

Если сервис использует secrets, их нужно создать в Docker Swarm заранее.

Проверка:

```bash
docker secret ls
```

Создание:

```bash
printf '%s' 'value' | docker secret create SECRET_NAME -
```

Для массового создания можно использовать:

* [create-secrets.sh](/home/viktor/PycharmProjects/trip-constructor/create-secrets.sh)

### 4. Если сервису нужна PostgreSQL база

Для каждого сервиса используется отдельная база и отдельный пользователь.

Нужно создать secrets:

```bash
DB_<SERVICE>_SERVICE_NAME
DB_<SERVICE>_SERVICE_USER
DB_<SERVICE>_SERVICE_PASS
```

Пример для сервиса `orders`:

```bash
printf '%s' 'orders_db' | docker secret create DB_ORDERS_SERVICE_NAME -
printf '%s' 'orders_user' | docker secret create DB_ORDERS_SERVICE_USER -
printf '%s' 'strong-password' | docker secret create DB_ORDERS_SERVICE_PASS -
```

Если окружение уже поднято и Postgres volume уже существует, `init-multi-db.sh` заново не выполнится. В этом случае нужно вручную создать БД и роль внутри контейнера Postgres:

```bash
docker exec -it <postgres-container> /usr/local/bin/create-service-db.sh orders
```

Скрипт:

* [create-service-db.sh](/home/viktor/PycharmProjects/trip-constructor/infra/configs/postgres/create-service-db.sh)

Он уже встроен в postgres image и создает роль и базу идемпотентно.

Если сервис должен создаваться при первичной инициализации пустого Postgres volume, добавьте его ключ в `POSTGRES_MULTIPLE_DATABASES` в:

* [data-stack.yml](/home/viktor/PycharmProjects/trip-constructor/infra/stacks/data-stack.yml)

### 5. Добавить переменные и секреты сервиса в stack

Если сервис использует PostgreSQL, Redis, mail или другие зависимости, нужно:

* подключить соответствующие `secrets` в stack
* прокинуть `*_FILE` переменные в `environment`
* убедиться, что сервис подключен к нужным overlay-сетям

### 6. Проверить ручной деплой

Перед merge и CI полезно проверить, что сервис поднимается вручную:

```bash
docker stack deploy -c infra/stacks/data-stack.yml data
envsubst < infra/stacks/app-stack.yml | docker stack deploy -c - apps
docker service ls
docker service logs <service-name>
```

### 7. Что важно помнить

* `docker secret` и GitHub `secrets` это разные сущности
* новый сервис не создаст БД автоматически, если Postgres уже был инициализирован раньше
* для production release по тегу должны существовать version-tagged образы всех сервисов, участвующих в деплое
