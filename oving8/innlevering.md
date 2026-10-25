# Oppgave 8 – Endring av levende infrastruktur

Bygger videre på øving 7: koden i `oving8/stacks/network/` og
`oving8/modules/network/` er kopiert derfra (NSG-en har fra øving7 av ingen
inline `security_rule`-blokker – det viser seg å være akkurat riktig
utgangspunkt for denne øvingen, se S1). Bruker samme backend-storage
(`sttfkdqp6uud`), samme Key Vault (`kv-tf-kdqp6uud`), samme App Registration
(`oving5-pipeline-kd`) som resten av serien – men egne, isolerte
Key Vault-secrets (`tfvars-oving8-dev/test/prod`) og egne backend-state-keys
(`env/<miljø>/oving8-network.tfstate`), etter lærdommen fra øving6 om å
aldri dele state-nøkler mellom øvinger.

---

## Del 0 – Oppsett

### Mappestruktur og kodegjenbruk

```bash
mkdir -p oving8/stacks/network oving8/modules oving8/shared oving8/scripts
cp -r oving7/modules/network oving8/modules/network
cp -r oving7/stacks/network/* oving8/stacks/network/
cp oving6/shared/backend.hcl oving8/shared/backend.hcl
```

### CD dev/test/prod-workflows, kopiert fra øving6 og reparametrisert

```bash
cp .github/workflows/cd-dev.yml  /tmp/cd-dev-oving8.yml
cp .github/workflows/cd-test.yml /tmp/cd-test-oving8.yml
cp .github/workflows/cd-prod.yml /tmp/cd-prod-oving8.yml
# sed-kommandoer for å bytte alle oving6-stier/-keys til oving8
cp /tmp/cd-dev-oving8.yml  .github/workflows/cd-dev-oving8.yml
cp /tmp/cd-test-oving8.yml .github/workflows/cd-test-oving8.yml
cp /tmp/cd-prod-oving8.yml .github/workflows/cd-prod-oving8.yml
```

