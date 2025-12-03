# 📊 Полное руководство по Grafana Monitoring Stack

## 📑 Содержание

1. [Обзор системы](#обзор-системы)
2. [Компоненты](#компоненты)
3. [Требования](#требования)
4. [Установка](#установка)
5. [Настройка безопасности](#настройка-безопасности)
6. [Использование](#использование)
7. [Мониторинг и алерты](#мониторинг-и-алерты)
8. [Устранение неполадок](#устранение-неполадок)
9. [Резервное копирование](#резервное-копирование)
10. [Масштабирование](#масштабирование)

---

## 🎯 Обзор системы

Это комплексная система мониторинга на базе Docker, включающая:

- **Grafana** - визуализация данных и дашборды
- **Prometheus** - сбор и хранение метрик
- **Loki** - агрегация и анализ логов
- **Alertmanager** - управление оповещениями
- **Node Exporter** - метрики хостовой системы
- **cAdvisor** - мониторинг Docker контейнеров
- **Promtail** - сбор логов
- **Blackbox Exporter** - проверка доступности сервисов

### Ключевые улучшения безопасности

✅ Обновленные версии всех компонентов
✅ Изолированная сеть Docker
✅ Ограничения ресурсов (CPU/Memory)
✅ Healthcheck для всех сервисов
✅ Read-only файловые системы где возможно
✅ Защита от privilege escalation
✅ Автоматические алерты о проблемах

---

## 🔧 Компоненты

### Grafana (порт 3000)
- **Версия**: 10.2.3
- **Назначение**: Визуализация метрик и логов
- **URL**: http://localhost:3000
- **Логин по умолчанию**: admin / changeme

### Prometheus (порт 9090)
- **Версия**: 2.48.1
- **Назначение**: Сбор и хранение метрик
- **URL**: http://localhost:9090
- **Retention**: 30 дней

### Alertmanager (порт 9093)
- **Версия**: 0.26.0
- **Назначение**: Управление алертами
- **URL**: http://localhost:9093

### Loki (порт 3100)
- **Версия**: 2.9.3
- **Назначение**: Хранение и поиск логов
- **URL**: http://localhost:3100

### Node Exporter (порт 9100)
- **Версия**: 1.7.0
- **Назначение**: Метрики операционной системы

### cAdvisor (порт 8080)
- **Версия**: 0.47.2
- **Назначение**: Метрики Docker контейнеров

### Blackbox Exporter (порт 9115)
- **Версия**: 0.24.0
- **Назначение**: Проверка доступности сервисов

---

## 📋 Требования

### Минимальные требования:
- **OS**: Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+)
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 20 GB свободного места
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

### Рекомендуемые требования:
- **CPU**: 4+ cores
- **RAM**: 8+ GB
- **Disk**: 50+ GB (SSD)
- **Network**: 100+ Mbps

---

## 🚀 Установка

### Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/yourusername/grafana-monitoring-stack.git
cd grafana-monitoring-stack
```

### Шаг 2: Настройка переменных окружения

```bash
# Скопируйте файл примера
cp .env.example .env

# ОБЯЗАТЕЛЬНО отредактируйте .env и измените пароли!
nano .env
```

**Важные параметры в .env:**
```bash
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=ВАШ_СИЛЬНЫЙ_ПАРОЛЬ
HOSTNAME=мой-сервер
TZ=Europe/Moscow
```

### Шаг 3: Проверка конфигурации

```bash
# Проверка синтаксиса docker-compose
docker compose config

# Проверка конфигурации Prometheus
docker run --rm -v $(pwd)/configs/prometheus:/etc/prometheus \
  prom/prometheus:v2.48.1 \
  promtool check config /etc/prometheus/prometheus.yml

# Проверка правил алертинга
docker run --rm -v $(pwd)/configs/prometheus:/etc/prometheus \
  prom/prometheus:v2.48.1 \
  promtool check rules /etc/prometheus/alerts.yml
```

### Шаг 4: Запуск системы

```bash
# Запуск всех сервисов
docker compose up -d

# Просмотр логов
docker compose logs -f

# Проверка статуса
docker compose ps
```

### Шаг 5: Проверка работоспособности

```bash
# Проверка всех сервисов
curl -s http://localhost:3000/api/health        # Grafana
curl -s http://localhost:9090/-/healthy         # Prometheus
curl -s http://localhost:9093/-/healthy         # Alertmanager
curl -s http://localhost:3100/ready             # Loki
curl -s http://localhost:9100/metrics | head    # Node Exporter
curl -s http://localhost:8080/healthz           # cAdvisor
```

---

## 🔒 Настройка безопасности

### 1. Изменение паролей

**Grafana:**
```bash
# Через веб-интерфейс: User > Change Password
# Или через CLI в контейнере:
docker exec -it grafana grafana-cli admin reset-admin-password НОВЫЙ_ПАРОЛЬ
```

### 2. Настройка firewall

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 3000/tcp        # Grafana
sudo ufw deny 9090/tcp         # Закрыть Prometheus снаружи
sudo ufw deny 9100/tcp         # Закрыть Node Exporter
sudo ufw enable

# Или используйте iptables
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9090 -s 127.0.0.1 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9090 -j DROP
```

### 3. Настройка SSL/TLS (с Nginx)

```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx

# Получение сертификата
sudo certbot --nginx -d monitoring.example.com

# Пример конфигурации Nginx
cat > /etc/nginx/sites-available/grafana << 'EOF'
server {
    listen 443 ssl http2;
    server_name monitoring.example.com;

    ssl_certificate /etc/letsencrypt/live/monitoring.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monitoring.example.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/grafana /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 4. Ограничение доступа по IP

В `docker-compose.yml` измените порты:
```yaml
ports:
  - "127.0.0.1:3000:3000"  # Только localhost
  - "192.168.1.0/24:9090:9090"  # Только локальная сеть
```

### 5. Включение аудита

```bash
# Добавьте в configs/grafana/grafana.ini
[log]
mode = console file
level = info

[auditing]
enabled = true
log_dashboard_content = true
```

---

## 💻 Использование

### Доступ к интерфейсам

1. **Grafana**: http://localhost:3000
   - Логин: admin (или из .env)
   - Пароль: changeme (ИЗМЕНИТЕ!)

2. **Prometheus**: http://localhost:9090
   - Просмотр метрик и выполнение PromQL запросов

3. **Alertmanager**: http://localhost:9093
   - Управление активными алертами

### Создание первого дашборда в Grafana

1. Откройте Grafana (http://localhost:3000)
2. Войдите с учетными данными
3. Нажмите "+" → "Import"
4. Введите ID дашборда или JSON:
   - **1860** - Node Exporter Full
   - **193** - Docker Monitoring
   - **12486** - Loki Dashboard

### Популярные дашборды

```bash
# Node Exporter (системные метрики)
ID: 1860
URL: https://grafana.com/grafana/dashboards/1860

# Docker Container Monitoring
ID: 193
URL: https://grafana.com/grafana/dashboards/193

# Prometheus Stats
ID: 2
URL: https://grafana.com/grafana/dashboards/2

# Loki & Promtail
ID: 13639
URL: https://grafana.com/grafana/dashboards/13639
```

### Основные PromQL запросы

**Загрузка CPU:**
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Использование памяти:**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Использование диска:**
```promql
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

**Сетевой трафик:**
```promql
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

**Uptime сервисов:**
```promql
up{job="prometheus"}
```

### Работа с логами в Loki

**LogQL запросы:**

```logql
# Все логи Grafana
{job="grafana"}

# Только ошибки
{job="grafana"} |= "error"

# С фильтром по времени и уровню
{job="grafana", level="error"} | json | line_format "{{.msg}}"

# Подсчет ошибок за период
count_over_time({job="grafana"} |= "error" [5m])
```

---

## 🚨 Мониторинг и алерты

### Настроенные алерты

Система включает автоматические алерты для:

#### 🔴 Критические (Critical)
- Сервис недоступен более 2 минут
- CPU загрузка > 95%
- Память > 95%
- Диск заполнен > 95%

#### ⚠️ Предупреждения (Warning)
- CPU загрузка > 80%
- Память > 80%
- Диск заполнен > 80%
- Высокая загрузка I/O
- Сетевые ошибки

#### 🔒 Безопасность (Security)
- SSL сертификат истекает через 30 дней
- Подозрительная активность

### Настройка Email уведомлений

Отредактируйте `configs/alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'your_app_password'
  smtp_require_tls: true

receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: 'oncall@example.com'
        subject: '🚨 [CRITICAL] {{ .GroupLabels.alertname }}'
```

После изменения перезагрузите Alertmanager:
```bash
docker compose restart alertmanager
```

### Настройка Slack уведомлений

```yaml
receivers:
  - name: 'slack-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#monitoring'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Тестирование алертов

```bash
# Искусственная нагрузка CPU
docker run --rm -it alpine sh -c "while true; do true; done"

# Заполнение памяти
docker run --rm -it alpine sh -c "tail /dev/zero"

# Проверка алертов в Alertmanager
curl http://localhost:9093/api/v2/alerts
```

---

## 🔍 Устранение неполадок

### Проверка логов

```bash
# Все сервисы
docker compose logs -f

# Конкретный сервис
docker compose logs -f grafana
docker compose logs -f prometheus

# Последние 100 строк
docker compose logs --tail=100 prometheus
```

### Проблема: Grafana не запускается

```bash
# Проверка логов
docker compose logs grafana

# Проверка прав доступа
sudo chown -R 472:472 configs/grafana

# Пересоздание контейнера
docker compose down
docker compose up -d grafana
```

### Проблема: Prometheus не собирает метрики

```bash
# Проверка targets в Prometheus UI
open http://localhost:9090/targets

# Проверка конфигурации
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Перезагрузка конфигурации
curl -X POST http://localhost:9090/-/reload
```

### Проблема: Alertmanager не отправляет уведомления

```bash
# Проверка конфигурации
docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml

# Проверка алертов
curl http://localhost:9093/api/v2/alerts | jq

# Проверка SMTP соединения
docker exec alertmanager nc -zv smtp.gmail.com 587
```

### Проблема: Высокое потребление ресурсов

```bash
# Проверка использования ресурсов
docker stats

# Уменьшение retention в Prometheus (configs/prometheus/prometheus.yml)
--storage.tsdb.retention.time=15d

# Ограничение памяти Loki (configs/loki/loki.yml)
limits_config:
  ingestion_rate_mb: 5
  ingestion_burst_size_mb: 10
```

### Очистка старых данных

```bash
# Prometheus
docker compose down prometheus
docker volume rm grafana-docker-for_Desktop_lite-_prom-data
docker compose up -d prometheus

# Loki
docker compose down loki
docker volume rm grafana-docker-for_Desktop_lite-_loki-data
docker compose up -d loki

# Или очистка всех данных
docker compose down -v
docker compose up -d
```

---

## 💾 Резервное копирование

### Автоматический скрипт резервного копирования

Создайте файл `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backup/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="monitoring_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR

# Остановка сервисов для консистентности (опционально)
# docker compose stop

# Резервное копирование томов Docker
docker run --rm \
  -v grafana-docker-for_Desktop_lite-_grafana-data:/grafana:ro \
  -v grafana-docker-for_Desktop_lite-_prom-data:/prometheus:ro \
  -v grafana-docker-for_Desktop_lite-_loki-data:/loki:ro \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/$BACKUP_FILE \
  /grafana /prometheus /loki

# Резервное копирование конфигураций
tar czf $BACKUP_DIR/configs_$DATE.tar.gz configs/

# Запуск сервисов
# docker compose start

# Удаление старых бэкапов (старше 30 дней)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE"
```

```bash
chmod +x backup.sh

# Добавить в cron для ежедневного резервного копирования
crontab -e
# Добавьте: 0 2 * * * /path/to/backup.sh
```

### Восстановление из резервной копии

```bash
#!/bin/bash
BACKUP_FILE="monitoring_backup_20231203_020000.tar.gz"

# Остановка сервисов
docker compose down

# Восстановление данных
docker run --rm \
  -v grafana-docker-for_Desktop_lite-_grafana-data:/grafana \
  -v grafana-docker-for_Desktop_lite-_prom-data:/prometheus \
  -v grafana-docker-for_Desktop_lite-_loki-data:/loki \
  -v /backup/monitoring:/backup:ro \
  alpine tar xzf /backup/$BACKUP_FILE -C /

# Восстановление конфигураций
tar xzf /backup/monitoring/configs_20231203_020000.tar.gz

# Запуск сервисов
docker compose up -d
```

---

## 📈 Масштабирование

### Добавление дополнительных серверов для мониторинга

1. **На целевом сервере установите Node Exporter:**

```bash
# Скачайте node-exporter.yml
wget https://raw.githubusercontent.com/yourusername/grafana-monitoring-stack/main/node-exporter.yml

# Запустите
docker compose -f node-exporter.yml up -d
```

2. **Добавьте сервер в Prometheus конфигурацию:**

Отредактируйте `configs/prometheus/prometheus.yml`:

```yaml
- job_name: 'node-exporter'
  static_configs:
    - targets:
        - 'node-exporter:9100'
        - 'server1.example.com:9100'  # Новый сервер
        - 'server2.example.com:9100'  # Еще один
      labels:
        env: 'production'
```

3. **Перезагрузите конфигурацию:**

```bash
curl -X POST http://localhost:9090/-/reload
```

### Мониторинг внешних HTTP сервисов

Добавьте в `configs/prometheus/prometheus.yml`:

```yaml
- job_name: 'blackbox-http'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
        - https://example.com
        - https://api.example.com
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter:9115
```

### Масштабирование для больших нагрузок

Для высоконагруженных систем рассмотрите:

1. **Использование внешних БД для Grafana:**
```yaml
# В docker-compose.yml для Grafana
environment:
  - GF_DATABASE_TYPE=postgres
  - GF_DATABASE_HOST=postgres:5432
  - GF_DATABASE_NAME=grafana
  - GF_DATABASE_USER=grafana
  - GF_DATABASE_PASSWORD=password
```

2. **Prometheus Federation (для множества Prometheus серверов):**
```yaml
- job_name: 'federate'
  scrape_interval: 15s
  honor_labels: true
  metrics_path: '/federate'
  params:
    'match[]':
      - '{job="prometheus"}'
      - '{__name__=~"job:.*"}'
  static_configs:
    - targets:
      - 'prometheus1:9090'
      - 'prometheus2:9090'
```

3. **Использование Thanos для долгосрочного хранения метрик**

---

## 📞 Поддержка и документация

### Полезные ссылки

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Basics](https://grafana.com/docs/loki/latest/logql/)

### Команды для управления

```bash
# Запуск
docker compose up -d

# Остановка
docker compose stop

# Перезапуск
docker compose restart

# Остановка и удаление контейнеров
docker compose down

# Полная очистка (включая volumes)
docker compose down -v

# Обновление образов
docker compose pull
docker compose up -d

# Просмотр логов
docker compose logs -f [service_name]

# Выполнение команд в контейнере
docker compose exec grafana sh

# Проверка статуса
docker compose ps
```

---

## 🎓 Дополнительные возможности

### Интеграция с другими сервисами

- **MySQL/PostgreSQL monitoring** - добавьте mysqld_exporter или postgres_exporter
- **Redis monitoring** - используйте redis_exporter
- **Nginx monitoring** - nginx-prometheus-exporter
- **Kubernetes** - используйте kube-state-metrics

### Пример добавления MySQL exporter

```yaml
# В docker-compose.yml
  mysql-exporter:
    image: prom/mysqld-exporter:latest
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=user:password@(mysql:3306)/
    networks:
      - monitoring
```

---

## ✅ Чеклист после установки

- [ ] Изменены все пароли по умолчанию
- [ ] Настроен firewall
- [ ] Настроен SSL/TLS (если нужен внешний доступ)
- [ ] Импортированы дашборды в Grafana
- [ ] Настроены уведомления в Alertmanager
- [ ] Проверены все алерты
- [ ] Настроено резервное копирование
- [ ] Документированы все изменения
- [ ] Протестирована система мониторинга

---

**Версия**: 2.0
**Дата обновления**: 2025-12-03
**Автор**: Grafana Monitoring Stack Team
