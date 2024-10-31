# Ensure the script stops on error
$ErrorActionPreference = "Stop"

Write-Host "`n🗝️  Keycloak deployment started.`n"

Write-Host "📦 Installing Keycloak..."

# Generate a random client secret
$clientSecret = [System.BitConverter]::ToString((New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes((Get-Random)))).Replace("-", "").Substring(0, 20)

kubectl apply -f resources/namespace.yml

# Replace the placeholder in the config file and apply it
(Get-Content resources/keycloak-config.yml -Raw).Replace('polar-keycloak-secret', $clientSecret) | kubectl apply -f -

Write-Host "`n📦 Configuring Helm chart..."

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install polar-keycloak bitnami/keycloak `
  --values values.yml `
  --namespace keycloak-system

Write-Host "`n⌛ Waiting for Keycloak to be deployed..."

Start-Sleep -Seconds 15

while ((kubectl get pod -l app.kubernetes.io/component=keycloak -n keycloak-system | Measure-Object).Count -eq 0) {
    Start-Sleep -Seconds 15
}

Write-Host "`n⌛ Waiting for Keycloak to be ready..."

kubectl wait `
  --for='condition=ready' pod `
  --selector='app.kubernetes.io/component=keycloak' `
  --timeout='600s' `
  --namespace='keycloak-system'

Write-Host "`n✅  Keycloak cluster has been successfully deployed."

Write-Host "`n🔐 Your Keycloak Admin credentials...`n"

Write-Host "Admin Username: user"
$adminPassword = kubectl get secret --namespace keycloak-system polar-keycloak -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Admin Password: $adminPassword"

Write-Host "`n🔑 Generating Secret with Keycloak client secret."

kubectl delete secret polar-keycloak-client-credentials -ErrorAction SilentlyContinue

kubectl create secret generic polar-keycloak-client-credentials `
    --from-literal=spring.security.oauth2.client.registration.keycloak.client-secret="$clientSecret"

Write-Host "`n🍃 A 'polar-keycloak-client-credentials' has been created for Spring Boot applications to interact with Keycloak."

Write-Host "`n🗝️  Keycloak deployment completed.`n"