**Reelt avvik underveis:** `sed`-kommandoen som skulle bytte Key
Vault-secret-navnet (`"tfvars-dev"` → `"tfvars-oving8-dev"`) matchet aldri
noe, fordi den faktiske linja i filen er `--name "tfvars-dev" \` (en
CLI-flagg-syntaks), ikke `name: "tfvars-dev"` (YAML-nøkkel-syntaks) som
mønsteret lette etter. Rettet med riktig mønster:

```bash
sed -i '' 's/--name "tfvars-dev"/--name "tfvars-oving8-dev"/'   .github/workflows/cd-dev-oving8.yml
sed -i '' 's/--name "tfvars-test"/--name "tfvars-oving8-test"/' .github/workflows/cd-test-oving8.yml
sed -i '' 's/--name "tfvars-prod"/--name "tfvars-oving8-prod"/' .github/workflows/cd-prod-oving8.yml
```

### tfvars lastet opp til Key Vault

```bash
az keyvault secret set --vault-name "kv-tf-kdqp6uud" --name "tfvars-oving8-dev"  --file /tmp/dev.tfvars
az keyvault secret set --vault-name "kv-tf-kdqp6uud" --name "tfvars-oving8-test" --file /tmp/test.tfvars
az keyvault secret set --vault-name "kv-tf-kdqp6uud" --name "tfvars-oving8-prod" --file /tmp/prod.tfvars
```

`project_name = "oving8"`, egne CIDR-er (`10.10.0.0/16` dev,
`10.20.0.0/16` test, `10.30.0.0/16` prod), samme mønster som tidligere
øvinger.

### `riv-ned-oving8.yml`

Samme bekreftelse-port-mønster som øving6/7, med `tfvars-oving8-$MILJO` og
`env/$MILJO/oving8-network.tfstate` (unntatt prod, som beholdt
`env/prod/oving8-network.tfstate` – konsekvent gjennom hele øvingen siden
prod aldri var delt med andre øvinger).

### `.terraform.lock.hcl` – et repo-bredt funn

Da `.terraform.lock.hcl` skulle legges til for `oving8/stacks/network/`,
viste det seg at `.gitignore` inneholdt linja `.terraform.lock.hcl` – en
blindsone som har eksistert siden øving1, og som har ekskludert **hver
eneste** lock-fil i hele repoet fra git, stikk i strid med Terraforms egen
anbefaling ("Include this file in your version control repository"). Fjernet
linja fra `.gitignore`, og la til kun øving8 sine lock-filer (øving1–7 sine
historiske, allerede innleverte lock-filer ble bevisst latt urørt – ikke
verdt churnen på ferdig arbeid):

```bash
sed -i '' '/^\.terraform\.lock\.hcl$/d' .gitignore
git add .gitignore oving8/stacks/network/.terraform.lock.hcl oving8/modules/network/.terraform.lock.hcl
```

### PR #16 – merge-konflikt med branch protection

Første forsøk på å pushe rett til `main` ble avvist av Ruleset-et
(`GH013: Repository rule violations found`, krevde PR og 3 påkrevde
statussjekker). Flyttet alt til en gren (`oving8-setup`), PR #16, merget
etter at `fmt og validate` og `plan mot dev` (øving6 sin gamle,
fortsatt-aktive sjekk) var grønne.

### Bug: `kodekontroll` manglet som påkrevd sjekk

`ci-oving7.yml` hadde et `paths: ['oving7/**']`-filter, som gjorde at
`kodekontroll` aldri kjørte på PR #16 (den rørte bare `oving8/`). Siden
`kodekontroll` var lagt til som påkrevd sjekk i Ruleset-et, men aldri kjørte,
nektet GitHub å merge PR-en i det hele tatt – selv med `--admin`, fordi
bypass-listen er tom. Rettet i PR #17 ved å fjerne `paths:`-filteret helt
fra `ci-oving7.yml`, slik at `kodekontroll` nå kjører på **alle** PR-er til
`main`, akkurat som `fmt og validate` og `plan mot dev` allerede gjorde.
Deretter en tom-commit på `oving8-setup` for å tvinge GitHub til å
re-evaluere PR #16 sine sjekker, og PR #16 ble til slutt merget rent.

### Første `dev`-utrulling

```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
resource_group_name = "rg-nett-oving8-dev-kd"
vnet_name = "vnet-oving8-dev-kd"
```

---

## S1 – Finn drift

### Punkt 1 – `plan` før noen drift, med `-detailed-exitcode`

```bash
cd oving8/stacks/network
terraform init \
  -backend-config="../../shared/backend.hcl" \
  -backend-config="key=env/dev/oving8-network.tfstate"
terraform plan -lock=false -detailed-exitcode
echo "exit code: $?"
```

Resultat: `No changes. Your infrastructure matches the configuration.`,
exit-kode **0**.

### Punkt 2 – `lag-drift.sh`

```bash
cat > oving8/scripts/lag-drift.sh << 'EOF'
#!/usr/bin/env bash
# lag-drift.sh - simulerer en "nødreparasjon i portalen": fire endringer
# gjort direkte mot Azure, utenom Terraform, som en operatør under press
# kunne gjort for å løse et akutt problem. Terraform vet ingenting om disse.
set -euo pipefail

RG="${1:?Bruk: lag-drift.sh <resource-group>}"

VNET=$(az network vnet list -g "$RG" --query "[0].name" -o tsv)
NSG=$(az network nsg list -g "$RG" --query "[0].name" -o tsv)
SUBNET=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET" --query "[0].name" -o tsv)

echo "1) Legger til tags på vnet-et (incident-id, modified-by) ..."
az network vnet update -g "$RG" -n "$VNET" \
  --set "tags.incident-id=INC-0042" "tags.modified-by=emergency-response" -o none

echo "2) Kobler NSG fra $SUBNET ..."
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" \
  --remove networkSecurityGroup -o none

echo "3) Legger til en SSH-regel direkte i NSG-en (utenom Terraform) ..."
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n tillat-ssh-noed \
  --priority 150 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes '*' --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 22 -o none

echo "4) Lager et ekstra subnett Terraform ikke vet om ..."
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-ekstra-drift \
  --address-prefixes 10.10.9.0/24 -o none
EOF
chmod +x oving8/scripts/lag-drift.sh

bash oving8/scripts/lag-drift.sh rg-nett-oving8-dev-kd
```

```
VNet:   vnet-oving8-dev-kd
NSG:    nsg-oving8-dev-kd
Subnet valgt for frakobling: snet-oving8-dev-kd-frontend

