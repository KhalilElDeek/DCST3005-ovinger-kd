# Øving 2 - Output md

## Del A - Mappestruktur

Hver miljømappe er sin egen root module med sine egne terraform filer. 
Vi kjører init, plan og apply i hver miljømappe. Se strukturen i Git

## Del C - To miljøer

### 1. Samme kode - Output fra terminalen

```text
khalil@Mac oving2 % diff environments/dev/main.tf environments/prod/main.tf

khalil@Mac oving2 %
```

Tom utskrift bekrefter K6: `main.tf` er identisk i `dev` og `prod`. All forskjell mellom miljøene ligger i `terraform.tfvars`.

### 2. Ulik infrastruktur

**dev – init, validate, plan, apply:**

```text
khalil@Mac oving2 % cd environments/dev
terraform init
terraform validate
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
Initializing the backend...

Initializing modules...
- network in ../../modules/network
- compute in ../../modules/compute

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "5.7.0"...
- Installing hashicorp/azurerm v5.7.0...
- Installed hashicorp/azurerm v5.7.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

Success! The configuration is valid.

Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "norwayeast"
      + name     = "rg-oving2-dev-kd"
      + tags     = {
          + "environment" = "dev"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }
    }

  # module.compute.azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username                   = "azureuser"
      + computer_name                    = (known after apply)
      + disable_password_authentication  = (known after apply)
      + location                         = "norwayeast"
      + name                             = "vm-oving2-dev-kd"
      + resource_group_name              = "rg-oving2-dev-kd"
      + size                             = "Standard_B2as_v2"
      + tags                             = {
          + "environment" = "dev"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }

      + admin_ssh_key {
          + public_key = "ssh-rsa AAAA... [FJERNET FOR LEVERING] ...khalil@Mac.home"
          + username   = "azureuser"
        }

      + os_disk {
          + caching                   = "ReadWrite"
          + storage_account_type      = "Premium_LRS"
        }

      + source_image_reference {
          + offer     = "0001-com-ubuntu-server-focal"
          + publisher = "Canonical"
          + sku       = "20_04-lts-gen2"
          + version   = "latest"
        }
    }

  # module.compute.azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + location             = "norwayeast"
      + name                 = "nic-oving2-dev-kd"
      + resource_group_name  = "rg-oving2-dev-kd"
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }

      + ip_configuration {
          + name                           = "testconfiguration1"
          + private_ip_address_allocation  = "Dynamic"
          + subnet_id                      = (known after apply)
        }
    }

  # module.network.azurerm_subnet.main will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = [
          + "10.10.1.0/24",
        ]
      + name                  = "subnet-oving2-dev-kd"
      + resource_group_name   = "rg-oving2-dev-kd"
      + virtual_network_name  = "vnet-oving2-dev-kd"
    }

  # module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space        = [
          + "10.10.0.0/16",
        ]
      + location             = "norwayeast"
      + name                 = "vnet-oving2-dev-kd"
      + resource_group_name  = "rg-oving2-dev-kd"
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }
    }

Plan: 5 to add, 0 to change, 0 to destroy.

Saved the plan to: dev.tfplan

azurerm_resource_group.main: Creation complete after 25s [id=/subscriptions/[FJERNET]/resourceGroups/rg-oving2-dev-kd]
module.network.azurerm_virtual_network.main: Creation complete after 6s
module.network.azurerm_subnet.main: Creation complete after 6s
module.compute.azurerm_network_interface.main: Creation complete after 12s
module.compute.azurerm_linux_virtual_machine.main: Creation complete after 50s

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

**prod – init, validate, plan, apply:**

```text
khalil@Mac dev % cd ../prod
terraform init
terraform validate
terraform plan -out=prod.tfplan
terraform apply prod.tfplan
Initializing the backend...

Initializing modules...
- compute in ../../modules/compute
- network in ../../modules/network

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "5.7.0"...
- Installing hashicorp/azurerm v5.7.0...
- Installed hashicorp/azurerm v5.7.0 (signed by HashiCorp)

Terraform has been successfully initialized!

