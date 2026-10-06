## Del A – Identiteten som ikke har noe passord
 
### K1 – Ingen client secrets på App Registration-en
 
```
khalil@Mac DCST3005-ovinger-kd % az ad app credential list --id "$APP_ID"
[]
```
 
Hele poenget med `Azure/login@v3.1.0` er at den tar tre identifikatorer (`client-id`, `tenant-id`, `subscription-id`) og ingen fjerde verdi. Det finnes ingen client secret å vise fram, fordi det ikke er nødvendig — beviset på at jobben har lov, er OIDC-tokenet GitHub utsteder under kjøring.
 
### K2 – Én federated credential per environment, scopet til environment
 
```json
[
  {
    "audiences": ["api://AzureADTokenExchange"],
    "description": "",
    "id": "f6fdf7d5-c34d-41bc-84f5-e7d10d48a0e7",
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-test",
    "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test"
  },
  {
    "audiences": ["api://AzureADTokenExchange"],
    "description": "",
    "id": "76a41e30-3661-4c04-a42a-68e43fb9a1d8",
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-dev",
    "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev"
  }
]
```
 
**Et reelt avvik underveis, og hvordan det ble løst:** Repoet mitt har GitHubs nyere funksjon for *immutable OIDC subject claims* påslått (`use_immutable_subject: true`), noe jeg ikke visste før workflowen feilet. Det betyr at GitHub ikke sender `repo:eier/repo:environment:miljø` i tokenet, men `repo:eier@org-id/repo@repo-id:environment:miljø` — med numeriske, uforanderlige ID-er i stedet for navn. Feilen så slik ut:
 
```
AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev'.
```
 
Jeg prøvde først å skru av `use_immutable_subject` via `gh api -X PUT .../actions/oidc/customization/sub`, men innstillingen sto fortsatt på `true` etter kallet — den lot seg ikke reversere på repo-nivå i dette tilfellet. Løsningen ble derfor å oppdatere subject-feltet på begge federated credentials i Entra ID til å matche det faktiske, immutable formatet:
 
```bash
az ad app federated-credential update \
  --id "$APP_ID" \
  --federated-credential-id github-dev \
  --parameters '{"subject":"repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev"}'
 
az ad app federated-credential update \
  --id "$APP_ID" \
  --federated-credential-id github-test \
  --parameters '{"subject":"repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test"}'
```
 
Dette er strengere, ikke svakere, enn navnebasert scoping: en omdøpt eller slettet-og-gjenopprettet konto/repo med samme navn kan ikke lenger arve tilgangen.
 
### Minste mulig workflow – bevis på tillitsforholdet
 
```
Run Azure/login@v3.1.0
Running Azure CLI Login.
/usr/bin/az cloud set -n azurecloud
Done setting cloud: "azurecloud"
Federated token details:
 issuer - https://token.actions.githubusercontent.com
 subject claim - repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev
 audience - api://AzureADTokenExchange
 job_workflow_ref - KhalilElDeek/DCST3005-ovinger-kd/.github/workflows/verify-logging.yml@refs/heads/main
Attempting Azure CLI login by using OIDC...
Subscription is set successfully.
Azure CLI login succeeds by using OIDC.
```
 
```
Run az account show --output json
{
  "environmentName": "AzureCloud",
  "homeTenantId": "***",
  "id": "***",
  "isDefault": true,
  "managedByTenants": [],
  "name": "sub_tenant03ntnu",
  "state": "Enabled",
  "tenantId": "***",
  "user": {
    "name": "***",
    "type": "servicePrincipal"
  }
}
```
 
`type: servicePrincipal` — det finnes ingen person bak denne innloggingen.
 
---
 
## Del B – Workflowen som ruller ut
 
### K3 – Ingen backend-blokk og ingen workflow-fil inneholder storage account-navnet
 