1) Legger til tags på vnet-et (incident-id, modified-by) ...
2) Kobler NSG fra snet-oving8-dev-kd-frontend ...
3) Legger til en SSH-regel direkte i NSG-en (utenom Terraform) ...
4) Lager et ekstra subnett Terraform ikke vet om ...

Drift lagt til i rg-nett-oving8-dev-kd.
```

### Punkt 3 – gjetning før ny plan

Fire endringer, forventet synlighet (notert FØR plan ble kjørt på nytt):
1. Tags på vnet-et – **ser den**, siden `tags` er et argument i koden.
2. NSG koblet fra subnett – **ser den**, koblingen er en egen ressurs i
   state.
3. SSH-regel i NSG-en – **ser den ikke**, NSG-ressursen har ingen
   `security_rule`-blokker i koden, så Terraform eier ingen regler der.
4. Ekstra subnett – **ser den ikke**, subnettet står ikke i state i det
   hele tatt; `plan` spør aldri Azure om noe den ikke allerede kjenner til.

### Punkt 4 – `plan` etter drift

```bash
terraform plan
echo "exit code: $?"
```

```
# module.network.azurerm_subnet_network_security_group_association.main["frontend"] will be created
+ resource "azurerm_subnet_network_security_group_association" "main" {
    + network_security_group_id = ".../nsg-oving8-dev-kd"
    + subnet_id                 = ".../snet-oving8-dev-kd-frontend"
  }

# module.network.azurerm_virtual_network.main will be updated in-place
~ resource "azurerm_virtual_network" "main" {
    ~ tags = {
          "environment" = "dev"
        - "incident-id" = "INC-0042" -> null
          "kurs"        = "dcst3005"
          "managedby"   = "terraform"
        - "modified-by" = "emergency-response" -> null
          "owner"       = "kd"
          "project"     = "oving8"
          "stack"       = "network"
      }
  }

Plan: 1 to add, 1 to change, 0 to destroy.
```

`exit code: 2` – nøyaktig slik oppgaven forventet: to av fire endringer
synlige (tags og NSG-koblingen), to usynlige (SSH-regelen, det ekstra
subnettet).

**Ikke rettet ennå** – drift-en ble stående, siden S2 trengte den.

---

## S2 – En drift-sjekk som melder fra

### `.github/workflows/drift-oving8.yml`

```yaml
name: Drift dev (oving8)

on:
  schedule:
    - cron: '0 11 * * 1-5'
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  sjekk:
    name: drift-sjekk dev
    runs-on: ubuntu-latest
    environment: dev

    defaults:
      run:
        working-directory: oving8/stacks/network

    steps:
      - name: Hent koden
        uses: actions/checkout@v4
      - name: Installer Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - name: Logg inn i Azure
        uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila for dev
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-oving8-dev" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        run: |
          terraform init \
            -backend-config="${{ github.workspace }}/oving8/shared/backend.hcl" \
            -backend-config="key=env/dev/oving8-network.tfstate"

      # Kjernen i hele workflowen. Tre detaljer, alle med vilje:
      #   set +e        - ellers stopper steget ved exit-kode 2 (bash -e)
      #   > fil         - IKKE en pipe; da ville vi fått exit-koden til en
      #                   annen kommando i stedet for terraform sin egen
      #   -lock=false   - planen skriver ingenting og skal ikke blokkere
      #                   en samtidig CD dev-kjøring
      - name: Plan med detaljert exit-kode
        id: plan
        run: |
          set +e
          terraform plan -lock=false -no-color -detailed-exitcode > plan.txt 2>&1
          kode=$?
          set -e
          cat plan.txt
          echo "kode=$kode" >> "$GITHUB_OUTPUT"

      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars

      - name: Skriv sammendrag
        if: always()
        env:
          KODE: ${{ steps.plan.outputs.kode }}
        run: |
          {
            case "$KODE" in
              0) echo "## ✅ Ingen drift i dev" ;;
              2) echo "## ⚠️ Drift i dev – Azure stemmer ikke med main" ;;
              *) echo "## ❌ Drift-sjekken feilet – se loggen" ;;
            esac
            echo
            grep -E '^(Plan:|No changes)' plan.txt || true
            echo
            echo "<details><summary>Hele planen</summary>"
            echo
            echo '```text'
            cat plan.txt 2>/dev/null || true
            echo '```'
            echo
            echo "</details>"
          } >> "$GITHUB_STEP_SUMMARY"

      # Til slutt: gjør jobben rød hvis det var drift (2) eller feil (1).
      - name: Rød ved drift
        env:
          KODE: ${{ steps.plan.outputs.kode }}
        run: |
          if [ "$KODE" != "0" ]; then
            echo "::error::Drift-sjekken ga exit-kode $KODE – se sammendraget."
            exit 1
          fi
