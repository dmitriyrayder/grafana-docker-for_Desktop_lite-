#!/bin/bash

# Скрипт резервного копирования Grafana Monitoring Stack
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
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring_backup_$DATE"
PROJECT_NAME="grafana-docker-for_Desktop_lite-"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Создание директории для резервных копий
create_backup_dir() {
    print_info "Создание директории для резервных копий..."
    mkdir -p "$BACKUP_DIR"
    print_success "Директория создана: $BACKUP_DIR"
}

# Резервное копирование Docker volumes
backup_volumes() {
    print_info "Резервное копирование Docker volumes..."

    docker run --rm \
        -v ${PROJECT_NAME}_grafana-data:/grafana:ro \
        -v ${PROJECT_NAME}_prom-data:/prometheus:ro \
        -v ${PROJECT_NAME}_loki-data:/loki:ro \
        -v ${PROJECT_NAME}_alertmanager-data:/alertmanager:ro \
        -v "$BACKUP_DIR:/backup" \
        alpine tar czf "/backup/${BACKUP_NAME}_volumes.tar.gz" \
        /grafana /prometheus /loki /alertmanager

    if [ $? -eq 0 ]; then
        print_success "Volumes скопированы: ${BACKUP_NAME}_volumes.tar.gz"
    else
        print_error "Ошибка при копировании volumes"
        return 1
    fi
}

# Резервное копирование конфигураций
backup_configs() {
    print_info "Резервное копирование конфигураций..."

    tar czf "$BACKUP_DIR/${BACKUP_NAME}_configs.tar.gz" \
        configs/ \
        docker-compose.yml \
        .env 2>/dev/null || \
    tar czf "$BACKUP_DIR/${BACKUP_NAME}_configs.tar.gz" \
        configs/ \
        docker-compose.yml

    if [ $? -eq 0 ]; then
        print_success "Конфигурации скопированы: ${BACKUP_NAME}_configs.tar.gz"
    else
        print_error "Ошибка при копировании конфигураций"
        return 1
    fi
}

# Создание манифеста резервной копии
create_manifest() {
    print_info "Создание манифеста резервной копии..."

    cat > "$BACKUP_DIR/${BACKUP_NAME}_manifest.txt" << EOF
Резервная копия Grafana Monitoring Stack
=========================================

Дата создания: $(date)
Hostname: $(hostname)
Версия: 2.0

Файлы:
  - ${BACKUP_NAME}_volumes.tar.gz
  - ${BACKUP_NAME}_configs.tar.gz

Docker образы:
$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "grafana|prometheus|loki|alertmanager|node-exporter|cadvisor|promtail|blackbox")

Docker volumes:
$(docker volume ls --format "{{.Name}}" | grep "${PROJECT_NAME}")

Размеры файлов:
$(ls -lh "$BACKUP_DIR"/${BACKUP_NAME}* | awk '{print $9, $5}')

EOF

    print_success "Манифест создан: ${BACKUP_NAME}_manifest.txt"
}

# Удаление старых резервных копий
cleanup_old_backups() {
    print_info "Удаление резервных копий старше $RETENTION_DAYS дней..."

    find "$BACKUP_DIR" -name "monitoring_backup_*" -type f -mtime +$RETENTION_DAYS -delete

    DELETED_COUNT=$(find "$BACKUP_DIR" -name "monitoring_backup_*" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)

    if [ $DELETED_COUNT -gt 0 ]; then
        print_success "Удалено $DELETED_COUNT старых резервных копий"
    else
        print_info "Старых резервных копий не найдено"
    fi
}

# Вычисление контрольных сумм
calculate_checksums() {
    print_info "Вычисление контрольных сумм..."

    cd "$BACKUP_DIR"
    sha256sum ${BACKUP_NAME}*.tar.gz > "${BACKUP_NAME}_checksums.sha256"

    print_success "Контрольные суммы сохранены: ${BACKUP_NAME}_checksums.sha256"
}

# Статистика резервной копии
show_backup_stats() {
    echo ""
    echo "=========================================="
    print_success "Резервное копирование завершено!"
    echo "=========================================="
    echo ""
    echo "Файлы резервной копии:"
    ls -lh "$BACKUP_DIR"/${BACKUP_NAME}* | awk '{printf "  %s (%s)\n", $9, $5}'
    echo ""

    TOTAL_SIZE=$(du -sh "$BACKUP_DIR/${BACKUP_NAME}"* | awk '{sum+=$1} END {print sum}')
    echo "Общий размер: $(du -sh "$BACKUP_DIR" | awk '{print $1}')"
    echo "Расположение: $BACKUP_DIR"
    echo ""

    print_info "Для восстановления используйте: ./restore.sh ${BACKUP_NAME}"
}

# Опциональное шифрование
encrypt_backup() {
    if [ -n "$ENCRYPTION_KEY" ]; then
        print_info "Шифрование резервной копии..."

        if command -v gpg &> /dev/null; then
            for file in "$BACKUP_DIR"/${BACKUP_NAME}*.tar.gz; do
                gpg --encrypt --recipient "$ENCRYPTION_KEY" "$file"
                if [ $? -eq 0 ]; then
                    rm "$file"
                    print_success "Зашифрован: $(basename $file).gpg"
                fi
            done
        else
            print_warning "GPG не установлен, шифрование пропущено"
        fi
    fi
}

# Основная функция
main() {
    echo "=========================================="
    echo "  Grafana Monitoring Stack - Резервное копирование"
    echo "  Версия: 2.0"
    echo "=========================================="
    echo ""

    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        exit 1
    fi

    create_backup_dir
    backup_volumes
    backup_configs
    create_manifest
    calculate_checksums
    encrypt_backup
    cleanup_old_backups
    show_backup_stats
}

# Запуск
main
