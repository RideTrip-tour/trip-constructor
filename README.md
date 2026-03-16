
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