```

PR #18, merget etter grønne sjekker.

### Punkt 2 – kjør Drift dev manuelt, første gang (drift fortsatt i dev)

Actions → **Drift dev (oving8)** → Run workflow.

```
✗ Rød ved drift – "Error: Drift-sjekken ga exit-kode 2 – se sammendraget."
```

Sammendrag:
```
⚠️ Drift i dev – Azure stemmer ikke med main
Plan: 1 to add, 1 to change, 0 to destroy.
```

### Punkt 3 – rett dev, kjør drift-sjekken igjen

Actions → `CD dev` → siste kjøring → **Re-run all jobs** → `Success`, `1m 1s`.

Deretter **Drift dev (oving8)** manuelt igjen:

```
✅ Ingen drift i dev
No changes. Your infrastructure matches the configuration.
```

### Punkt 4 – hva står likevel igjen i Azure?

```bash
az network nsg rule list -g rg-nett-oving8-dev-kd --nsg-name nsg-oving8-dev-kd --query "[].name" -o tsv
az network vnet subnet list -g rg-nett-oving8-dev-kd --vnet-name vnet-oving8-dev-kd -o table
```

```
tillat-ssh-noed

Name                           AddressPrefix
------------------------------ ---------------
snet-oving8-dev-kd-frontend
snet-oving8-dev-kd-backend
snet-ekstra-drift              10.10.9.0/24
snet-oving8-dev-kd-database
```

Begge fortsatt der, til tross for den grønne sjekken. Ryddet bort for hånd:

```bash
az network nsg rule delete -g rg-nett-oving8-dev-kd --nsg-name nsg-oving8-dev-kd -n tillat-ssh-noed
az network vnet subnet delete -g rg-nett-oving8-dev-kd --vnet-name vnet-oving8-dev-kd -n snet-ekstra-drift
```

---

## S3 – Rull tilbake

### Punkt 1 – bytt prefiks, se den destruktive planen

`oving8/modules/network/main.tf`:
```diff
- name = lower(format("snet-%s-%s", var.base_name, each.key))
+ name = lower(format("subnet-%s-%s", var.base_name, each.key))
```

PR #19. Lokal plan (siden `oving8` ikke har noen PR-tids plan-kommentar av
sin egen – kun øving6 sin stale `plan mot dev` postet på PR-en, irrelevant
for `oving8`):

```
# module.network.azurerm_subnet.main["backend"] must be replaced
-/+ resource "azurerm_subnet" "main" {
    ~ name = "snet-oving8-dev-kd-backend" -> "subnet-oving8-dev-kd-backend" # forces replacement
  }
# ... samme for database, frontend, og de tre
# azurerm_subnet_network_security_group_association-ressursene

Plan: 6 to add, 0 to change, 6 to destroy.
```

PR #19 merget. `CD dev` kjørte den ekte, destruktive endringen –
subnettene ble revet og gjenskapt med `subnet-`-navn, bekreftet med
`az network vnet subnet list`.

### Punkt 2 – Vei B: rask tilbakerulling (Re-run all jobs på gammel kjøring)

```bash
gh run list --workflow=cd-dev-oving8.yml --limit 2
gh run rerun 40028680230   # kjøringen FØR den gale commiten
```

```
az network vnet subnet list -g rg-nett-oving8-dev-kd --vnet-name vnet-oving8-dev-kd -o table
```
```
snet-oving8-dev-kd-frontend
snet-oving8-dev-kd-database
snet-oving8-dev-kd-backend
```

`dev` tilbake til `snet-` – men `main` har fortsatt `subnet-` i koden.

### Punkt 3 – Vei A: ekte tilbakerulling (`git revert`)

```bash
git log --oneline -5
# d630d12 Merge pull request #19 ...

