## Del A – Tre lag: modules, stacks og environments

### Mappestruktur
Se git-repo

### Hvorfor tre lag, og hvorfor `stacks/` ikke er en stack
 
`modules/` inneholder én komponent hver (nettverk og compute), og de to modulene vet ikke om hverandre — `modules/network/` har ingen referanse til `modules/compute/` eller omvendt. Koblingen mellom dem ligger ett nivå opp, i `stacks/main.tf`, der `subnet_id = module.network.subnet_ids[var.vm_subnet_key]` sender nettverkets subnett-ID inn i compute-modulen.
 
`stacks/` har ingen `backend`-blokk, ingen `provider`-blokk og ingen egen `terraform.tfstate`. Den kalles av miljømappene (`module "stack" { source = "../../stacks" }`) på nøyaktig samme måte som en hvilken som helst annen modul, og jeg kjører aldri `terraform apply` inne i `stacks/`. Etter definisjonen i pensum er det derfor `environments/dev`, `environments/test` og `environments/prod` som er de faktiske **stackene** — det er disse tre mappene som har hver sin state-fil, og det er state-filer, ikke mapper, som telles når man snakker om hvor mange stacks et oppsett har.
 
Ressursgruppa opprettes i `environments/<miljø>/main.tf`, ikke i en modul — dermed får både `network`- og `compute`-modulen den utlevert gjennom `rg_name`, og ingen av de to modulene er avhengig av den andre for å få den.
 
### Navnebygging (K7)
 
Miljøet bygger ett sammensatt navnegrunnlag i `locals.base_name` ut fra `project_name`, `environment` og `owner` (`lower(format("%s-%s-%s", ...))`, f.eks. `oving3-dev-kd`), og sender dette ned til `stacks/` og videre til modulene som én variabel. Modulene kjenner selv navnereglene for sin egen ressurstype og setter på riktig prefiks: `modules/network` lager `vnet-`, `snet-` og `nsg-`, `modules/compute` lager `nic-` og `vm-`. Miljøet trenger dermed ikke vite at et subnett skal hete `snet-…` — det er kunnskap som hører hjemme i nettverksmodulen.
 
### Adressering (K2, K4)
 
`vnet_cidr` kommer inn i miljøets `terraform.tfvars` som en hel `/16`, uten default i modulen. Hvert subnett sier kun hvilken `/24` det skal ha, som et tall (`netnum`) i `subnets`-mapet (f.eks. `"frontend" = 1`), og `modules/network/main.tf` regner selve adressen ut med `cidrsubnet(var.vnet_cidr, 8, each.value)`. Ingen CIDR-adresse er skrevet inn for hånd noe sted i `modules/`.
 
---
 
## Del B – Kode
 
Koden ligger i Git-repoet

## Del C – Beviset: identiteten står i ro
 
### 1. Utrulling av dev
 
