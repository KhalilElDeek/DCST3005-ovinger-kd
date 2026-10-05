## Del A – Backend-bootstrap og partial backend config
 
### Mappestruktur
Se Git-repo

### Hvorfor `backend-bootstrap` har lokal state (K1)
 
`backend-bootstrap` oppretter stedet alle de andre stackene lagrer state i — en ressursgruppe, et storage account og en container. Den kan ikke lagre sin egen state i en container som ikke finnes ennå, så den beholder `local`-backend-en. Dette er akseptabelt nettopp for denne ene stacken fordi den er liten: mister jeg state her, importerer jeg fire–fem ressurser tilbake med `terraform import` på et kvarter. Mister jeg state for et miljø med ni–tolv ressurser, har jeg mistet oversikten over alt som faktisk står der.
 
### Herding av storage-kontoen (K2–K4)
 
- `shared_access_key_enabled = false` — kontonøkler finnes ikke å hente, så backend-en må bruke `use_azuread_auth = true` i stedet for key-basert tilgang.
- `blob_properties` med `versioning_enabled = true` og `delete_retention_policy` — satt i kode, ikke klikket inn i portalen.
- Containeren er privat (`container_access_type = "private"`), og tilgangen gis med `Storage Blob Data Contributor` — en dataplan-rolle, ikke bare kontrollplan — til `data.azurerm_client_config.current.object_id`, slik at koden virker for hvem som helst som kjører den, uten en innlimt ID.
### Partial backend configuration (K3, K6)
 
Hver stack har en tom blokk:
```hcl
terraform {
  backend "azurerm" {}
}
```
Den faktiske adressen (ressursgruppe, storage account, container) bor i `shared/backend.hcl`, og hentes inn med `-backend-config` ved `init`. `key` er den ene verdien som skiller instansene, og den står **kun** i init-kommandoen — aldri i koden.
 
### To stacks med hver sin key (K7, K9)
 
| Stack | Rolle | key |
|---|---|---|
| `environments/dev/network/` | Provider – lager subnettene | `dev/network.tfstate` |
| `environments/dev/app/` | Consumer – trenger ett av dem | `dev/app.tfstate` |
| `environments/prod/network/` | Samme kode, annet miljø | `prod/network.tfstate` |
| `environments/prod/app/` | Samme kode, annet miljø | `prod/app.tfstate` |
 
`app`-stacken henter subnett-ID-en med `terraform_remote_state` i stedet for å få den sendt inn (K8):
```hcl
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name   = var.backend_resource_group_name
    storage_account_name  = var.backend_storage_account_name
    container_name        = var.backend_container_name
    key                   = var.network_state_key
    use_azuread_auth      = true
  }
}
 
locals {
  subnet_id = data.terraform_remote_state.network.outputs.subnet_ids[var.vm_subnet_key]
}
```
 
---
 
## Del B – Kode
 
Koden ligger i Git-repoet (lenke i innleveringen): `backend-bootstrap/`, `shared/backend.hcl`, `modules/network/`, `modules/compute/`, og alle fire stack-instansene under `environments/`.
 
---
 
## Del C – Beviset
 
### 1. Utrulling av dev/network
 