`stacks/network/versions.tf`:
```hcl
terraform {
  required_version = ">= 1.5.0"
 
  # K3: blokka er TOM, med vilje. Storage account-navnet skal ikke stå her -
  # det bor i shared/backend.hcl og sendes inn med -backend-config ved init.
  backend "azurerm" {}
 
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}
 
provider "azurerm" {
  features {}
  # Ingen subscription_id her - jobben setter ARM_SUBSCRIPTION_ID via OIDC.
}
```
 
`shared/backend.hcl`:
```hcl
resource_group_name  = "rg-tfstate-kd"
storage_account_name = "sttfkdqp6uud"
container_name       = "tfstate"
use_azuread_auth     = true
```
 
### K4 – Service principal-en har selv rettigheter på state-containeren
 
`backend-bootstrap/pipeline.tf`:
```hcl
# K4 - samme rolle som deg selv, men for service principal-en pipelinen bruker.
resource "azurerm_role_assignment" "pipeline_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.pipeline_principal_id
  principal_type       = "ServicePrincipal"
 
  depends_on = [
    azurerm_storage_account.tfstate,
    azurerm_storage_container.tfstate,
  ]
}
 
resource "azurerm_key_vault" "kv" {
  name                = substr(lower("kv-tf-${var.owner}${random_string.storage_suffix.result}"), 0, 24)
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
 
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
 
  tags = local.tags
}
 
# Du skal kunne SKRIVE secrets (laste opp tfvars-innholdet) - Officer, ikke User.
resource "azurerm_role_assignment" "kv_officer_meg" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}
 
# Workflowen skal bare LESE secrets under kjøring - User, ikke Officer.
resource "azurerm_role_assignment" "kv_user_pipeline" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.pipeline_principal_id
  principal_type       = "ServicePrincipal"
}
```
 
**Et avvik ingen krav dekker eksplisitt:** `terraform init` kom gjennom med rettighetene over, men selve `apply` i `stacks/network` feilet først med:
 
```
Error: checking for presence of existing Resource Group (Subscription: "***"
Resource Group Name: "rg-nett-oving5-dev-kd"): unexpected status 403 (403 Forbidden)
with error: AuthorizationFailed: The client '***' with object id 'd53e0123-32aa-401b-b76c-ee242749bddc'
does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourceGroups/read'
over scope '/subscriptions/***/resourceGroups/rg-nett-oving5-dev-kd' or the scope is invalid.
```
 
K4 gir service principal-en rettigheter på *state-containeren* — ikke på å opprette ressurser i abonnementet. Det kravet finnes ikke i K1–K10, og kan heller ikke løses i Terraform, siden ingenting kan gi seg selv sin egen første rettighet. Løst med én manuell, ett-gangs CLI-kommando, utenfor pipelinen, på samme måte som den første `.tfvars`-opplastingen:
 
```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUB_ID"
```
 
### K5 – Ingen .tfvars-fil i repoet
 
```
khalil@Mac DCST3005-ovinger-kd % git log --all --diff-filter=A --name-only -- '*.tfvars'
```
(tom utskrift — ingen `.tfvars`-fil er noen gang committet, i noen branch.)
 
`deploy-network.yml` henter parameterfila fra Key Vault under kjøring og sletter den igjen med `if: always()`:
```yaml
      - name: Hent parameterfila fra Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-$MILJO" \
            --query value -o tsv > params.auto.tfvars
      ...
      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars
```
 
---
 
## Del C – To miljøer, én kode
 
### K6 – Én stack-definisjon, ikke én per miljø
 
`stacks/network/variables.tf` (utdrag):
```hcl
variable "environment" {
  description = "Miljønavn: dev eller test. Kommer inn som en VERDI fra pipelinen, ikke som et mappenavn (K6)."
  type        = string
 
  validation {
    condition     = contains(["dev", "test"], var.environment)
    error_message = "environment må være dev eller test i denne øvingen."
  }
}
```
 
Ingen miljønavn forekommer i noe fil- eller mappenavn under `stacks/` — kun `stacks/network/`.
 
### K7 – Hvert miljø har sin egen state-fil og sine egne parameterverdier
 
