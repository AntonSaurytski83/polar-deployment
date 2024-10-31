# Ensure the script stops on error
$ErrorActionPreference = "Stop"

Write-Host "`n🐰 RabbitMQ deployment started."

Write-Host "`n📦 Installing RabbitMQ Cluster Kubernetes Operator..."
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/download/v1.14.0/cluster-operator.yml"

Write-Host "`n⌛ Waiting for RabbitMQ Operator to be deployed..."
while ((kubectl get pod -l app.kubernetes.io/name=rabbitmq-cluster-operator -n rabbitmq-system | Measure-Object).Count -eq 0) {
    Start-Sleep -Seconds 15
}

Write-Host "`n⌛ Waiting for RabbitMQ Operator to be ready..."
kubectl wait `
  --for='condition=ready' pod `
  --selector='app.kubernetes.io/name=rabbitmq-cluster-operator' `
  --timeout='300s' `
  --namespace='rabbitmq-system'

Write-Host "`n✅ The RabbitMQ Cluster Kubernetes Operator has been successfully installed."

Write-Host "`n-----------------------------------------------------"

Write-Host "`n📦 Deploying RabbitMQ cluster..."
kubectl apply -f resources/cluster.yml

Write-Host "`n⌛ Waiting for RabbitMQ cluster to be deployed..."
while ((kubectl get pod -l app.kubernetes.io/name=polar-rabbitmq -n rabbitmq-system | Measure-Object).Count -eq 0) {
    Start-Sleep -Seconds 15
}

Write-Host "`n⌛ Waiting for RabbitMQ cluster to be ready..."
kubectl wait `
  --for='condition=ready' pod `
  --selector='app.kubernetes.io/name=polar-rabbitmq' `
  --timeout='600s' `
  --namespace='rabbitmq-system'

Write-Host "`n✅ The RabbitMQ cluster has been successfully deployed."

Write-Host "`n-----------------------------------------------------"

$RABBITMQ_USERNAME = kubectl get secret polar-rabbitmq-default-user -o jsonpath='{.data.username}' -n=rabbitmq-system | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$RABBITMQ_PASSWORD = kubectl get secret polar-rabbitmq-default-user -o jsonpath='{.data.password}' -n=rabbitmq-system | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "Username: $RABBITMQ_USERNAME"
Write-Host "Password: $RABBITMQ_PASSWORD"

Write-Host "`n🔑 Generating Secret with RabbitMQ credentials."

kubectl delete secret polar-rabbitmq-credentials -ErrorAction SilentlyContinue

kubectl create secret generic polar-rabbitmq-credentials `
    --from-literal=spring.rabbitmq.host='polar-rabbitmq.rabbitmq-system.svc.cluster.local' `
    --from-literal=spring.rabbitmq.port='5672' `
    --from-literal=spring.rabbitmq.username="$RABBITMQ_USERNAME" `
    --from-literal=spring.rabbitmq.password="$RABBITMQ_PASSWORD"

Remove-Variable RABBITMQ_USERNAME
Remove-Variable RABBITMQ_PASSWORD

Write-Host "`n🍃 Secret 'polar-rabbitmq-credentials' has been created for Spring Boot applications to interact with RabbitMQ."

Write-Host "`n🐰 RabbitMQ deployment completed.`n"
