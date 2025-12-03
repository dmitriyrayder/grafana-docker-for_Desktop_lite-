#!/bin/bash

# Скрипт развертывания Grafana Monitoring Stack
# Версия: 2.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Не рекомендуется запускать этот скрипт от root"
        read -p "Продолжить? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка Docker
check_docker() {
    print_info "Проверка Docker..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен. Установите Docker и повторите попытку."
        echo "Инструкции: https://docs.docker.com/engine/install/"
        exit 1
    fi

    # Проверка версии Docker
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' | cut -d. -f1)
    if [ "$DOCKER_VERSION" -lt 20 ]; then
        print_warning "Рекомендуется Docker версии 20.10 или выше"
    fi

    print_success "Docker установлен: $(docker --version)"
}

# Проверка Docker Compose
check_docker_compose() {
    print_info "Проверка Docker Compose..."
    if ! command -v docker compose &> /dev/null; then
        if ! command -v docker-compose &> /dev/null; then
            print_error "Docker Compose не установлен"
            exit 1
        fi
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi

    print_success "Docker Compose установлен: $($COMPOSE_CMD version)"
}

# Создание .env файла
setup_env() {
    print_info "Настройка переменных окружения..."

    if [ -f ".env" ]; then
        print_warning "Файл .env уже существует"
        read -p "Перезаписать? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    cp .env.example .env

    # Генерация случайного пароля
    if command -v openssl &> /dev/null; then
        RANDOM_PASSWORD=$(openssl rand -base64 32)
        sed -i "s/changeme_strong_password_here/$RANDOM_PASSWORD/" .env
        print_success "Сгенерирован случайный пароль для Grafana"
    else
        print_warning "openssl не найден. Используется пароль по умолчанию"
        print_warning "ОБЯЗАТЕЛЬНО измените пароль в файле .env!"
    fi

    print_success "Файл .env создан"
    print_warning "Проверьте и отредактируйте файл .env перед продолжением"
}

# Проверка конфигурации
validate_config() {
    print_info "Проверка конфигурации..."

    # Проверка docker-compose.yml
    if ! $COMPOSE_CMD config > /dev/null 2>&1; then
        print_error "Ошибка в docker-compose.yml"
        $COMPOSE_CMD config
        exit 1
    fi

    # Проверка конфигурации Prometheus
    if [ -f "configs/prometheus/prometheus.yml" ]; then
        docker run --rm -v "$(pwd)/configs/prometheus:/etc/prometheus" \
            prom/prometheus:v2.48.1 \
            promtool check config /etc/prometheus/prometheus.yml > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            print_success "Конфигурация Prometheus валидна"
        else
            print_error "Ошибка в конфигурации Prometheus"
            exit 1
        fi
    fi

    # Проверка правил алертинга
    if [ -f "configs/prometheus/alerts.yml" ]; then
        docker run --rm -v "$(pwd)/configs/prometheus:/etc/prometheus" \
            prom/prometheus:v2.48.1 \
            promtool check rules /etc/prometheus/alerts.yml > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            print_success "Правила алертинга валидны"
        else
            print_error "Ошибка в правилах алертинга"
            exit 1
        fi
    fi
}

# Загрузка образов
pull_images() {
    print_info "Загрузка Docker образов..."
    $COMPOSE_CMD pull
    print_success "Образы загружены"
}

# Запуск стека
start_stack() {
    print_info "Запуск Monitoring Stack..."
    $COMPOSE_CMD up -d
    print_success "Стек запущен"
}

# Проверка здоровья сервисов
check_health() {
    print_info "Проверка здоровья сервисов..."
    sleep 10

    # Grafana
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        print_success "Grafana доступна на http://localhost:3000"
    else
        print_warning "Grafana еще не готова (может потребоваться время)"
    fi

    # Prometheus
    if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
        print_success "Prometheus доступен на http://localhost:9090"
    else
        print_warning "Prometheus еще не готов"
    fi

    # Alertmanager
    if curl -sf http://localhost:9093/-/healthy > /dev/null 2>&1; then
        print_success "Alertmanager доступен на http://localhost:9093"
    else
        print_warning "Alertmanager еще не готов"
    fi

    # Loki
    if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
        print_success "Loki доступен на http://localhost:3100"
    else
        print_warning "Loki еще не готов"
    fi
}

# Вывод информации для пользователя
print_final_info() {
    echo ""
    echo "=========================================="
    print_success "Развертывание завершено!"
    echo "=========================================="
    echo ""
    echo "Доступ к сервисам:"
    echo "  Grafana:       http://localhost:3000"
    echo "  Prometheus:    http://localhost:9090"
    echo "  Alertmanager:  http://localhost:9093"
    echo ""

    if [ -f ".env" ]; then
        ADMIN_USER=$(grep GRAFANA_ADMIN_USER .env | cut -d '=' -f2)
        echo "Grafana credentials:"
        echo "  Username: ${ADMIN_USER:-admin}"
        echo "  Password: (см. в файле .env)"
        echo ""
    fi

    echo "Полезные команды:"
    echo "  Просмотр логов:    $COMPOSE_CMD logs -f"
    echo "  Статус сервисов:   $COMPOSE_CMD ps"
    echo "  Остановка:         $COMPOSE_CMD stop"
    echo "  Перезапуск:        $COMPOSE_CMD restart"
    echo ""
    echo "Документация:"
    echo "  Полное руководство: ./GUIDE.md"
    echo "  Безопасность:       ./SECURITY.md"
    echo ""
    print_warning "ВАЖНО: Измените пароль по умолчанию в файле .env!"
    print_warning "ВАЖНО: Настройте firewall для защиты сервисов!"
    echo ""
}

# Основная функция
main() {
    echo "=========================================="
    echo "  Grafana Monitoring Stack - Развертывание"
    echo "  Версия: 2.0"
    echo "=========================================="
    echo ""

    check_root
    check_docker
    check_docker_compose
    setup_env

    read -p "Продолжить развертывание? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Развертывание отменено"
        exit 0
    fi

    validate_config
    pull_images
    start_stack
    check_health
    print_final_info
}

# Запуск
main
