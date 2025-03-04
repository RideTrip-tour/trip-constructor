#!/bin/bash

# Путь к папке с манифестами
K8S_MANIFESTS_DIR="./k8s"

# Функция для применения манифестов
apply_manifests() {
    local dir=$1
    echo "Applying manifests in $dir..."
    for file in $(find $dir -name '*.yaml' -o -name '*.yml'); do
        kubectl apply -f $file
        if [ $? -ne 0 ]; then
            echo "Error applying $file"
            exit 1
        fi
    done
}

# Применяем манифесты для каждого микросервиса
apply_manifests "$K8S_MANIFESTS_DIR/auth"
apply_manifests "$K8S_MANIFESTS_DIR/plans"
apply_manifests "$K8S_MANIFESTS_DIR/locations"

# Применяем ingress
apply_manifests "$K8S_MANIFESTS_DIR"

echo "All resources deployed successfully!"