```text
khalil@Mac oving3 % cd environments/dev
terraform init
terraform validate
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
Initializing the backend...
 
Initializing modules...
- stack in ../../stacks
- stack.network in ../../modules/network
- stack.compute in ../../modules/compute
 
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "5.7.0"...
- Installing hashicorp/azurerm v5.7.0...
- Installed hashicorp/azurerm v5.7.0 (signed by HashiCorp)
 
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.
 
Terraform has been successfully initialized!
 
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.
 
If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
Success! The configuration is valid.
 
 
Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create
 
Terraform will perform the following actions:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + id       = (known after apply)
      + location = "norwayeast"
      + name     = "rg-oving3-dev-kd"
      + tags     = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
    }
 
  # module.stack.module.compute.azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username       = "azureuser"
      + computer_name        = (known after apply)
      + location             = "norwayeast"
      + name                 = "vm-oving3-dev-kd"
      + resource_group_name  = "rg-oving3-dev-kd"
      + size                 = "Standard_B2as_v2"
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
 
      + admin_ssh_key {
          + public_key = "ssh-rsa AAAA... [FJERNET FOR LEVERING] ...khalil@Mac.home"
          + username   = "azureuser"
        }
 
      + os_disk {
          + caching              = "ReadWrite"
          + storage_account_type = "Premium_LRS"
        }
 
      + source_image_reference {
          + offer     = "0001-com-ubuntu-server-focal"
          + publisher = "Canonical"
          + sku       = "20_04-lts-gen2"
          + version   = "latest"
        }
    }
 
  # module.stack.module.compute.azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + location             = "norwayeast"
      + name                 = "nic-oving3-dev-kd"
      + resource_group_name  = "rg-oving3-dev-kd"
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
 
      + ip_configuration {
          + name                           = "internal"
          + private_ip_address_allocation  = "Dynamic"
          + subnet_id                      = (known after apply)
        }
    }
 
  # module.stack.module.network.azurerm_network_security_group.main will be created
  + resource "azurerm_network_security_group" "main" {
      + location             = "norwayeast"
      + name                 = "nsg-oving3-dev-kd"
      + resource_group_name  = "rg-oving3-dev-kd"
      + security_rule        = [
          + {
              + access                  = "Allow"
              + destination_port_range  = "22"
              + direction               = "Inbound"
              + name                    = "AllowSSH"
              + priority                = 100
              + protocol                = "Tcp"
              + source_address_prefix   = "*"
              + source_port_range       = "*"
            },
          + {
              + access                  = "Allow"
              + destination_port_range  = "80"
              + direction               = "Inbound"
              + name                    = "AllowHTTP"
              + priority                = 101
              + protocol                = "Tcp"
              + source_address_prefix   = "*"
              + source_port_range       = "*"
            },
        ]
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
    }
 
  # module.stack.module.network.azurerm_subnet.main["backend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = [
          + "10.10.2.0/24",
        ]
      + name                  = "snet-oving3-dev-kd-backend"
      + resource_group_name   = "rg-oving3-dev-kd"
      + virtual_network_name  = "vnet-oving3-dev-kd"
    }
 
  # module.stack.module.network.azurerm_subnet.main["database"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = [
          + "10.10.3.0/24",
        ]
      + name                  = "snet-oving3-dev-kd-database"
      + resource_group_name   = "rg-oving3-dev-kd"
      + virtual_network_name  = "vnet-oving3-dev-kd"
    }
 
  # module.stack.module.network.azurerm_subnet.main["frontend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = [
          + "10.10.1.0/24",
        ]
      + name                  = "snet-oving3-dev-kd-frontend"
      + resource_group_name   = "rg-oving3-dev-kd"
      + virtual_network_name  = "vnet-oving3-dev-kd"
    }
 
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"] will be created
  + resource "azurerm_subnet_network_security_group_association" "main" {
      + id                         = (known after apply)
      + network_security_group_id  = (known after apply)
      + subnet_id                  = (known after apply)
    }
 
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"] will be created
  + resource "azurerm_subnet_network_security_group_association" "main" {
      + id                         = (known after apply)
      + network_security_group_id  = (known after apply)
      + subnet_id                  = (known after apply)
    }
 
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"] will be created
  + resource "azurerm_subnet_network_security_group_association" "main" {
      + id                         = (known after apply)
      + network_security_group_id  = (known after apply)
      + subnet_id                  = (known after apply)
    }
 
  # module.stack.module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space        = [
          + "10.10.0.0/16",
        ]
      + location             = "norwayeast"
      + name                 = "vnet-oving3-dev-kd"
      + resource_group_name  = "rg-oving3-dev-kd"
      + tags                 = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
    }
 
Plan: 11 to add, 0 to change, 0 to destroy.
 
Changes to Outputs:
  + subnet_ids = {
      + backend  = (known after apply)
      + database = (known after apply)
      + frontend = (known after apply)
    }
  + vm_name    = "vm-oving3-dev-kd"
 
Saved the plan to: dev.tfplan
 
azurerm_resource_group.rg: Creation complete after 26s [id=/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd]
module.stack.module.network.azurerm_virtual_network.main: Creation complete after 5s
module.stack.module.network.azurerm_network_security_group.main: Creation complete after 3s
module.stack.module.network.azurerm_subnet.main["backend"]: Creation complete after 7s
module.stack.module.network.azurerm_subnet.main["database"]: Creation complete after 13s
module.stack.module.network.azurerm_subnet.main["frontend"]: Creation complete after 17s
module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"]: Creation complete after 5s
module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"]: Creation complete after 21s
module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Creation complete after 26s
module.stack.module.compute.azurerm_network_interface.main: Creation complete after 17s
module.stack.module.compute.azurerm_linux_virtual_machine.main: Creation complete after 50s
 
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.
 
Outputs:
 
subnet_ids = {
  "backend" = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-backend"
  "database" = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-database"
  "frontend" = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-frontend"
}
vm_name = "vm-oving3-dev-kd"
```
 
