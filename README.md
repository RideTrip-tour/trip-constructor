
# Active Recreation Platform (or Trip Constructor)

Это основной репозиторий для платформы активного отдыха, которая позволяет пользователям выбирать направления отдыха, планировать маршруты, рассчитывать стоимость поездок и взаимодействовать с другими путешественниками через социальную сеть.

### Описание проекта

Платформа предоставляет пользователям возможность:
- Выбрать направление активного отдыха (дайвинг, хайкинг, и другие).
- Выбрать локацию для конкретной активности.
- Получить готовые маршруты отдыха и подробное описание поездки.
- Рассчитать маршруты с учетом доступных транспортных средств (автомобиль, поезд, авиа) и стоимости билетов через сторонние API.
- Получить ссылки на билеты и возможность сохранить маршрут в PDF или поделиться им через мессенджеры.
- Найти попутчиков через соцсеть и отзывы о маршрутах.

Проект построен на микросервисной архитектуре с использованием современных технологий для обеспечения масштабируемости и надежности.

### Структура репозитория

В этом репозитории находятся все необходимые компоненты для запуска платформы, включая настройки оркестрации и взаимодействия между микросервисами. Для каждого микросервиса будет использоваться отдельный сабмодуль, подключаемый к основному репозиторию.

### Основные микросервисы

1. **auth-service** — Авторизация и аутентификация пользователей.
2. **users-service** — Управление профилями пользователей, сохранение истории поездок.
3. **activities-service** — Управление активностями и их сезонностью.
4. **locations-service** — Управление локациями для активностей.
5. **plans-service** — Генерация планов отдыха.
6. **routes-service** — Расчет маршрутов (в будущем с ИИ).
7. **departure-service** — Управление точками отправления.
8. **pricing-service** — Расчет стоимости поездок.
9. **pdf-service** — Генерация PDF-отчетов.
10. **bot-service** — Telegram-бот с поддержкой FAQ.

### Технологический стек

- **Бэкенд**: FastAPI
- **Межсервисное взаимодействие**: RabbitMQ
- **Фоновые задачи**: Celery
- **Кэширование**: Redis
- **База данных**: PostgreSQL
- **Мониторинг**: Prometheus + Grafana
- **Логи**: Loki + Promtail
- **Оркестрация**: Kubernetes
- **Балансировка трафика**: Traefik/NGINX Ingress Controller
- **PDF-генерация**: ReportLab или WeasyPrint
- **Telegram-бот**: aiogram

### Архитектура

Проект состоит из нескольких микросервисов, взаимодействующих между собой с использованием **RabbitMQ** для сообщений и **Redis** для кэширования. Для оркестрации используется **Kubernetes**, а для управления трафиком и балансировки — **Traefik** или **NGINX Ingress Controller**.

### Запуск проекта

#### 1. Клонировать репозиторий

```bash
git clone git@github.com:RideTrip-tour/trip-constructor.git
cd trip-constructor
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
- `RABBITMQ_URL` — URL подключения к RabbitMQ.
- `JWT_SECRET_KEY` — Секретный ключ для JWT.
- Другие параметры можно найти в `.env.example`.

### Разработка

Чтобы начать разработку, выполните следующие шаги:

1. Установите зависимости для каждого микросервиса:
   ```bash
   pip install -r requirements.txt
   ```

2. Для тестирования используйте `pytest`:
   ```bash
   pytest
   ```

3. Для локального запуска отдельных сервисов можно использовать команды FastAPI, например:
   ```bash
   uvicorn users-service.main:app --reload
   ```

### Мониторинг

Мониторинг и визуализация метрик осуществляется с использованием **Prometheus** и **Grafana**. Все метрики доступны через интерфейс Grafana.

### Логи

Логи всех сервисов собираются с использованием **Loki** и **Promtail**, и могут быть просмотрены через интерфейс Grafana.

### Контрибьюция

Мы рады любым улучшениям проекта! Чтобы внести изменения:

1. Форкните репозиторий.
2. Создайте новую ветку (`git checkout -b feature-name`).
3. Сделайте изменения и создайте коммит (`git commit -am 'Add new feature'`).
4. Отправьте ваш фрагмент кода на ваш форк (`git push origin feature-name`).
5. Создайте Pull Request в основную ветку репозитория.

### Лицензия

Этот проект лицензирован под **MIT** лицензией.