```
khalil@Mac oving5 % az storage blob list \
  --container-name tfstate \
  --account-name sttfkdqp6uud \
  --auth-mode login \
  -o table
Name                      Blob Type    Blob Tier    Length    Content Type     Last Modified              Snapshot
------------------------  -----------  -----------  --------  ----------------  -------------------------  ----------
dev/app.tfstate           BlockBlob    Hot          322       application/json  2026-10-05T22:44:06+00:00
dev/network.tfstate       BlockBlob    Hot          324       application/json  2026-10-05T22:45:38+00:00
env/dev/network.tfstate   BlockBlob    Hot          17917     application/json  2026-10-06T19:05:37+00:00
env/test/network.tfstate  BlockBlob    Hot          17997     application/json  2026-10-06T19:09:38+00:00
prod/app.tfstate          BlockBlob    Hot          181       application/json  2026-10-05T22:41:54+00:00
prod/network.tfstate      BlockBlob    Hot          324       application/json  2026-10-05T22:35:24+00:00
```
 
`env/dev/network.tfstate` og `env/test/network.tfstate` er de to relevante for øving 5 — én per miljø, samme container. (`dev/`-, `prod/`-blobene uten `env/`-prefiks er rester fra øving 4 sine egne stacks, med annen `key`, og kolliderer ikke.)
 
**Utrulling av dev** (fra workflow-logg):
```
Plan: 9 to add, 0 to change, 0 to destroy.
...
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
 
Outputs:
resource_group_name = "rg-nett-oving5-dev-kd"
vnet_name = "vnet-oving5-dev-kd"
```
 
**Utrulling av test** (fra workflow-logg):
```
Plan: 9 to add, 0 to change, 0 to destroy.
...
azurerm_resource_group.rg: Creation complete after 26s [id=/subscriptions/***/resourceGroups/rg-nett-oving5-test-kd]
...
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
 
Outputs:
resource_group_name = "rg-nett-oving5-test-kd"
vnet_name = "vnet-oving5-test-kd"
```
 
Samme kode, annet adresserom (`10.20.0.0/16` mot `10.10.0.0/16`) og annet miljønavn i alle ressursnavn — uten en eneste endret linje i `modules/network/` eller i selve stacken.
 
---
 
## Del D – Triggeren, og det som ikke skal skje
 
### K8 – Push til main ruller ut dev, og bare dev / K9 – test kan ikke rulles ut av en push
 
Etter en push med en trivell endring i `stacks/network/main.tf`:
 
```
Federated token details:
 subject claim - repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev
...
terraform plan
No changes. Your infrastructure matches the configuration.
...
terraform apply -auto-approve
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
 
Outputs:
resource_group_name = "rg-nett-oving5-dev-kd"
vnet_name = "vnet-oving5-dev-kd"
```
 
Actions-oversikten etter pushen, 5 workflow-kjøringer totalt, kun én ny (den øverste) utløst av pushen:
 
- **test: K8/K9 - push skal kun rulle ut dev** — `Roll out network #4`, push av commit `9a5e47d`, 2 minutter gammel.
- **Roll out network #3** — manuell kjøring, 8 minutter gammel (den tidligere manuelle test-utrullingen, ikke utløst av denne pushen).
`test` fikk ingen ny kjøring fra pushen — K9 bekreftet.
 
---
 
## Del E – Nedrivingen som krever et bevisst valg
 
### K10 – Nedrivingen krever bekreftelse, validert av en egen jobb før noe kjøres
 
`riv-ned-nettverk.yml` kjørt for `dev` med bekreftelsesteksten `riv ned dev`:
 
```
Run terraform apply tfdestroy
...
azurerm_resource_group.rg: Destruction complete after 27s
Releasing state lock. This may take a few moments...
 
Apply complete! Resources: 0 added, 0 changed, 9 destroyed.
 
Run terraform state list
(tom)
 
Run rm -f params.auto.tfvars
```
 
Samme kjørt for `test` med bekreftelsesteksten `riv ned test` — samme resultat, ni ressurser revet, tom state.
 
> **TODO:** lim inn selve loggen fra test-nedrivingen her, på samme format som dev over, hvis du vil ha begge fulle logger med i innleveringen (du har allerede bekreftet at begge lykkedes).
 
