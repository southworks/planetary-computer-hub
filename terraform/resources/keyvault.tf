data "azurerm_key_vault" "deploy_secrets" {
  name                = var.pc_resources_kv
  resource_group_name = var.pc_resources_rg
}

# JupyterHub
data "azurerm_key_vault_secret" "jupyterhub_proxy_secret_token" {
  name         = "${local.namespaced_prefix}--jupyterhub-proxy-secret-token"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

# Django App

data "azurerm_key_vault_secret" "id_client_secret" {
  name         = "${local.stack_id}--id-client-secret"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

data "azurerm_key_vault_secret" "pc_id_token" {
  name         = "${local.stack_id}--pc-id-token"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

# API Management integration
data "azurerm_key_vault_secret" "azure_client_secret" {
  name         = "${local.stack_id}--azure-client-secret"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

# kbatch integration
data "azurerm_key_vault_secret" "kbatch_server_api_token" {
  name         = "${local.namespaced_prefix}--kbatch-server-api-token"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

# Velero integration

data "azurerm_key_vault_secret" "velero_azure_subscription_id" {
  name         = "${local.stack_id}--velero-azure-subscription-id"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}


data "azurerm_key_vault_secret" "velero_azure_tenant_id" {
  name         = "${local.stack_id}--velero-azure-tenant-id"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}


data "azurerm_key_vault_secret" "velero_azure_client_id" {
  name         = "${local.stack_id}--velero-azure-client-id"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}


data "azurerm_key_vault_secret" "velero_azure_client_secret" {
  name         = "${local.stack_id}--velero-azure-client-secret"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}

data "azurerm_key_vault_secret" "microsoft_defender_log_analytics_workspace_id" {
  name         = "${local.stack_id}--microsoft-defender-log-analytics-workspace-id"
  key_vault_id = data.azurerm_key_vault.deploy_secrets.id
}