### 2. Instansadressene (K3-beviset)
 
```text
khalil@Mac dev % terraform state list
azurerm_resource_group.rg
module.stack.module.compute.azurerm_linux_virtual_machine.main
module.stack.module.compute.azurerm_network_interface.main
module.stack.module.network.azurerm_network_security_group.main
module.stack.module.network.azurerm_subnet.main["backend"]
module.stack.module.network.azurerm_subnet.main["database"]
module.stack.module.network.azurerm_subnet.main["frontend"]
module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"]
module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"]
module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"]
module.stack.module.network.azurerm_virtual_network.main
```
 
Adressene inneholder navnet på subnettet (`["backend"]`, `["database"]`, `["frontend"]`), ikke en posisjon som `[0]`, `[1]`, `[2]`. Det er dette som gjør identiteten til hver instans stabil.
 
### 3. Fjern det midterste subnettet (`backend`), kun plan
 
```text
khalil@Mac dev % terraform plan
azurerm_resource_group.rg: Refreshing state... [id=/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd]
module.stack.module.network.azurerm_virtual_network.main: Refreshing state...
module.stack.module.network.azurerm_network_security_group.main: Refreshing state...
module.stack.module.network.azurerm_subnet.main["backend"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["database"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"]: Refreshing state...
module.stack.module.compute.azurerm_network_interface.main: Refreshing state...
module.stack.module.compute.azurerm_linux_virtual_machine.main: Refreshing state...
 
Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  - destroy
 
Terraform will perform the following actions:
 
  # module.stack.module.network.azurerm_subnet.main["backend"] will be destroyed
  # (because key ["backend"] is not in for_each map)
  - resource "azurerm_subnet" "main" {
      - address_prefixes      = [
          - "10.10.2.0/24",
        ] -> null
      - id                    = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-backend" -> null
      - name                  = "snet-oving3-dev-kd-backend" -> null
      - network_security_group_id = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/networkSecurityGroups/nsg-oving3-dev-kd" -> null
      - resource_group_name   = "rg-oving3-dev-kd" -> null
      - virtual_network_name  = "vnet-oving3-dev-kd" -> null
        # (unchanged attributes hidden)
    }
 
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"] will be destroyed
  # (because key ["backend"] is not in for_each map)
  - resource "azurerm_subnet_network_security_group_association" "main" {
      - id                         = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-backend" -> null
      - network_security_group_id  = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/networkSecurityGroups/nsg-oving3-dev-kd" -> null
      - subnet_id                  = "/subscriptions/[FJERNET]/resourceGroups/rg-oving3-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving3-dev-kd/subnets/snet-oving3-dev-kd-backend" -> null
    }
 
Plan: 0 to add, 0 to change, 2 to destroy.
 
Changes to Outputs:
  ~ subnet_ids = {
      - backend  = "/subscriptions/[FJERNET]/.../snet-oving3-dev-kd-backend"
        # (2 unchanged attributes hidden)
    }
 
Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to
take exactly these actions if you run "terraform apply" now.
```
 