---
 
## Del F – De fire forsøkene
 
### Forsøk 1 — Pipelinen er ikke deg
 
Lokalt, på min egen maskin:
```
khalil@Mac DCST3005-ovinger-kd % az account show --query user
{
  "name": "khalilel@stud.ntnu.no",
  "type": "user"
}
```
 
Fra workflow-loggen (kjørt som pipelinen):
```json
{
  "user": {
    "name": "***",
    "type": "servicePrincipal"
  }
}
```
 
Feltet som skiller de to er `type`: lokalt er jeg en `user` med navnet `khalilel@stud.ntnu.no`; i workflowen er innloggingen en `servicePrincipal`, med et GUID som navn i stedet for en e-postadresse. Det finnes ingen person bak kjøringen i workflowen — kun en identitet pipelinen selv fikk utstedt av Entra ID via OIDC-tokenet.
 
### Forsøk 2 — Tilliten er det som bærer
 
Federated credential for `test` ble midlertidig endret til `:environment:feil`:
```bash
az ad app federated-credential update \
  --id "$APP_ID" \
  --federated-credential-id github-test \
  --parameters '{"subject":"repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:feil"}'
```
 
Kjøring av `deploy-network.yml` mot `test` deretter:
```
Run Azure/login@v3.1.0
Running Azure CLI Login.
/usr/bin/az cloud set -n azurecloud
Done setting cloud: "azurecloud"
Federated token details:
 issuer - https://token.actions.githubusercontent.com
 subject claim - repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test
 audience - api://AzureADTokenExchange
 job_workflow_ref - KhalilElDeek/DCST3005-ovinger-kd/.github/workflows/deploy-network.yml@refs/heads/main
Attempting Azure CLI login by using OIDC...
Error: AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test'.
Check your federated identity credential Subject, Audience and Issuer against the presented assertion.
Error: Run the command below to authenticate interactively; additional arguments may be added as needed:
az logout
az login
Error: Login failed with Error: The process '/usr/bin/az' failed with exit code 1.
```
 
Deretter reversert:
```bash
az ad app federated-credential update \
  --id "$APP_ID" \
  --federated-credential-id github-test \
  --parameters '{"subject":"repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test"}'
```
 
**Svar:** Feilen oppstår i `azure/login`, ikke i `terraform init`. GitHub sendte fortsatt riktig subject (`...environment:test` — synlig i loggen, linje 17), men Entra ID fant ingen federated credential som matchet den strengen jeg nettopp hadde endret den til. Dette viser forskjellen på autentisering og autorisasjon: feilen her er at identiteten ikke blir gjenkjent i det hele tatt, før noe annet rekker å skje. Verken Terraform, state-fila eller noe i Azure ble rørt.
 
### Forsøk 3 — Hva loggen faktisk viser
 
Siden `.tfvars` lastes opp som én samlet secret (ikke én secret per verdi), ble `location`-verdien lest ut av den nedlastede parameterfila i stedet for direkte fra Key Vault:
 
```yaml
      - name: Midlertidig – hva havner i loggen?
        run: echo "location er $(grep location params.auto.tfvars)"
```
 
```
Run echo "location er $(grep location params.auto.tfvars)"
location er location     = "norwayeast"
```
 
**Svar:** Verdien står helt i klartekst. GitHub maskerer kun verdier den selv vet er hemmelige — typisk de som kommer fra `secrets.*` direkte i workflow-YAML-en. `location` ble hentet ut og tolket av `grep` under kjøring, og for logg-systemet er resultatet bare en vanlig tekststreng, ikke noe den gjenkjenner som sensitivt. Hadde dette vært et databasepassord i samme fil, ville det stått akkurat like synlig — og kjøringslogger blir liggende, synlige for alle med tilgang til repoet. Riktig løsning for en ekte hemmelighet er enten `echo "::add-mask::$VERDI"` før den havner i loggen, eller aller helst: aldri hente den inn i et steg som skriver den ut i utgangspunktet.
 
### Forsøk 4 — State overlevde runneren
 
