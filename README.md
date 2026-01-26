
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


### Лицензия

Этот проект лицензирован под **MIT** лицензией.