**Resultat:** nøyaktig 2 ressurser røres (subnettet selv og NSG-koblingen til det), `frontend` og `database` nevnes ikke i det hele tatt. `terraform apply` ble **ikke** kjørt — kun `plan`, slik oppgaven ber om.
 
### 4. Flytt hele adresserommet (`vnet_cidr` endret til `10.90.0.0/16`)
 
```text
khalil@Mac dev % terraform plan
azurerm_resource_group.rg: Refreshing state...
module.stack.module.network.azurerm_virtual_network.main: Refreshing state...
module.stack.module.network.azurerm_network_security_group.main: Refreshing state...
module.stack.module.network.azurerm_subnet.main["backend"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["database"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"]: Refreshing state...
module.stack.module.compute.azurerm_network_interface.main: Refreshing state...
module.stack.module.compute.azurerm_linux_virtual_machine.main: Refreshing state...
 
Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  ~ update in-place
 
Terraform will perform the following actions:
 
  # module.stack.module.network.azurerm_subnet.main["backend"] will be updated in-place
  ~ resource "azurerm_subnet" "main" {
      ~ address_prefixes = [
          ~ "10.10.2.0/24" -> "10.90.2.0/24",
        ]
        name = "snet-oving3-dev-kd-backend"
        # (13 unchanged attributes hidden)
    }
 
  # module.stack.module.network.azurerm_subnet.main["database"] will be updated in-place
  ~ resource "azurerm_subnet" "main" {
      ~ address_prefixes = [
          ~ "10.10.3.0/24" -> "10.90.3.0/24",
        ]
        name = "snet-oving3-dev-kd-database"
        # (13 unchanged attributes hidden)
    }
 
  # module.stack.module.network.azurerm_subnet.main["frontend"] will be updated in-place
  ~ resource "azurerm_subnet" "main" {
      ~ address_prefixes = [
          ~ "10.10.1.0/24" -> "10.90.1.0/24",
        ]
        name = "snet-oving3-dev-kd-frontend"
        # (13 unchanged attributes hidden)
    }
 
  # module.stack.module.network.azurerm_virtual_network.main will be updated in-place
  ~ resource "azurerm_virtual_network" "main" {
      ~ address_space = [
          - "10.10.0.0/16",
          + "10.90.0.0/16",
        ]
        name = "vnet-oving3-dev-kd"
        # (9 unchanged attributes hidden)
    }
 
Plan: 0 to add, 4 to change, 0 to destroy.
 
Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to
take exactly these actions if you run "terraform apply" now.
```
 
**Resultat:** alle tre subnett **og** vnet-et berøres — fire ressurser i alt, ingen destroy/create, men en `update in-place` på hver eneste adresseavhengige ressurs. Samme type endring (én linje i `terraform.tfvars`) som i forsøk 3, men her rammes alt som henger på adresserommet, ikke bare én navngitt nøkkel.
 
### 5. Tilbake til `No changes` (etter at `vnet_cidr` ble satt tilbake til `10.10.0.0/16`)
 
```text
khalil@Mac dev % terraform plan
azurerm_resource_group.rg: Refreshing state...
module.stack.module.network.azurerm_virtual_network.main: Refreshing state...
module.stack.module.network.azurerm_network_security_group.main: Refreshing state...
module.stack.module.network.azurerm_subnet.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["database"]: Refreshing state...
module.stack.module.network.azurerm_subnet.main["backend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Refreshing state...
module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"]: Refreshing state...
module.stack.module.compute.azurerm_network_interface.main: Refreshing state...
module.stack.module.compute.azurerm_linux_virtual_machine.main: Refreshing state...
 
No changes. Your infrastructure matches the configuration.
 
Terraform has compared your real infrastructure against your configuration and found no
differences, so no changes are needed.
```
 
### 6. `test`-miljøet — kun init og plan, aldri apply
 