Samme kjøring som K8-beviset over, på en helt fersk, aldri-før-brukt runner:
```
Run terraform plan
Acquiring state lock. This may take a few moments...
azurerm_resource_group.rg: Refreshing state... [id=/subscriptions/***/resourceGroups/rg-nett-oving5-dev-kd]
module.network.azurerm_virtual_network.main: Refreshing state...
module.network.azurerm_network_security_group.main: Refreshing state...
module.network.azurerm_subnet.main["backend"]: Refreshing state...
module.network.azurerm_subnet.main["database"]: Refreshing state...
module.network.azurerm_subnet.main["frontend"]: Refreshing state...
module.network.azurerm_subnet_network_security_group_association.main["database"]: Refreshing state...
module.network.azurerm_subnet_network_security_group_association.main["frontend"]: Refreshing state...
module.network.azurerm_subnet_network_security_group_association.main["backend"]: Refreshing state...
 
No changes. Your infrastructure matches the configuration.
```
 
**Svar:** Kunnskapen kom fra blobben i Azure, ikke fra disken på runneren — runnerens disk fantes ikke før akkurat denne kjøringen startet, og slettes igjen etterpå. `Initializing the backend...` kobler seg til `env/dev/network.tfstate` i Key Vault-bootstrap-ens storage-container ved hver `init`, og `Refreshing state...` på hver eneste ressurs er beviset på at Terraform spurte Azure «ser disse fortsatt slik ut», i stedet for å anta noe lokalt. `No changes` er dermed ikke runneren som husker noe — det er staten i Azure som husker, og runneren som spør pent hver gang.
 
---
 
## Del G – Rydd opp
 
Begge miljøer revet ned via `riv-ned-nettverk.yml` (se K10 over). `backend-bootstrap` (ressursgruppe, storage account, Key Vault) står fortsatt, uberørt — tagget `keep = "true"`, og trengs videre i modul 6.
 
`deploy-network.yml` (med `on: push`) er deaktivert i Actions-fanen etter at testingen var ferdig, slik at en senere commit i semesteret ikke ved et uhell ruller ut `dev` på nytt.
 
---
 
## Del H – Vurderingen
 
Mennesket er fortsatt inne akkurat der det bør være: når jeg skriver koden, når jeg laster opp .tfvars-innholdet til Key Vault én gang per miljø, når jeg velger test i nedtrekksmenyen for en manuell utrulling, og når jeg skriver bekreftelsesteksten før en nedriving. Det jeg ikke lenger gjør, er å logge inn med mitt eget passord eller trykke «apply» med min egen terminal — og det er nøyaktig det modulen ba om.

I Del C valgte jeg én workflow_dispatch-input fremfor en matrise eller en gjenbrukbar workflow, fordi det holdt antall filer nede og gjorde det tydelig for en medstudent hvor miljøvalget faktisk skjer — ett sted, i dropdown-menyen, ikke spredt over flere YAML-filer. Ulempen er at en matrise ville rullet ut begge miljøene samtidig med én trigger, noe som er raskere, men som også fjerner muligheten til å teste dev isolert før test røres.

Det farlige med at en push skulle kunne rulle ut test, er ikke selve utrullingen i seg selv, men at ingen bevisst tok den avgjørelsen — en skrivefeil i en commit-melding eller en hvilken som helst push til main ville da fått konsekvenser i et miljø som er ment å være mer stabilt enn dev. For å gjøre en fremtidig prod-utrulling forsvarlig, ville jeg lagt inn et GitHub Environment med obligatorisk godkjenning (required reviewers), slik at apply mot prod alltid stopper opp og venter på et bevisst «ja» fra et menneske, uansett hva workflow-filen sier.

Sammenlignet med øving 4 er oppsettet et sted mellom enklere og vanskeligere: selve stack-koden er kortere fordi det nå bare finnes én kopi i stedet for én mappe per miljø, men en medstudent må nå lese shared/backend.hcl og selve workflow-filene for å forstå hvilke verdier som faktisk brukes, siden de ikke lenger ligger synlig i en .tfvars-fil i repoet.