Success! The configuration is valid.

Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + location = "norwayeast"
      + name     = "rg-oving2-prod-kd"
      + tags     = {
          + "environment" = "prod"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }
    }

  # module.compute.azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username       = "azureuser"
      + location             = "norwayeast"
      + name                 = "vm-oving2-prod-kd"
      + resource_group_name  = "rg-oving2-prod-kd"
      + size                 = "Standard_D2s_v5"
      + tags                 = {
          + "environment" = "prod"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }

      + admin_ssh_key {
          + public_key = "ssh-rsa AAAA... [FJERNET FOR LEVERING] ...khalil@Mac.home"
          + username   = "azureuser"
        }

      + source_image_reference {
          + offer     = "0001-com-ubuntu-server-focal"
          + publisher = "Canonical"
          + sku       = "20_04-lts-gen2"
          + version   = "latest"
        }
    }

  # module.compute.azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + location             = "norwayeast"
      + name                 = "nic-oving2-prod-kd"
      + resource_group_name  = "rg-oving2-prod-kd"
      + tags                 = {
          + "environment" = "prod"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }
    }

  # module.network.azurerm_subnet.main will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = [
          + "10.30.1.0/24",
        ]
      + name                  = "subnet-oving2-prod-kd"
      + resource_group_name   = "rg-oving2-prod-kd"
      + virtual_network_name  = "vnet-oving2-prod-kd"
    }

  # module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space        = [
          + "10.30.0.0/16",
        ]
      + location             = "norwayeast"
      + name                 = "vnet-oving2-prod-kd"
      + resource_group_name  = "rg-oving2-prod-kd"
      + tags                 = {
          + "environment" = "prod"
          + "managedby"   = "Terraform"
          + "owner"       = "kd"
          + "project"     = "oving2"
        }
    }

Plan: 5 to add, 0 to change, 0 to destroy.

Saved the plan to: prod.tfplan

azurerm_resource_group.main: Creation complete after 23s [id=/subscriptions/[FJERNET]/resourceGroups/rg-oving2-prod-kd]
module.network.azurerm_virtual_network.main: Creation complete after 5s
module.network.azurerm_subnet.main: Creation complete after 5s
module.compute.azurerm_network_interface.main: Creation complete after 11s
module.compute.azurerm_linux_virtual_machine.main: Creation complete after 49s

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

**Observert resultat:**

| | dev | prod |
|---|---|---|
| Ressursgruppe | `rg-oving2-dev-kd` | `rg-oving2-prod-kd` |
| VM-navn | `vm-oving2-dev-kd` | `vm-oving2-prod-kd` |
| VM-størrelse | `Standard_B2as_v2` | `Standard_D2s_v5` |
| Adresserom | `10.10.0.0/16` | `10.30.0.0/16` |
| Subnet | `10.10.1.0/24` | `10.30.1.0/24` |
| Tag `environment` | `dev` | `prod` |

Fem ressurser i hvert miljø: ressursgruppe, vnet, subnet, nettverkskort, VM. Navn og størrelse er de eneste forskjellene — akkurat det `terraform.tfvars` skulle styre.

### 3. Samme adresser – to state-filer

Begge miljøene bruker adressen `module.compute.azurerm_linux_virtual_machine.main` i sin egen state, men peker på to forskjellige maskiner i Azure. Det fungerer fordi `environments/dev/` og `environments/prod/` har hver sin lokale `terraform.tfstate`-fil — adressene kolliderer ikke fordi de aldri sammenlignes mot hverandre.

---

## Del D – Refleksjon i Google Docs 

---

## Opprydding

```text
khalil@Mac oving2 % cd environments/dev && terraform destroy
...
Destroy complete! Resources: 5 destroyed.

cd ../prod && terraform destroy
...
Destroy complete! Resources: 5 destroyed.

az group list --query "[?contains(name,'oving2')].name" -o tsv
khalil@Mac prod %
```

`terraform destroy` kjørt i både `dev` og `prod`. `az group list`-sjekken ga tom utskrift — ingen `oving2`-ressursgrupper igjen i abonnementet.