```text
khalil@Mac dev % cd ../test
terraform init
terraform plan
Initializing the backend...
 
Initializing modules...
- stack in ../../stacks
- stack.compute in ../../modules/compute
- stack.network in ../../modules/network
 
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "5.7.0"...
- Installing hashicorp/azurerm v5.7.0...
- Installed hashicorp/azurerm v5.7.0 (signed by HashiCorp)
 
Terraform has been successfully initialized!
 
Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create
 
Terraform will perform the following actions:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + location = "norwayeast"
      + name     = "rg-oving3-test-kd"
      + tags     = {
          + "environment" = "test"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
    }
 
  # module.stack.module.compute.azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username       = "azureuser"
      + location             = "norwayeast"
      + name                 = "vm-oving3-test-kd"
      + resource_group_name  = "rg-oving3-test-kd"
      + size                 = "Standard_B2as_v2"
      + tags                 = {
          + "environment" = "test"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
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
 
  # module.stack.module.compute.azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + location             = "norwayeast"
      + name                 = "nic-oving3-test-kd"
      + resource_group_name  = "rg-oving3-test-kd"
 
      + ip_configuration {
          + name                           = "internal"
          + private_ip_address_allocation  = "Dynamic"
          + subnet_id                      = (known after apply)
        }
    }
 
  # module.stack.module.network.azurerm_network_security_group.main will be created
  + resource "azurerm_network_security_group" "main" {
      + location             = "norwayeast"
      + name                 = "nsg-oving3-test-kd"
      + resource_group_name  = "rg-oving3-test-kd"
      + security_rule        = [
          + { name = "AllowSSH", priority = 100, destination_port_range = "22" },
          + { name = "AllowHTTP", priority = 101, destination_port_range = "80" },
        ]
    }
 
  # module.stack.module.network.azurerm_subnet.main["backend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.20.2.0/24"]
      + name                  = "snet-oving3-test-kd-backend"
      + resource_group_name   = "rg-oving3-test-kd"
      + virtual_network_name  = "vnet-oving3-test-kd"
    }
 
  # module.stack.module.network.azurerm_subnet.main["database"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.20.3.0/24"]
      + name                  = "snet-oving3-test-kd-database"
      + resource_group_name   = "rg-oving3-test-kd"
      + virtual_network_name  = "vnet-oving3-test-kd"
    }
 
  # module.stack.module.network.azurerm_subnet.main["frontend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.20.1.0/24"]
      + name                  = "snet-oving3-test-kd-frontend"
      + resource_group_name   = "rg-oving3-test-kd"
      + virtual_network_name  = "vnet-oving3-test-kd"
    }
 
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["backend"] will be created
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["database"] will be created
  # module.stack.module.network.azurerm_subnet_network_security_group_association.main["frontend"] will be created
 
  # module.stack.module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space        = ["10.20.0.0/16"]
      + location             = "norwayeast"
      + name                 = "vnet-oving3-test-kd"
      + resource_group_name  = "rg-oving3-test-kd"
      + tags                 = {
          + "environment" = "test"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving3"
        }
    }
 
Plan: 11 to add, 0 to change, 0 to destroy.
 
Changes to Outputs:
  + subnet_ids = {
      + backend  = (known after apply)
      + database = (known after apply)
      + frontend = (known after apply)
    }
  + vm_name    = "vm-oving3-test-kd"
 
Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to
take exactly these actions if you run "terraform apply" now.
```
 
`test`-miljøet ble **kun** initialisert og planlagt — ingen `apply`. Planen viser 11 ressurser med `test` i navn og tags, og et eget adresserom (`10.20.0.0/16`), uten at en eneste linje i `stacks/` eller `modules/` ble endret for å få dette til.
 
### 7. K1-beviset
 
```text
khalil@Mac test % cd ../..
diff environments/dev/main.tf environments/prod/main.tf
diff environments/dev/main.tf environments/test/main.tf
khalil@Mac oving3 %
```
 
Begge `diff`-kommandoene ga tom utskrift — `main.tf` er bokstavelig talt identisk i alle tre miljøene. Alt som skiller `dev`, `test` og `prod` ligger i hver sin `terraform.tfvars`.
 
---
 
## Opprydding
 
`terraform destroy` kjøres i `environments/dev`