```text
khalil@Mac oving4 % cd environments/dev/network
 
khalil@Mac network % terraform init \
  -backend-config="../../../shared/backend.hcl" \
  -backend-config="key=dev/network.tfstate" \
  -reconfigure
Initializing the backend...
 
Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.
 
Initializing modules...
 
Initializing provider plugins...
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v5.7.0
 
Terraform has been successfully initialized!
 
khalil@Mac network % terraform validate
 
Success! The configuration is valid.
 
khalil@Mac network % terraform plan -out=network.tfplan
 
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 
Terraform will perform the following actions:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + location = "norwayeast"
      + name     = "rg-nett-oving4-dev-kd"
      + tags     = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving4"
          + "stack"       = "network"
        }
    }
 
  # module.network.azurerm_network_security_group.main will be created
  + resource "azurerm_network_security_group" "main" {
      + location            = "norwayeast"
      + name                = "nsg-oving4-dev-kd"
      + resource_group_name = "rg-nett-oving4-dev-kd"
      + security_rule       = [
          + { name = "AllowSSH", priority = 100, destination_port_range = "22" },
          + { name = "AllowHTTP", priority = 101, destination_port_range = "80" },
        ]
    }
 
  # module.network.azurerm_subnet.main["backend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.10.2.0/24"]
      + name                  = "snet-oving4-dev-kd-backend"
      + resource_group_name   = "rg-nett-oving4-dev-kd"
      + virtual_network_name  = "vnet-oving4-dev-kd"
    }
 
  # module.network.azurerm_subnet.main["database"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.10.3.0/24"]
      + name                  = "snet-oving4-dev-kd-database"
      + resource_group_name   = "rg-nett-oving4-dev-kd"
      + virtual_network_name  = "vnet-oving4-dev-kd"
    }
 
  # module.network.azurerm_subnet.main["frontend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes      = ["10.10.1.0/24"]
      + name                  = "snet-oving4-dev-kd-frontend"
      + resource_group_name   = "rg-nett-oving4-dev-kd"
      + virtual_network_name  = "vnet-oving4-dev-kd"
    }
 
  # module.network.azurerm_subnet_network_security_group_association.main["backend"] will be created
  # module.network.azurerm_subnet_network_security_group_association.main["database"] will be created
  # module.network.azurerm_subnet_network_security_group_association.main["frontend"] will be created
 
  # module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space        = ["10.10.0.0/16"]
      + location             = "norwayeast"
      + name                 = "vnet-oving4-dev-kd"
      + resource_group_name  = "rg-nett-oving4-dev-kd"
    }
 
Plan: 9 to add, 0 to change, 0 to destroy.
 
Changes to Outputs:
  + subnet_ids = {
      + backend  = (known after apply)
      + database = (known after apply)
      + frontend = (known after apply)
    }
  + vnet_id    = (known after apply)
 
Saved the plan to: network.tfplan
 
khalil@Mac network % terraform apply network.tfplan
azurerm_resource_group.rg: Creating...
azurerm_resource_group.rg: Creation complete after 24s [id=/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd]
module.network.azurerm_virtual_network.main: Creating...
module.network.azurerm_network_security_group.main: Creating...
module.network.azurerm_network_security_group.main: Creation complete after 3s
module.network.azurerm_virtual_network.main: Creation complete after 6s
module.network.azurerm_subnet.main["frontend"]: Creating...
module.network.azurerm_subnet.main["database"]: Creating...
module.network.azurerm_subnet.main["backend"]: Creating...
module.network.azurerm_subnet.main["frontend"]: Creation complete after 4s
module.network.azurerm_subnet.main["backend"]: Creation complete after 9s
module.network.azurerm_subnet.main["database"]: Creation complete after 14s
module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Creating...
module.network.azurerm_subnet_network_security_group_association.main["database"]: Creating...
module.network.azurerm_subnet_network_security_group_association.main["backend"]: Creating...
module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Creation complete after 5s
module.network.azurerm_subnet_network_security_group_association.main["database"]: Creation complete after 10s
module.network.azurerm_subnet_network_security_group_association.main["backend"]: Creation complete after 15s
Releasing state lock. This may take a few moments...
 
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
 
Outputs:
 
subnet_ids = {
  "backend" = "/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving4-dev-kd/subnets/snet-oving4-dev-kd-backend"
  "database" = "/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving4-dev-kd/subnets/snet-oving4-dev-kd-database"
  "frontend" = "/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving4-dev-kd/subnets/snet-oving4-dev-kd-frontend"
}
vnet_id = "/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving4-dev-kd"
```
 
### 2. K5/K7-beviset: instansadressene og outputs som map
 
```text
khalil@Mac network % terraform state list
azurerm_resource_group.rg
module.network.azurerm_network_security_group.main
module.network.azurerm_subnet.main["backend"]
module.network.azurerm_subnet.main["database"]
module.network.azurerm_subnet.main["frontend"]
module.network.azurerm_subnet_network_security_group_association.main["backend"]
module.network.azurerm_subnet_network_security_group_association.main["database"]
module.network.azurerm_subnet_network_security_group_association.main["frontend"]
module.network.azurerm_virtual_network.main
 
khalil@Mac network % terraform output
subnet_ids = {
  "backend" = "/subscriptions/[FJERNET]/.../snet-oving4-dev-kd-backend"
  "database" = "/subscriptions/[FJERNET]/.../snet-oving4-dev-kd-database"
  "frontend" = "/subscriptions/[FJERNET]/.../snet-oving4-dev-kd-frontend"
}
vnet_id = "/subscriptions/[FJERNET]/.../vnet-oving4-dev-kd"
```
 