git switch -c revert-subnett-prefiks
git revert -m 1 d630d12 --no-edit
git push -u origin revert-subnett-prefiks
gh pr create --base main --fill
```

Lokal plan på revert-grenen:

```
No changes. Your infrastructure matches the configuration.
```

Nøyaktig som forventet – `dev` ble allerede fikset av Vei B, så revert-en
endrer bare hva `main` *sier*, ikke hva som faktisk kjører. PR #20 merget.
`main` har nå både den gale commiten (`3b7a7a4`) og revert-commiten i
historikken, side om side.

---

## S4 – Døp om uten å rive

**Tilpasning fra referanseløsningen:** løsningsforslaget bytter modulkallet
fra `network` til `nettverk` fordi mappenavnet der er `stacks/nettverk/`
(norsk). Vårt repo bruker konsekvent engelske mappenavn
(`stacks/network/`), så det finnes ingen reell navne-inkonsistens å rette.
Vi gjorde byttet likevel – til `module "nett"` – utelukkende for å
demonstrere selve `moved`-mekanikken, som er det pedagogiske poenget i S4.

### Punkt 1 – bytt modulkallet, lokal plan UTEN moved

`oving8/stacks/network/main.tf`:
```bash
sed -i '' 's/^module "network" {/module "nett" {/' oving8/stacks/network/main.tf
```

`oving8/stacks/network/outputs.tf`:
```bash
sed -i '' 's/module\.network\./module.nett./g' oving8/stacks/network/outputs.tf
```

Lokal plan (ikke pushet):
```
Plan: 8 to add, 0 to change, 8 to destroy.
```

Nøyaktig som forventet – et nytt modulnavn uten `moved`-blokk ser identisk
ut for Terraform som "slett alt, bygg alt på nytt".

### Punkt 2 – legg til `moved.tf`, re-plan

```bash
cat > oving8/stacks/network/moved.tf << 'EOF'
moved {
  from = module.network
  to   = module.nett
}
EOF
```

Lokal plan på nytt:
```
# module.network.azurerm_virtual_network.main has moved to module.nett.azurerm_virtual_network.main
# module.network.azurerm_network_security_group.main has moved to module.nett.azurerm_network_security_group.main
# module.network.azurerm_subnet.main["frontend"] has moved to module.nett.azurerm_subnet.main["frontend"]
# module.network.azurerm_subnet.main["backend"] has moved to module.nett.azurerm_subnet.main["backend"]
# module.network.azurerm_subnet.main["database"] has moved to module.nett.azurerm_subnet.main["database"]
# ... og tilsvarende for alle tre azurerm_subnet_network_security_group_association

Plan: 0 to add, 0 to change, 0 to destroy.
```

### Punkt 3 – PR, merge, promoter samme SHA til dev, test og prod

```bash
git switch -c steg-s4-moved
git add oving8/stacks/network/main.tf oving8/stacks/network/outputs.tf oving8/stacks/network/moved.tf
git commit -m "S4: dop om modulkallet til nett, moved.tf sa ingenting rives"
git push -u origin steg-s4-moved
gh pr create --base main --fill
```

Merget. `CD dev` kjørte automatisk – `0 destroyed`, bekreftet.

```bash
gh run list --workflow=cd-dev-oving8.yml --limit 1
```

Samme SHA trigget manuelt mot `CD test` og `CD prod` (sistnevnte krevde
godkjenning via Required reviewers-porten fra øving6, samme mønster som
tidligere). Begge grønne, `0 destroyed`.

---

## S5 – Rydd opp etter moved

Kun gjort **etter** at dev, test OG prod alle hadde fått S4-endringen:

```bash
git switch main && git pull
git switch -c steg-s5-fjern-moved
git rm oving8/stacks/network/moved.tf
git commit -m "S5: fjern moved.tf - alle tre miljoer har fatt S4"
git push -u origin steg-s5-fjern-moved
gh pr create --base main --fill
```

PR #22 merget.

```
khalil@Mac DCST3005-ovinger-kd % gh run list --workflow=cd-dev-oving8.yml --limit 1
STATUS  TITLE                 WORKFLOW  BRANCH  EVENT  ID           ELAPSED  AGE
✓       dev ← 9a942a938e2...  CD dev    main    push   40216197642  45s      about 4 minu...

