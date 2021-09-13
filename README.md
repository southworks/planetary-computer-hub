# Planetary Computer Hub

This repository contains the configuration and continuous deployment for the [Planetary Computer's Hub][hub], a [Dask-Gateway][gateway] enabled [JupyterHub][jupyterhub] deployment focused on supporting scalable geospatial analysis.

Environment |                           URL                            |                        Host
----------- | -------------------------------------------------------- | --------------------------------------------------
prod        | https://planetarycomputer.microsoft.com/compute/         | https://pccompute.westeurope.cloudapp.azure.com/
staging     | https://planetarycomputer-staging.microsoft.com/compute/ | https://pcc-staging.westeurope.cloudapp.azure.com/

## Overview

See the [user documentation][hub] for an overview of what all is provided.

This deployment is relatively complex, and contains a few Microsoft Planetary Computer-specific aspects. For developers or system administrators looking to deploy their own hub, consult the [deployment guide][#TODO]. This can serve as a concrete example.

There are two main components to the `planetary-commputer-hub` repository:

1. `helm`: A wrapper around the `daskhub` helm chart.
2. `terraform`: Terraform code to deploy all the necessary Azure resources and the Hub itself.

## Helm

The most interesting pieces are the YAML configuration files. These are used by the Terraform helm-release provider to customize the JupyterHub and Dask Gateway charts (see `hub.tf`). In addition to these `values_files`, the `hub.tf` passes some terraform variables through to the chart using `set` blocks.

The bulk of the configuration is done in `values.yaml`. See the inline comments there for documentation on why those values are set.

`profiles.yaml` configures `daskhub.jupyterhub.singleuser.ProfileList`. The helm-release provider does not lend itself to setting List values, and we need to get the various image tags from the terraform configuration. We place this in its own file to keep things a bit more manageable.

`jupyterhub_opencensus_monitor.yaml` sets `daskhub.jupyterhub.hub.extraFiles.jupyterhub_open_census_monitor.stringData` to be the `jupyterhub_opencensus_monitor.py` script (see below). We couldn't figure out out to get the helm-release provider working with with kubectl's `set-file` so we needed to inline the script. There's probably a better way to do this.

## Terraform

The `terraform` directory contains all the deployment code for the Hub. It's split into deployment-specific directories (`prod`, `staging`) and a `common` directory that contains the shared configuration between the two deployments.

To the extent possible, resources should be defined in `common`. `staging` and `prod` should only contain configuration (e.g. the URL for the hub, or the size of the core VM).

### acr.tf

This module creates the [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/) used for Hub images. It's deployment is a bit strange, an artifact of the deployment history and a desire
to use the same container registry for both the staging and prod deployments.

### aks.tf

This module deploys the Kubernetes cluster using [Azure Kubernetes Service][aks].

Most of the configuration is around node pools. We use the default node pool for "core" JupyterHub pods (e.g. the hub pod). We add a `user_pool` for users, and a `cpu_worker_pool` for Dask workers (using preemptible nodes).

In addition to the node pools configured here, we attach two GPU node pools. See `scripts/gpu`. We're following this [upstream issue](https://github.com/terraform-providers/terraform-provider-azurerm/issues/6793) to deploy GPU node pools through terraform.

### hub.tf

This uses the [helm_release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) provider to deploy the Hub using our Helm chart. See [below](#helm) for more.

### keyvault.tf

We manually place some secrets in [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/). These are accessed in `keyvault.tf` and used in the deployment.

### logs.tf

This deploys a Log Analytics workspace, Log Analytics solution, and application insights.

### outputs.tf


### providers.tf

This sets the versions of the Terraform [providers](https://registry.terraform.io/browse/providers) we use.

### rg.tf

Creates a Resource Group to contain all the created Azure resources.

### variables.tf

Defines the variables that can be controlled by the staging / prod deployments. See the variable descriptions for documentation on what each variable is used for.

### vnet.tf

Creates an [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) used by the Kubernetes Cluster.

## Manual Resources

We rely on a few "manual" resources that are created outside of this repository. These include

- A storage account and container for Terraform state
- A keyvault for secrets

### Keyvault secrets reference

This table documents the values we set in keyvault. They can be created with

```console
$ az keyvault secret set --vault-name pc-deploy-secrets --name '<prefix>--<key-name>' --value '<key-value>'
```
|                Keyvault Key                |                                                                          Description                                                                          |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pcc-staging--jupyterhub-proxy-secret-token | Sets `daskhub.jupyterhub.proxy.secretToken` for the staging JupyterHub                                                                                        |
| pcc-prod--jupyterhub-proxy-secret-token    | Sets `daskhub.jupyterhub.proxy.secretToken` for the prod JupyterHub                                                                                           |
| pcc--id-client-secret                      | Sets `daskhub.jupyterhub.hub.config.GenericOAuthenticator.client_secret`, an Oauth token to communicate with the pc-id oauth provider                         |
| pcc--pc-id-token                           | Sets `daskhub.jupyterhub.hub.extraEnv.PC_ID_TOKEN`, an API token with the pc-id application to look up users, enabling the API management integration         |
| pcc--azure-client-secret                   | Sets `daskhub.jupyterhub.hub.extraEnv.AZURE_CLIENT_SECRET`, an secret key to allow the hub to access Azure resources, enabling the API management integration |


## Continuous deployment

This repository deploys on commits to the staging environment on commits `main`. We commit to production on tags.

The deployment is done through Azure Pipelines / GitHub actions.

## Opencensus monitor service

The jupyterhub_opencensus_monitory.py module is deployed as a JuptyerHub service. It collects metrics on usage from the JupyterHub REST API. It would ideally be refactored into a standalone repository: <https://github.com/jupyterhub/jupyterhub/issues/3116>.

## API Management integration

The Planetary Computer API is deployed using API Management. The hub includes an integration to automatically insert the logged in user's subscription key as an environment variable. This is used by libaries like the [planetary-computer](https://github.com/microsoft/planetary-computer-sdk-for-python) to automatically sign requests.
See `daskhub.jupyterhub.hub.extraConfig.pre_spawn_hook` in `values.yaml` for where this is done.

The Hub has been granted access to API management with the following:

```
$ az role assignment create --assignee "daae755c-ba60-4d37-9114-86b21e3c0d77" \
--role "71522526-b88f-4d52-b57f-d31fc3546d0d" \
--scope "<api-management-id>"
```
## Testing

We used the JupyterHub admin panel to create a user for tests, `pangeotestbot@microsoft.com`.

```
curl -X POST -H "Authorization: token <ADMIN_TOKEN>" https://pcc-staging.westeurope.cloudapp.azure.com/compute/hub/api/users/pangeotestbot@microsoft.com/tokens
{"user": "pangeotestbot@microsoft.com", "id": "a128", "kind": "api_token", "created": "...", "last_activity": null, "expires_at": null, "note": "Requested via api by user taugspurger@microsoft.com", "token": "<BOT-TOKEN>"}
```

## Custom UI

We're able to customize the JupyterHub and jupyterlab UIs following the approach outlined in <https://discourse.jupyter.org/t/customizing-jupyterhub-on-kubernetes/1769/4>.


[gateway]: https://gateway.dask.org/
[jupyterhub]: https://jupyterhub.readthedocs.io/en/stable/
[hub]: https://planetarycomputer.microsoft.com/docs/overview/environment/
[aks]: https://docs.microsoft.com/en-us/azure/aks/
[daskhub]: https://github.com/dask/helm-chart/tree/main/daskhub

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.