Adressene har navn i klammeparentesen, ikke posisjon, og `subnet_ids` kommer ut som et map — nøyaktig det videreføringen fra modul 3 krever.
 
### 3. Utrulling av dev/app — koblingen mellom stackene (K8, K9)
 
```text
khalil@Mac network % cd ../app
 
khalil@Mac app % terraform init \
  -backend-config="../../../shared/backend.hcl" \
  -backend-config="key=dev/app.tfstate" \
  -reconfigure
Initializing the backend...
 
Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.
 
Initializing provider plugins...
- terraform.io/builtin/terraform is built in to Terraform
- Reusing previous version of hashicorp/azurerm from the dependency lock file
 
Terraform has been successfully initialized!
 
khalil@Mac app % terraform validate
 
Success! The configuration is valid.
 
khalil@Mac app % terraform plan -out=app.tfplan
 
data.terraform_remote_state.network: Reading...
data.terraform_remote_state.network: Read complete after 0s
 
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 
Terraform will perform the following actions:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + location = "norwayeast"
      + name     = "rg-app-oving4-dev-kd"
      + tags     = {
          + "environment" = "dev"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving4"
          + "stack"       = "app"
        }
    }
 
  # module.compute.azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username       = "azureuser"
      + location             = "norwayeast"
      + name                 = "vm-oving4-dev-kd"
      + resource_group_name  = "rg-app-oving4-dev-kd"
      + size                 = "Standard_B2as_v2"
 
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
      + name                 = "nic-oving4-dev-kd"
      + resource_group_name  = "rg-app-oving4-dev-kd"
 
      + ip_configuration {
          + name                            = "internal"
          + private_ip_address_allocation   = "Dynamic"
          + subnet_id                       = "/subscriptions/[FJERNET]/resourceGroups/rg-nett-oving4-dev-kd/providers/Microsoft.Network/virtualNetworks/vnet-oving4-dev-kd/subnets/snet-oving4-dev-kd-frontend"
        }
    }
 
Plan: 3 to add, 0 to change, 0 to destroy.
 
Changes to Outputs:
  + brukt_subnet_id = "/subscriptions/[FJERNET]/.../snet-oving4-dev-kd-frontend"
  + private_ip      = (known after apply)
  + vm_name         = "vm-oving4-dev-kd"
 
Saved the plan to: app.tfplan
 
khalil@Mac app % terraform apply app.tfplan
azurerm_resource_group.rg: Creating...
azurerm_resource_group.rg: Creation complete after 24s [id=/subscriptions/[FJERNET]/resourceGroups/rg-app-oving4-dev-kd]
module.compute.azurerm_network_interface.main: Creating...
module.compute.azurerm_network_interface.main: Creation complete after 11s
module.compute.azurerm_linux_virtual_machine.main: Creating...
module.compute.azurerm_linux_virtual_machine.main: Creation complete after 14s
Releasing state lock. This may take a few moments...
 
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
 
Outputs:
 
brukt_subnet_id = "/subscriptions/[FJERNET]/.../snet-oving4-dev-kd-frontend"
private_ip = "10.10.1.4"
vm_name = "vm-oving4-dev-kd"
```
 
Linja `data.terraform_remote_state.network: Reading...` / `Read complete after 0s` øverst i plan-utskriften er selve beviset: Terraform kobler seg til nettverks-stackens state i Azure og leser `subnet_ids` derfra, uten at jeg har skrevet inn noen subnett-ID for hånd. `subnet_id` i `ip_configuration` peker nøyaktig på `snet-oving4-dev-kd-frontend`-ID-en fra `network`-stacken.
 
### 4. K6-beviset: ingen storage account-navn i koden
 
```text
khalil@Mac oving4 % grep -rn "storage_account_name" environments/
environments/prod/app/main.tf:22:    storage_account_name = var.backend_storage_account_name
environments/prod/app/terraform.tfvars:11:backend_storage_account_name = "sttfkd[FJERNET]"
environments/prod/app/variables.tf:40:variable "backend_storage_account_name" {
environments/dev/app/main.tf:22:    storage_account_name = var.backend_storage_account_name
environments/dev/app/terraform.tfvars:11:backend_storage_account_name = "sttfkd[FJERNET]"
environments/dev/app/variables.tf:40:variable "backend_storage_account_name" {
```
 