khalil@Mac DCST3005-ovinger-kd % gh run list --workflow=cd-test-oving8.yml --limit 1
STATUS  TITLE             WORKFLOW  BRANCH  EVENT         ID           ELAPSED  AGE
✓       test ← 9a942a...  CD test   main    workflow_...  40216353834  42s      about 2 m...

khalil@Mac DCST3005-ovinger-kd % gh run list --workflow=cd-prod-oving8.yml --limit 1
STATUS  TITLE             WORKFLOW  BRANCH  EVENT         ID           ELAPSED  AGE
✓       prod ← 9a942a...  CD prod   main    workflow_...  40216313429  59s      about 3 m...
```

Samme SHA (`9a942a9`) grønt i alle tre, alle `terraform plan` som
`No changes` – `moved.tf` kunne fjernes helt uten at noe miljø merket det.

Deretter revet ned for natten: `Riv ned et miljø (oving8)` kjørt mot `dev`,
`test` og `prod`, med bekreftelse per miljø og godkjenning for `prod`.

---

## S6 – Refleksjon

**1. Drift-sjekken har vært grønn i en måned. En kollega sier: «Da vet vi at
dev er slik koden beskriver.» Hva svarer du?**

Nei, ikke helt – en grønn drift-sjekk betyr bare at *det Terraform eier*,
stemmer med koden. Den sier ingenting om resten av ressursgruppa. Jeg så
dette konkret i S2: etter at `CD dev` rettet tagg-endringen og
NSG-koblingen, ble `Drift dev`-sjekken grønn med `No changes` – men SSH-
regelen `tillat-ssh-noed` (åpen fra `*` på port 22) og det ekstra subnettet
`snet-ekstra-drift` sto fortsatt i `dev`, usett av Terraform fordi NSG-en
ikke har noen `security_rule`-blokker i koden, og subnettet aldri kom inn i
state. Grønt lys fra `plan` er en påstand om det Terraform *spør om* – ikke
en garanti om alt som finnes i ressursgruppa.

**2. Prod er nede etter en utrulling. Hva gjør du de første fem minuttene,
og hva gjør du etterpå? Hvorfor i den rekkefølgen?**

De første fem minuttene: Vei B – finn den siste kjøringen av `CD prod` som
var grønn, og kjør **Re-run all jobs** på den. Det er den raskeste veien
tilbake til en fungerende tjeneste, fordi den bare gjenbruker kode og en
plan vi vet virket. Jeg demonstrerte akkurat dette i S3 med `dev`: et
`gh run rerun` på den forrige kjøringen hentet subnettene tilbake til
`snet-`-navnene på under to minutter, uten å vente på en ny pull request.

Rett etterpå, men ikke før: Vei A – en `git revert` av den gale commiten,
gjennom en vanlig pull request, merget til `main`. Dette endrer ikke
infrastrukturen i det hele tatt (jeg så selv at plan-en på revert-PR-en kom
tilbake som `No changes`, siden `dev` allerede var rettet av Vei B) – den
retter bare *historien*, slik at `main` igjen beskriver det som faktisk
kjører. Rekkefølgen er bevisst: tjenesten må opp først, fordi det er brukerne
som merker nedetid. Sannheten i `main` kommer rett etter, fordi uten den vil
neste ordinære merge til `main` dra den gale koden med seg tilbake – en
re-run alene løser ikker problemet permanent, bare midlertidig.

**3. Hvilken endring i stacken min kunne ikke vært gjort med `moved`, og
hvorfor ikke?**

Subnett-prefiks-byttet fra S3 (`snet-` → `subnet-`). En `moved`-blokk
fungerer bare når selve ressursen i Azure er uendret, og det eneste som
endres, er navnelappen Terraform bruker *internt* i state (adressen i
koden, ikke identiteten i skyen). Å bytte `name`-attributtet på en
`azurerm_subnet` endrer derimot navnet på selve Azure-ressursen – det
tvinger `forces replacement`, fordi et subnett ikke kan byttes navn i
Azure. `moved` løser omdøpinger i *Terraform sin bokføring*; det løser ikke
omdøpinger i *den virkelige infrastrukturen*. S4 sitt modulkall-bytte var
derimot akkurat det `moved` er laget for: samme ressurser i Azure, bare en
ny adresse i Terraform sin state.
