#!/bin/bash

# Скрипт восстановления Grafana Monitoring Stack
# Версия: 2.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Конфигурация
BACKUP_DIR="${BACKUP_DIR:-/backup/monitoring}"
PROJECT_NAME="grafana-docker-for_Desktop_lite-"

# Проверка аргументов
if [ $# -eq 0 ]; then
    print_error "Использование: $0 <backup_name>"
    echo ""
    echo "Доступные резервные копии:"
    ls -1 "$BACKUP_DIR"/monitoring_backup_*_manifest.txt 2>/dev/null | \
        sed 's/_manifest.txt//g' | \
        xargs -n1 basename
    exit 1
fi

BACKUP_NAME=$1
VOLUMES_FILE="$BACKUP_DIR/${BACKUP_NAME}_volumes.tar.gz"
CONFIGS_FILE="$BACKUP_DIR/${BACKUP_NAME}_configs.tar.gz"
CHECKSUMS_FILE="$BACKUP_DIR/${BACKUP_NAME}_checksums.sha256"

# Проверка наличия файлов
check_backup_files() {
    print_info "Проверка файлов резервной копии..."

    if [ ! -f "$VOLUMES_FILE" ]; then
        print_error "Файл не найден: $VOLUMES_FILE"
        exit 1
    fi

    if [ ! -f "$CONFIGS_FILE" ]; then
        print_error "Файл не найден: $CONFIGS_FILE"
        exit 1
    fi

    print_success "Все файлы найдены"
}

# Проверка контрольных сумм
verify_checksums() {
    if [ -f "$CHECKSUMS_FILE" ]; then
        print_info "Проверка контрольных сумм..."
        cd "$BACKUP_DIR"

        if sha256sum -c "$CHECKSUMS_FILE" > /dev/null 2>&1; then
            print_success "Контрольные суммы верны"
        else
            print_error "Контрольные суммы не совпадают!"
            read -p "Продолжить восстановление? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        cd - > /dev/null
    else
        print_warning "Файл контрольных сумм не найден"
    fi
}

# Остановка контейнеров
stop_containers() {
    print_info "Остановка контейнеров..."

    if command -v docker compose &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi

    print_success "Контейнеры остановлены"
}

# Восстановление volumes
restore_volumes() {
    print_info "Восстановление Docker volumes..."

    # Создание volumes если не существуют
    docker volume create ${PROJECT_NAME}_grafana-data
    docker volume create ${PROJECT_NAME}_prom-data
    docker volume create ${PROJECT_NAME}_loki-data
    docker volume create ${PROJECT_NAME}_alertmanager-data

    # Восстановление данных
    docker run --rm \
        -v ${PROJECT_NAME}_grafana-data:/grafana \
        -v ${PROJECT_NAME}_prom-data:/prometheus \
        -v ${PROJECT_NAME}_loki-data:/loki \
        -v ${PROJECT_NAME}_alertmanager-data:/alertmanager \
        -v "$BACKUP_DIR:/backup:ro" \
        alpine tar xzf "/backup/$(basename $VOLUMES_FILE)" -C /

    if [ $? -eq 0 ]; then
        print_success "Volumes восстановлены"
    else
        print_error "Ошибка при восстановлении volumes"
        return 1
    fi
}

# Восстановление конфигураций
restore_configs() {
    print_info "Восстановление конфигураций..."

    # Создание резервной копии текущих конфигураций
    if [ -d "configs" ]; then
        print_info "Создание резервной копии текущих конфигураций..."
        tar czf "configs_backup_$(date +%Y%m%d_%H%M%S).tar.gz" configs/ docker-compose.yml 2>/dev/null || true
    fi

    # Восстановление конфигураций
    tar xzf "$CONFIGS_FILE"

    if [ $? -eq 0 ]; then
        print_success "Конфигурации восстановлены"
    else
        print_error "Ошибка при восстановлении конфигураций"
        return 1
    fi
}

# Запуск контейнеров
start_containers() {
    print_info "Запуск контейнеров..."

    if command -v docker compose &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    print_success "Контейнеры запущены"
}

# Проверка здоровья сервисов
check_health() {
    print_info "Проверка здоровья сервисов..."
    sleep 15

    # Grafana
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        print_success "Grafana работает"
    else
        print_warning "Grafana еще не готова"
    fi

    # Prometheus
    if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
        print_success "Prometheus работает"
    else
        print_warning "Prometheus еще не готов"
    fi
}

# Вывод информации
show_restore_info() {
    echo ""
    echo "=========================================="
    print_success "Восстановление завершено!"
    echo "=========================================="
    echo ""
    echo "Сервисы:"
    echo "  Grafana:       http://localhost:3000"
    echo "  Prometheus:    http://localhost:9090"
    echo "  Alertmanager:  http://localhost:9093"
    echo ""
    echo "Проверка логов:"
    if command -v docker compose &> /dev/null; then
        echo "  docker compose logs -f"
    else
        echo "  docker-compose logs -f"
    fi
    echo ""
}

# Основная функция
main() {
    echo "=========================================="
    echo "  Grafana Monitoring Stack - Восстановление"
    echo "  Версия: 2.0"
    echo "=========================================="
    echo ""

    print_warning "Это действие перезапишет текущие данные!"
    read -p "Продолжить восстановление из $BACKUP_NAME? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Восстановление отменено"
        exit 0
    fi

    check_backup_files
    verify_checksums
    stop_containers
    restore_volumes
    restore_configs
    start_containers
    check_health
    show_restore_info
}

# Запуск
main