Treffene i `.tf`-filene er kun på variabelnavnet (`var.backend_storage_account_name`), aldri den faktiske strengen. Den ekte verdien står kun i `terraform.tfvars`.
 
### 5. K7-beviset: hver stack har sin egen key
 
```text
khalil@Mac oving4 % az storage blob list \
  --account-name sttfkd[FJERNET] \
  --container-name tfstate \
  --auth-mode login \
  --output table
Name                  Blob Type    Blob Tier    Length    Content Type      Last Modified
--------------------  -----------  -----------  --------  ----------------  -------------------------
dev/app.tfstate       BlockBlob    Hot          13363     application/json  2026-10-05T22:31:50+00:00
dev/network.tfstate   BlockBlob    Hot          17726     application/json  2026-10-05T22:29:31+00:00
prod/network.tfstate  BlockBlob    Hot          324       application/json  2026-10-05T22:34:50+00:00
```
 
Tre filer, hver med miljønavnet i `key`. `prod/network.tfstate` er liten (324 bytes) fordi den kun inneholder backend-metadata — `prod` er bevisst kun planlagt, aldri apply'et.
 
### 6. K8-beviset: ingen ressurs-ID skrevet for hånd
 
```text
khalil@Mac oving4 % grep -rn "/subscriptions/" environments/dev/app/*.tf
khalil@Mac oving4 %
```
 
Tomt resultat — `subnet_id` kommer utelukkende fra `data.terraform_remote_state`, aldri fra en hardkodet streng.
 
### 7. prod — kun init og plan, aldri apply
 
```text
khalil@Mac oving4 % cd environments/prod/network
terraform init \
  -backend-config="../../../shared/backend.hcl" \
  -backend-config="key=prod/network.tfstate" \
  -reconfigure
terraform plan -out=network.tfplan
 
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 
Terraform will perform the following actions:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + location = "norwayeast"
      + name     = "rg-nett-oving4-prod-kd"
      + tags     = {
          + "environment" = "prod"
          + "managedby"   = "terraform"
          + "owner"       = "kd"
          + "project"     = "oving4"
          + "stack"       = "network"
        }
    }
 
  # module.network.azurerm_subnet.main["backend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes = ["10.30.2.0/24"]
      + name              = "snet-oving4-prod-kd-backend"
    }
 
  # module.network.azurerm_subnet.main["database"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes = ["10.30.3.0/24"]
      + name              = "snet-oving4-prod-kd-database"
    }
 
  # module.network.azurerm_subnet.main["frontend"] will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes = ["10.30.1.0/24"]
      + name              = "snet-oving4-prod-kd-frontend"
    }
 
  # module.network.azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space = ["10.30.0.0/16"]
      + name          = "vnet-oving4-prod-kd"
    }
 
Plan: 9 to add, 0 to change, 0 to destroy.
 
Changes to Outputs:
  + subnet_ids = {
      + backend  = (known after apply)
      + database = (known after apply)
      + frontend = (known after apply)
    }
  + vnet_id    = (known after apply)
 
Saved the plan to: network.tfplan
```
 
Samme kode som dev, annet adresserom (`10.30.0.0/16` mot `10.10.0.0/16`) og annet miljønavn i alle ressursnavn — uten en eneste endret linje i `modules/` eller koden selv.
 
---
 
## Del D – De fire forsøkene
 
### Forsøk 1 — Én stack, én state-fil
 
Dekket av blob-lista i punkt 5 over: tre filer i containeren, hver med sin egen `key`.
 
### Forsøk 2 — Låsen
 
For å trigge en reell lås måtte jeg gjøre en midlertidig, ufarlig endring (en ekstra tag) i `dev/network`, siden en `apply` uten endringer fullfører for raskt til at en samtidig `plan` rekker å kollidere med den.
 
**Terminal 1** (`terraform apply`, med en midlertidig tag lagt til i koden):
```text
khalil@Mac network % terraform apply
...
Plan: 0 to add, 3 to change, 0 to destroy.
 
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
 
  Enter a value:
```
*(sto og ventet her mens terminal 2 ble kjørt)*
 
