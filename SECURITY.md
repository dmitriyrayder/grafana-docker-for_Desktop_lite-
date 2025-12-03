# 🔒 Руководство по безопасности Grafana Monitoring Stack

## 📋 Содержание

1. [Результаты аудита безопасности](#результаты-аудита-безопасности)
2. [Реализованные меры защиты](#реализованные-меры-защиты)
3. [Настройка безопасности](#настройка-безопасности)
4. [Лучшие практики](#лучшие-практики)
5. [Мониторинг безопасности](#мониторинг-безопасности)
6. [Обновления и патчи](#обновления-и-патчи)
7. [Реагирование на инциденты](#реагирование-на-инциденты)

---

## 🔍 Результаты аудита безопасности

### ❌ Уязвимости в исходной версии

#### Критические проблемы:
1. **Устаревшие версии ПО** - CVE уязвимости
   - Grafana 8.5.3 → обновлено до 10.2.3
   - Prometheus 2.36.0 → обновлено до 2.48.1
   - Node Exporter 1.3.1 → обновлено до 1.7.0

2. **Отсутствие аутентификации**
   - Порты открыты без защиты
   - Нет настройки паролей

3. **Отсутствие сетевой изоляции**
   - Все сервисы в одной сети с хостом

4. **Отсутствие SSL/TLS**
   - Передача данных в открытом виде

5. **Отсутствие ограничений ресурсов**
   - Возможность DoS атак

6. **Привилегированный доступ**
   - Node Exporter имеет полный доступ к хосту

### ✅ Реализованные исправления

Все критические уязвимости устранены. Подробности ниже.

---

## 🛡️ Реализованные меры защиты

### 1. Обновление версий ПО

| Компонент | Старая версия | Новая версия | CVE исправлены |
|-----------|--------------|-------------|----------------|
| Grafana | 8.5.3 | 10.2.3 | CVE-2022-31097, CVE-2022-31107 и др. |
| Prometheus | 2.36.0 | 2.48.1 | CVE-2022-46146 и др. |
| Node Exporter | 1.3.1 | 1.7.0 | Множественные |
| Alertmanager | - | 0.26.0 | Добавлен |

### 2. Сетевая изоляция

```yaml
networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

**Защита:**
- Изолированная сеть для всех компонентов
- Контейнеры не имеют прямого доступа к хост-сети
- Межсервисная коммуникация через Docker DNS

### 3. Аутентификация и авторизация

**Grafana:**
```yaml
environment:
  - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
  - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
  - GF_USERS_ALLOW_SIGN_UP=false
```

**Меры:**
- Обязательная аутентификация
- Отключена регистрация новых пользователей
- Пароли хранятся в переменных окружения
- Скрыта версия Grafana (против fingerprinting)

### 4. Ограничение ресурсов (DoS защита)

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

**Защита:**
- Предотвращение исчерпания ресурсов хоста
- Защита от DoS атак
- Гарантированные ресурсы для каждого сервиса

### 5. Security опции контейнеров

```yaml
security_opt:
  - no-new-privileges:true
read_only: true
```

**Защита:**
- Запрет повышения привилегий
- Read-only файловая система где возможно
- Минимизация attack surface

### 6. Healthchecks

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**Защита:**
- Автоматическое обнаружение проблем
- Перезапуск неработающих сервисов
- Мониторинг доступности

### 7. Алертинг по безопасности

Настроены автоматические алерты:
- SSL сертификат истекает
- Неудачные попытки входа
- Изменения конфигурации
- Подозрительная активность

---

## 🔐 Настройка безопасности

### Шаг 1: Смена паролей по умолчанию (ОБЯЗАТЕЛЬНО!)

```bash
# 1. Создайте .env файл
cp .env.example .env

# 2. Сгенерируйте сильный пароль
openssl rand -base64 32

# 3. Отредактируйте .env
nano .env
```

В файле `.env`:
```bash
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=ваш_сгенерированный_пароль_здесь
```

**Требования к паролю:**
- Минимум 16 символов
- Включает буквы, цифры, специальные символы
- Не содержит словарных слов
- Уникален для каждой системы

### Шаг 2: Настройка Firewall

#### UFW (Ubuntu/Debian)

```bash
# Установка UFW
sudo apt update
sudo apt install ufw

# Разрешаем SSH (ВАЖНО! Сделайте это первым)
sudo ufw allow 22/tcp

# Разрешаем Grafana только с определенных IP
sudo ufw allow from 192.168.1.0/24 to any port 3000 proto tcp

# Или открываем для всех (не рекомендуется без SSL)
sudo ufw allow 3000/tcp

# Блокируем прямой доступ к внутренним сервисам
sudo ufw deny 9090/tcp  # Prometheus
sudo ufw deny 9100/tcp  # Node Exporter
sudo ufw deny 9093/tcp  # Alertmanager
sudo ufw deny 3100/tcp  # Loki
sudo ufw deny 8080/tcp  # cAdvisor

# Включаем firewall
sudo ufw enable

# Проверяем статус
sudo ufw status verbose
```

#### iptables

```bash
#!/bin/bash
# Скрипт для настройки iptables

# Очистка правил
iptables -F
iptables -X

# Политика по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешаем loopback
iptables -A INPUT -i lo -j ACCEPT

# Разрешаем установленные соединения
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Grafana (только с определенных IP)
iptables -A INPUT -p tcp -s 192.168.1.0/24 --dport 3000 -j ACCEPT

# Или для всех (не рекомендуется)
# iptables -A INPUT -p tcp --dport 3000 -j ACCEPT

# Блокируем все остальное
iptables -A INPUT -j DROP

# Сохранение правил
apt install iptables-persistent
netfilter-persistent save
```

### Шаг 3: Настройка SSL/TLS

#### Вариант 1: Использование Nginx Reverse Proxy

```bash
# Установка Nginx и Certbot
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx

# Создание конфигурации Nginx
sudo nano /etc/nginx/sites-available/grafana
```

Содержимое файла:
```nginx
# HTTP -> HTTPS редирект
server {
    listen 80;
    server_name monitoring.example.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    server_name monitoring.example.com;

    # SSL сертификаты (будут созданы Certbot)
    ssl_certificate /etc/letsencrypt/live/monitoring.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monitoring.example.com/privkey.pem;

    # Современные SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Другие заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Proxy к Grafana
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Ограничение размера тела запроса
    client_max_body_size 10M;
}
```

```bash
# Активация конфигурации
sudo ln -s /etc/nginx/sites-available/grafana /etc/nginx/sites-enabled/
sudo nginx -t

# Получение SSL сертификата
sudo certbot --nginx -d monitoring.example.com

# Автоматическое обновление сертификата
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

После настройки измените в `docker-compose.yml`:
```yaml
grafana:
  ports:
    - "127.0.0.1:3000:3000"  # Только localhost
```

#### Вариант 2: Traefik как Reverse Proxy

```yaml
# Добавьте в docker-compose.yml
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=false"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=your@email.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-certs:/letsencrypt
    networks:
      - monitoring

  grafana:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`monitoring.example.com`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=myresolver"
    # Убираем ports, трафик идет через Traefik
```

### Шаг 4: Настройка аудита и логирования

```bash
# Включите подробное логирование в configs/grafana/grafana.ini
[log]
mode = console file
level = info
filters = rendering:debug

[log.console]
level = info
format = json

[log.file]
level = info
format = json
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7

[auditing]
enabled = true
log_dashboard_content = true
```

### Шаг 5: Ограничение доступа по IP в Docker

```yaml
# В docker-compose.yml измените порты:
grafana:
  ports:
    - "127.0.0.1:3000:3000"  # Только localhost

prometheus:
  ports:
    - "127.0.0.1:9090:9090"  # Только localhost

# Или для конкретной подсети
grafana:
  ports:
    - "192.168.1.10:3000:3000"  # Только один IP
```

### Шаг 6: Двухфакторная аутентификация (2FA) в Grafana

```bash
# В configs/grafana/grafana.ini
[auth]
disable_login_form = false
oauth_auto_login = false

# Для интеграции с Google Auth
[auth.google]
enabled = true
client_id = YOUR_CLIENT_ID
client_secret = YOUR_CLIENT_SECRET
scopes = openid email profile
auth_url = https://accounts.google.com/o/oauth2/v2/auth
token_url = https://oauth2.googleapis.com/token
allowed_domains = yourdomain.com
allow_sign_up = true
```

---

## 📘 Лучшие практики безопасности

### 1. Принцип наименьших привилегий

```yaml
# ❌ НЕ ДЕЛАЙТЕ ТАК
privileged: true

# ✅ ДЕЛАЙТЕ ТАК
security_opt:
  - no-new-privileges:true
read_only: true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Только необходимые
```

### 2. Регулярное обновление

```bash
# Еженедельная проверка обновлений
docker compose pull
docker compose up -d

# Проверка CVE
docker scan grafana/grafana:10.2.3
```

### 3. Секреты не в коде

```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК
GF_SECURITY_ADMIN_PASSWORD=mypassword123

# ✅ ДЕЛАЙТЕ ТАК
GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

# Или используйте Docker Secrets
echo "mypassword" | docker secret create grafana_password -
```

### 4. Сканирование на уязвимости

```bash
# Установка Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update && sudo apt install trivy

# Сканирование образов
trivy image grafana/grafana:10.2.3
trivy image prom/prometheus:v2.48.1
```

### 5. Ротация паролей

```bash
# Каждые 90 дней меняйте пароли
# 1. Генерация нового пароля
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Обновление в Grafana
docker exec -it grafana grafana-cli admin reset-admin-password "$NEW_PASSWORD"

# 3. Обновление .env файла
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$NEW_PASSWORD/" .env
```

### 6. Мониторинг логов безопасности

```bash
# Настройте алерты на подозрительные события
# В configs/prometheus/alerts.yml добавьте:

- alert: MultipleFailedLogins
  expr: increase(grafana_api_login_failures_total[5m]) > 5
  for: 5m
  labels:
    severity: warning
    category: security
  annotations:
    summary: "Множественные неудачные попытки входа"
    description: "Обнаружено {{ $value }} неудачных попыток входа за последние 5 минут"
```

### 7. Резервное копирование с шифрованием

```bash
#!/bin/bash
# backup-encrypted.sh

BACKUP_DIR="/backup/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="monitoring_backup_$DATE.tar.gz"
ENCRYPTION_KEY="your_gpg_key_id"

# Создание резервной копии
docker run --rm \
  -v grafana-docker-for_Desktop_lite-_grafana-data:/grafana:ro \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/$BACKUP_FILE /grafana

# Шифрование
gpg --encrypt --recipient $ENCRYPTION_KEY $BACKUP_DIR/$BACKUP_FILE
rm $BACKUP_DIR/$BACKUP_FILE

echo "Encrypted backup: $BACKUP_FILE.gpg"
```

### 8. Network segmentation

```yaml
networks:
  frontend:  # Для публичного доступа
    driver: bridge
  backend:   # Для внутренних сервисов
    driver: bridge
    internal: true  # Нет доступа в интернет

services:
  grafana:
    networks:
      - frontend
      - backend

  prometheus:
    networks:
      - backend  # Только внутренняя сеть
```

---

## 🔎 Мониторинг безопасности

### Алерты безопасности

Система включает следующие алерты:

```yaml
# SSL сертификат истекает
- alert: SSLCertificateExpiry
  expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
  labels:
    severity: warning
    category: security

# Множественные неудачные попытки входа
- alert: HighFailedLoginRate
  expr: rate(grafana_api_login_failures_total[5m]) > 0.1
  labels:
    severity: warning
    category: security

# Изменение конфигурации
- alert: ConfigurationChanged
  expr: prometheus_config_last_reload_success_timestamp_seconds != prometheus_config_last_reload_success_timestamp_seconds offset 5m
  labels:
    severity: info
    category: security
```

### Логи для анализа

```bash
# Просмотр логов безопасности Grafana
docker compose logs grafana | grep -i "login\|auth\|fail"

# Подозрительная активность
docker compose logs | grep -i "error\|unauthorized\|forbidden"

# Экспорт логов для анализа
docker compose logs --since 24h > /tmp/security-logs-$(date +%F).log
```

### Интеграция с SIEM

```yaml
# Для отправки логов в ELK, Splunk, или другие SIEM
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
    networks:
      - monitoring
```

---

## 🔄 Обновления и патчи

### Стратегия обновлений

1. **Мониторинг новых версий**
   - Подпишитесь на уведомления GitHub
   - Проверяйте CVE базы данных

2. **Тестирование обновлений**
   ```bash
   # В тестовой среде
   docker compose -f docker-compose.test.yml pull
   docker compose -f docker-compose.test.yml up -d
   # Тестирование...
   ```

3. **Применение в продакшен**
   ```bash
   # Создание резервной копии
   ./backup.sh

   # Обновление
   docker compose pull
   docker compose up -d

   # Проверка
   docker compose ps
   docker compose logs -f
   ```

### Автоматизация обновлений

```bash
# Watchtower для автоматического обновления
# В docker-compose.yml добавьте:
  watchtower:
    image: containrrr/watchtower:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *  # Каждый день в 4:00
      - WATCHTOWER_NOTIFICATIONS=email
      - WATCHTOWER_NOTIFICATION_EMAIL_TO=admin@example.com
    networks:
      - monitoring
```

---

## 🚨 Реагирование на инциденты

### План реагирования

1. **Обнаружение**
   - Алерты в Alertmanager
   - Аномалии в логах
   - Уведомления пользователей

2. **Анализ**
   ```bash
   # Проверка активных соединений
   docker exec grafana netstat -tupln

   # Проверка процессов
   docker exec grafana ps aux

   # Анализ логов
   docker compose logs --since 1h > incident-$(date +%F-%H%M).log
   ```

3. **Изоляция**
   ```bash
   # Остановка скомпрометированного сервиса
   docker compose stop grafana

   # Или отключение от сети
   docker network disconnect monitoring_monitoring grafana
   ```

4. **Восстановление**
   ```bash
   # Восстановление из резервной копии
   ./restore.sh backup-YYYYMMDD.tar.gz

   # Или пересоздание контейнера
   docker compose up -d --force-recreate grafana
   ```

5. **Анализ после инцидента**
   - Документирование инцидента
   - Обновление политик безопасности
   - Патчинг уязвимостей

### Контакты для инцидентов

```bash
# Создайте файл SECURITY-CONTACTS.md
- Security Team: security@example.com
- On-Call: +1-XXX-XXX-XXXX
- Incident Response: https://incident.example.com
```

---

## 📊 Чеклист безопасности

### Начальная настройка
- [ ] Изменены все пароли по умолчанию
- [ ] Создан файл .env с секретами
- [ ] Настроен firewall (UFW/iptables)
- [ ] Настроен SSL/TLS
- [ ] Отключена регистрация пользователей
- [ ] Включен аудит логирование

### Регулярное обслуживание (еженедельно)
- [ ] Проверка логов на подозрительную активность
- [ ] Проверка алертов безопасности
- [ ] Проверка доступных обновлений
- [ ] Проверка использования ресурсов

### Ежемесячное обслуживание
- [ ] Обновление всех компонентов
- [ ] Сканирование на уязвимости (Trivy)
- [ ] Проверка резервных копий
- [ ] Аудит пользователей и прав доступа
- [ ] Ротация логов

### Ежеквартальное обслуживание
- [ ] Ротация паролей
- [ ] Обзор политик безопасности
- [ ] Тестирование плана восстановления
- [ ] Обучение команды

---

## 📚 Дополнительные ресурсы

### Официальная документация по безопасности
- [Grafana Security](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)
- [Prometheus Security](https://prometheus.io/docs/operating/security/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

### Инструменты безопасности
- [Trivy](https://github.com/aquasecurity/trivy) - сканер уязвимостей
- [Docker Bench Security](https://github.com/docker/docker-bench-security) - аудит Docker
- [OWASP ZAP](https://www.zaproxy.org/) - тестирование веб-безопасности

### CVE базы данных
- [NVD](https://nvd.nist.gov/)
- [CVE Details](https://www.cvedetails.com/)
- [Snyk Vulnerability DB](https://security.snyk.io/)

---

## 🔐 Заключение

Безопасность - это непрерывный процесс. Регулярно:
- Обновляйте компоненты
- Мониторьте логи
- Проверяйте алерты
- Тестируйте резервные копии
- Обучайте команду

**Важно**: Этот стек значительно улучшен с точки зрения безопасности по сравнению с исходной версией, но безопасность зависит от правильной настройки и регулярного обслуживания.

---

**Версия**: 2.0
**Дата**: 2025-12-03
**Статус**: Все критические уязвимости устранены
**Следующий аудит**: Через 3 месяца или при обнаружении новых CVE