**Terminal 2** (samtidig, samme mappe):
```text
khalil@Mac network % terraform plan
╷
│ Error: Error acquiring the state lock
│
│ Error message: state blob is already locked
│ Lock Info:
│   ID:        afbce8f7-f53b-5e9f-f215-4a16925b9dc7
│   Path:      tfstate/dev/network.tfstate
│   Operation: OperationTypeApply
│   Who:       khalil@Mac.home
│   Version:   1.16.1
│   Created:   2026-10-05 22:38:25.657836 +0000 UTC
│
│ Terraform acquires a state lock to protect the state from being written
│ by multiple users at the same time. Please resolve the issue above and
│ try again. For most commands, you can disable locking with the
│ "-lock=false" flag, but this is not recommended.
╵
```
 
**Tilbake i terminal 1:**
```text
  Enter a value: no
 
Apply cancelled.
```
 
Deretter fjernet jeg den midlertidige tagen og bekreftet at alt var tilbake til normalt:
```text
khalil@Mac network % terraform apply
...
No changes. Your infrastructure matches the configuration.
 
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```
 
**Svar:** Det er ikke en feil i oppsettet, men systemet som virker som tiltenkt. `Who: khalil@Mac.home` og `Created:`-tidspunktet viser nøyaktig hvem som holder låsen og når den ble tatt — nok informasjon til å løse en reell kollisjon mellom to personer uten å måtte gjette. Låsen finnes for å hindre at to samtidige `apply`-kjøringer skriver til samme state-fil og ødelegger hverandres endringer.
 
### Forsøk 3 — Feil rekkefølge
 
Siden `prod/network` kun var planlagt (se punkt 7), testet jeg `prod/app` før noe var apply'et i `prod/network`:
 
```text
khalil@Mac app % terraform init \
  -backend-config="../../../shared/backend.hcl" \
  -backend-config="key=prod/app.tfstate" \
  -reconfigure
...
Terraform has been successfully initialized!
 
khalil@Mac app % terraform plan
data.terraform_remote_state.network: Reading...
data.terraform_remote_state.network: Read complete after 1s
 
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 
Terraform planned the following actions, but then encountered a problem:
 
  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + location = "norwayeast"
      + name     = "rg-app-oving4-prod-kd"
    }
 
Plan: 1 to add, 0 to change, 0 to destroy.
╷
│ Error: Unsupported attribute
│
│   on main.tf line 40, in locals:
│   40:   subnet_id = data.terraform_remote_state.network.outputs.subnet_ids[var.vm_subnet_key]
│     ├────────────────
│     │ data.terraform_remote_state.network.outputs is object with no attributes
│
│ This object does not have an attribute named "subnet_ids".
╵
```
 
**Svar:** Feilen sier ikke at den andre stacken mangler, fordi Terraform ikke vet det. Når `terraform_remote_state` peker på en `key` som enten ikke finnes eller ikke har noen reelle ressurser ennå, får den ikke en feil tilbake fra Azure — den får et **tomt objekt**. Loggen bekrefter dette ordrett: `data.terraform_remote_state.network.outputs is object with no attributes`. Et tomt objekt har ingen attributter, og da blir `.outputs.subnet_ids` et oppslag på noe som rett og slett ikke eksisterer. Feilmeldingen beskriver symptomet (manglende attributt), ikke årsaken (nettverks-stacken er ikke rullet ut). Jeg la også merke til at planleggingen kom et stykke på vei først — `azurerm_resource_group.rg` ble planlagt helt fint siden den ikke er avhengig av remote state — og stoppet først når den traff `local.subnet_id`, nøyaktig der koblingen mellom stackene ligger.
 
---
 
## Opprydding
 
```text
khalil@Mac app % cd ../../dev/app
terraform destroy
...
Destroy complete! Resources: 3 destroyed.
 
khalil@Mac app % cd ../network
terraform destroy
...
Destroy complete! Resources: 9 destroyed.
 
khalil@Mac network % cd ../../..
az group list --query "[?contains(name,'oving4')].name" -o tsv
khalil@Mac oving4 %
```
 
`terraform destroy` kjørt i riktig rekkefølge — **app først, nettverk sist** — siden app er avhengig av nettverket, ikke omvendt. `az group list`-sjekken ga tom utskrift: ingen `oving4`-ressursgrupper gjenstår i abonnementet (`backend-bootstrap` sin `rg-tfstate-kd` er ikke en del av dette søket og skal bestå — den er tagget `keep = "true"`). `prod` ble aldri apply'et, så det var ingenting å rive der.
 