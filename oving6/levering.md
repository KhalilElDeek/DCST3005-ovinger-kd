# Oppgave 6 (enkel) – Bygg en gang, rull ut mange steder

Bygger videre på øving 5: samme backend-storage (`sttfkdqp6uud`), samme Key Vault
(`kv-tf-kdqp6uud`), samme App Registration (`oving5-pipeline-kd`,
`a63938a5-8753-4448-bbe2-2853ac27e8dd`). Det nye er fire workflow-filer og en
tredje federated credential for `prod`. Repoet ble gjort **public** underveis –
`Required reviewers` på environments krever det på en gratis GitHub-konto.

---

## Del 0 – Forutsetninger

### Kode kopiert fra øving5, under ny mappe `oving6/`

```bash
mkdir -p oving6/.github/workflows oving6/stacks/network oving6/modules oving6/shared
cp -r oving5/modules/network oving6/modules/network
cp -r oving5/stacks/network/* oving6/stacks/network/
cp oving5/shared/backend.hcl oving6/shared/backend.hcl
```

`oving6/stacks/network/variables.tf` fikk `environment`-valideringen utvidet til
å tillate `prod`, i tillegg til `dev`/`test`:

```hcl
variable "environment" {
  description = "Miljønavn: dev, test eller prod. Kommer inn som en VERDI fra pipelinen, ikke som et mappenavn."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment må være dev, test eller prod i denne øvingen."
  }
}
```

### Linux-låsefil

Workflowene kjører på Linux-runnere, men utviklingsmaskinen er en Mac – en
låsefil generert bare lokalt ville feilet i CI:

```bash
cd oving6/stacks/network
terraform init -backend=false
terraform providers lock \
  -platform=linux_amd64 -platform=darwin_arm64 \
  -platform=darwin_amd64 -platform=windows_amd64
```

```
Success! Terraform has updated the lock file.
```

`.terraform.lock.hcl` committet på `main` før branch protection ble satt opp
(tillatt, siden `main` ikke var beskyttet enda på dette tidspunktet).

### `tfvars-prod` i Key Vault

```bash
cat > /tmp/prod.tfvars << 'EOF'
owner        = "kd"
project_name = "oving6"
environment  = "prod"
location     = "norwayeast"
vnet_cidr    = "10.30.0.0/16"
subnets = {
  frontend = 0
  backend  = 1
  database = 2
}
EOF
az keyvault secret set --vault-name "kv-tf-kdqp6uud" --name "tfvars-prod" --file /tmp/prod.tfvars
rm /tmp/prod.tfvars
```

### Fjerde federated credential: `github-prod`

App Registration-en manglet en credential for selve `prod`-miljøet (ikke bare
`prod-plan`, som den fulle versjonen av oppgaven ville trengt – denne enkle
versjonen har ingen egen plan-jobb for prod, så kun én ny credential var
nødvendig):

```bash
APP_ID="a63938a5-8753-4448-bbe2-2853ac27e8dd"

az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-prod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:prod",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

```json
[
  {
    "name": "github-prod",
    "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:prod"
  },
  {
    "name": "github-test",
    "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:test"
  },
  {
    "name": "github-dev",
    "subject": "repo:KhalilElDeek@188042090/DCST3005-ovinger-kd@1400750769:environment:dev"
  }
]
```

ID-basert subject brukt gjennomgående, samme begrunnelse som i øving5: repoet
har GitHubs immutable OIDC subject claims påslått og lot seg ikke skru av via
`gh api .../customization/sub`.

### `prod`-environment i GitHub

- Required reviewers: ✅, KhalilElDeek lagt til som reviewer
- Prevent self-review: av (nødvendig siden jeg er alene i repoet)
- Deployment branches and tags: Selected branches and tags → `main`
- Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (samme
  verdier som dev/test), `KEYVAULT_NAME` dekkes allerede som repo-secret

**Forutsetning som måtte løses underveis:** `Required reviewers` vises ikke i
det hele tatt på en privat repo med gratis GitHub-konto. Repoet ble gjort
public (Settings → General → Danger Zone → Change visibility) for at
seksjonen "Deployment protection rules" skulle rendres.

---

## Steg 1 – CI sjekker koden, uten Azure-tilgang

`.github/workflows/ci.yml` (kontroll-jobben):

```yaml
name: CI

on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  kontroll:
    name: fmt og validate
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: terraform fmt -check
        working-directory: oving6
        run: terraform fmt -check -recursive

      - name: terraform init (uten backend)
        working-directory: oving6/stacks/network
        run: terraform init -backend=false

      - name: terraform validate
        working-directory: oving6/stacks/network
        run: terraform validate
```

```bash
git switch -c steg-1-ci
git add .github/workflows/ci.yml
git commit -m "Steg 1: CI sjekker koden, uten Azure-tilgang"
git push -u origin steg-1-ci
gh pr create --base main --fill
```

**PR #1** – "Steg 1: CI sjekker koden, uten Azure-tilgang". `fmt og validate`
grønn, 9s, ingen `Azure/login`-steg i loggen. Merget.

---

## Steg 2 – Lås main

Satt opp som en **Ruleset** (`protect-main`, Active), ikke den eldre "classic
branch protection"-siden – bekreftet at `Settings → Branches` viser
*"Classic branch protections have not been configured"*, så det er Ruleset-et
alene som styrer `main`.

Rules i `protect-main`:
- ✅ Require a pull request before merging, Required approvals = 0
- ✅ Require status checks to pass → `fmt og validate`
- ✅ Restrict deletions, ✅ Block force pushes
- Bypass list: **tom** (tilsvarer "Do not allow bypassing" i den gamle UI-en –
  gjelder alle, inkludert repo-eier)

### Test 1 – push rett til main

```bash
git switch main && git pull
echo "test branch protection" >> README.md
git add README.md
git commit -m "direkte"
git push
```

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - Required status check "fmt og validate" is expected.
 ! [remote rejected] main -> main (push declined due to repository rule violations)
```

Lokal commit rullet tilbake (`git reset --hard HEAD~1`) siden den aldri nådde
`main`.

### Test 2 – rød sjekk sperrer merge, også for eieren

```bash
git switch -c steg-2-test-sperre
# fjernet innrykk i oving6/stacks/network/main.tf med vilje
git add oving6/stacks/network/main.tf
git commit -m "test: bevisst feil formatering"
git push -u origin steg-2-test-sperre
gh pr create --base main --fill
```

**PR #2** – `CI / fmt og validate (pull_request)` feilet etter 6s, merket
"Required". Merge-knappen var grå/sperret. Lukket uten å merge (branch
slettet, PR auto-lukket av GitHub).

**Svar på spørsmålet i forsøket:** den andre sperren ville ha lyktes om
bypass-listen i ruleset-et ikke var tom (klassisk UI: om "Do not allow
bypassing" ikke var krysset av). Den gjelder meg som repo-eier fordi jeg
ellers ville hatt administrator-privilegier til å trykke meg forbi –
nettopp det en pipeline med null menneskelig unntak skal hindre.

---

## Steg 3 – Planen for dev som kommentar på PR-en

Lagt til i `ci.yml`, egen jobb `plan-dev` med `needs: kontroll`:

```yaml
  plan-dev:
    name: plan mot dev
    needs: kontroll
    runs-on: ubuntu-latest
    environment: dev

    permissions:
      contents: read
      id-token: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila fra Key Vault
        working-directory: oving6/stacks/network
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-dev" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        working-directory: oving6/stacks/network
        run: |
          terraform init \
            -backend-config="${{ github.workspace }}/oving6/shared/backend.hcl" \
            -backend-config="key=env/dev/oving6-network.tfstate"

      - name: Plan
        working-directory: oving6/stacks/network
        run: terraform plan -no-color -out=tfplan | tee plan_output.txt

      - name: Legg plan som kommentar på PR-en
        working-directory: oving6/stacks/network
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          {
            echo "### Terraform plan – dev"
            echo "<details><summary>Vis plan</summary>"
            echo ""
            echo '```'
            cat plan_output.txt
            echo '```'
            echo "</details>"
          } > pr_comment.md
          gh pr comment "${{ github.event.pull_request.number }}" --body-file pr_comment.md

      - name: Slett parameterfila
        if: always()
        working-directory: oving6/stacks/network
        run: rm -f params.auto.tfvars
```

**PR #3** – begge sjekker grønne (`fmt og validate` 9s, `plan mot dev` 38s).
Plan-kommentaren landet foldet i en `<details>`-blokk, lesbar uten fargekoder
(`terraform_wrapper: false` + `-no-color`). Merget. `plan mot dev` lagt til
som andre påkrevde status-sjekk i `protect-main`.

---

## Steg 4 – CD dev: utrulling ved merge

```yaml
name: CD dev
run-name: dev ← ${{ github.sha }}

on:
  push:
    branches: [main]
    paths:
      - 'oving6/stacks/network/**'
      - 'oving6/modules/network/**'
      - 'oving6/shared/backend.hcl'
      - '.github/workflows/cd-dev.yml'

permissions:
  id-token: write
  contents: read

concurrency:
  group: oving6-dev
  cancel-in-progress: false

jobs:
  rull-ut:
    runs-on: ubuntu-latest
    environment: dev

    defaults:
      run:
        working-directory: oving6/stacks/network

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila fra Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-dev" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        run: |
          terraform init \
            -backend-config="${{ github.workspace }}/oving6/shared/backend.hcl" \
            -backend-config="key=env/dev/oving6-network.tfstate"

      - name: Plan
        run: terraform plan -out=tfplan

      - name: Apply (lagret plan, ingen auto-approve)
        run: terraform apply tfplan

      - name: Skriv oppsummering
        run: echo "Rullet ut \`${{ github.sha }}\` til dev" >> "$GITHUB_STEP_SUMMARY"

      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars
```

**PR #4** merget → `CD dev` startet automatisk, grønn på 1m 44s. SHA i
kjøringsnavnet matchet `git log -1` på oppdatert `main`.

**Reelt avvik underveis, rettet før det ble et problem i Del F/Steg 7:**
`cd-dev.yml` og `plan-dev`-jobben i `ci.yml` pekte opprinnelig på samme
backend-state-key og samme Key Vault-secret-navn som øving5
(`env/dev/network.tfstate`, `tfvars-dev`). Siden øving5 og øving6 deler
storage-konto og Key Vault med vilje, betydde det at `CD dev` i praksis leste
og skrev øving5 sin ekte state – synlig ved at ressursgruppene kom ut som
`rg-nett-oving5-dev-kd` i stedet for `rg-nett-oving6-dev-kd`. Løsningen var å
gi `dev` og `test` sin egen state-key i øving6
(`env/dev/oving6-network.tfstate`, `env/test/oving6-network.tfstate`) og
laste opp `tfvars-dev`/`tfvars-test` på nytt med `project_name = "oving6"`.
`prod` hadde aldri dette problemet, siden `tfvars-prod` ble opprettet separat
fra starten. Fikset i **PR #7** ("Steg 7-fix: egen state-key for oving6,
isolert fra oving5"). Push etter fiksen bekreftet korrekt navngiving:
`rg-nett-oving6-dev-kd`, `vnet-oving6-dev-kd`.

---

## Steg 5 – CD test: promoter commiten selv

```yaml
name: CD test
run-name: test ← ${{ inputs.sha }}

on:
  workflow_dispatch:
    inputs:
      sha:
        description: Hele commit-SHA-en fra en vellykket CD dev-kjøring
        type: string
        required: true

permissions:
  id-token: write
  contents: read

concurrency:
  group: oving6-test
  cancel-in-progress: false

jobs:
  rull-ut:
    runs-on: ubuntu-latest
    environment: test

    defaults:
      run:
        working-directory: oving6/stacks/network

    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.sha }}
          fetch-depth: 0

      - name: Sjekk at commiten ligger på main
        env:
          SHA: ${{ inputs.sha }}
        run: git merge-base --is-ancestor "$SHA" origin/main

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila fra Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-test" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        run: |
          terraform init \
            -backend-config="${{ github.workspace }}/oving6/shared/backend.hcl" \
            -backend-config="key=env/test/oving6-network.tfstate"

      - name: Plan
        run: terraform plan -out=tfplan

      - name: Apply (lagret plan, ingen auto-approve)
        run: terraform apply tfplan

      - name: Skriv oppsummering
        run: echo "Rullet ut \`${{ inputs.sha }}\` til test" >> "$GITHUB_STEP_SUMMARY"

      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars
```

**PR #5** merget. Kjørt manuelt med SHA `7344e7059837faa654d7d58107b77c4270cbae19`
(den samme som `CD dev` sin kjøring). Resultat: `test ← 7344e705...`, Success,
1m 35s. `dev ←` og `test ←` i Actions-lista viste identisk SHA – promotering,
ikke ny utrulling.

---

## Steg 6 – CD prod: porten med et menneske

```yaml
name: CD prod
run-name: prod ← ${{ inputs.sha }}

on:
  workflow_dispatch:
    inputs:
      sha:
        description: Hele commit-SHA-en fra en vellykket CD test-kjøring
        type: string
        required: true

permissions:
  id-token: write
  contents: read

concurrency:
  group: oving6-prod
  cancel-in-progress: false

jobs:
  rull-ut:
    runs-on: ubuntu-latest
    environment: prod

    defaults:
      run:
        working-directory: oving6/stacks/network

    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.sha }}
          fetch-depth: 0

      - name: Sjekk at commiten ligger på main
        env:
          SHA: ${{ inputs.sha }}
        run: git merge-base --is-ancestor "$SHA" origin/main

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila fra Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-prod" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        run: |
          terraform init \
            -backend-config="${{ github.workspace }}/oving6/shared/backend.hcl" \
            -backend-config="key=env/prod/network.tfstate"

      - name: Plan
        run: terraform plan -out=tfplan

      - name: Apply (lagret plan, ingen auto-approve)
        run: terraform apply tfplan

      - name: Skriv oppsummering
        run: echo "Rullet ut \`${{ inputs.sha }}\` til prod" >> "$GITHUB_STEP_SUMMARY"

      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars
```

**PR #6** merget. Kjørt manuelt med samme SHA som Steg 5. Kjøringen stoppet i
**Waiting**-status med gul boks *"KhalilElDeek requested your review to
deploy to prod"* og knappen **Review deployments**. Godkjent via
"Approve and deploy". Total varighet 4m 29s (2m 0s faktisk kjøretid etter
godkjenning, resten ventetid). Alle tre – `dev ←`, `test ←`, `prod ←` – viste
identisk SHA (`7344e7059837faa654d7d58107b77c4270cbae19`) i Actions-lista.

---

## Steg 7 – Hele runden, på egen hånd

Reell endring: ny tag i `local.tags` i `oving6/stacks/network/main.tf`:

```hcl
  tags = {
    environment = var.environment
    owner       = var.owner
    project     = var.project_name
    stack       = "network"
    managedby   = "terraform"
    kurs        = "dcst3005"
  }
```

```bash
git switch -c steg-7-full-runde
git add oving6/stacks/network/main.tf
git commit -m "Steg 7: full runde - ny tag"
git push -u origin steg-7-full-runde
gh pr create --base main --fill
```

**PR #8**. Plan-kommentaren viste:

```
Plan: 0 to add, 3 to change, 0 to destroy.
```

(oppdatering av tags på tre eksisterende ressurser – `azurerm_resource_group.rg`,
`azurerm_network_security_group.main`, `azurerm_virtual_network.main` – ingen
opprettelse eller sletting). Ressursene var denne gangen korrekt navngitt
`rg-nett-oving6-dev-kd` / `vnet-oving6-dev-kd` / `nsg-oving6-dev-kd`, etter
isolasjonsfiksen i PR #7.

### Tabell – én endring, hele veien til prod

| Felt | Verdi |
|---|---|
| Grennavn | `steg-7-full-runde` |
| PR-nummer | #8 |
| `Plan:`-linje | `Plan: 0 to add, 3 to change, 0 to destroy.` |
| SHA etter merge | `d41c9857e775525aa4facb813779a6e28bbd6b57` |
| SHA i CD dev | `d41c9857e775525aa4facb813779a6e28bbd6b57` |
| SHA i CD test | `d41c9857e775525aa4facb813779a6e28bbd6b57` |
| SHA i CD prod | `d41c9857e775525aa4facb813779a6e28bbd6b57` |
| Hvem godkjente prod, og når | KhalilElDeek, ~1 minutt etter trigger |

CD dev: Success, 1m 13s. CD test: Success, 2m 20s (manuelt trigget med samme
SHA). CD prod: Waiting → Review pending deployments → Approve and deploy →
Success, 1m 34s kjøretid. Deployment protection rules-panelet på kjøringen
viste direkte: *"KhalilElDeek approved 1 minute ago — prod"*.

Alle fire SHA-er identiske. Dette er selve beviset oppgaven ber om: det som
flyttes fra miljø til miljø er én commit-SHA, flyttet manuelt av meg – ikke
en ny utrulling av "det nyeste på main" i hvert miljø.

---

## Steg 8 – Rydd opp

Egen workflow laget for øving6 (øving5 sin `riv-ned-nettverk.yml` kunne ikke
gjenbrukes direkte – den peker på øving5 sine egne stier og state-keys):

```yaml
name: Riv ned et miljø (oving6)

on:
  workflow_dispatch:
    inputs:
      environment:
        description: Miljø som skal rives ned
        type: choice
        options: [dev, test, prod]
        required: true
      bekreftelse:
        description: 'Skriv "riv ned <miljø>" for å bekrefte'
        type: string
        required: true

permissions:
  id-token: write
  contents: read

concurrency:
  group: oving6-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  bekreft:
    runs-on: ubuntu-latest
    steps:
      - name: Sjekk bekreftelsen
        env:
          BEKREFTELSE: ${{ inputs.bekreftelse }}
          MILJO: ${{ inputs.environment }}
        run: |
          if [ "$BEKREFTELSE" != "riv ned $MILJO" ]; then
            echo "::error::Ikke bekreftet. Forventet nøyaktig: riv ned $MILJO"
            exit 1
          fi
          echo "Bekreftet."

  riv-ned:
    needs: bekreft
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    defaults:
      run:
        working-directory: oving6/stacks/network

    env:
      MILJO: ${{ inputs.environment }}

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false
      - uses: Azure/login@v3.1.0
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Hent parameterfila fra Key Vault
        run: |
          az keyvault secret show \
            --vault-name "${{ secrets.KEYVAULT_NAME }}" \
            --name "tfvars-$MILJO" \
            --query value -o tsv > params.auto.tfvars

      - name: Init
        run: |
          if [ "$MILJO" = "prod" ]; then
            KEY="env/prod/network.tfstate"
          else
            KEY="env/$MILJO/oving6-network.tfstate"
          fi
          terraform init \
            -backend-config="${{ github.workspace }}/oving6/shared/backend.hcl" \
            -backend-config="key=$KEY"

      - name: Lag en destroy-plan
        run: terraform plan -destroy -out=tfdestroy

      - name: Utfør destroy-planen
        run: terraform apply tfdestroy

      - name: Verifiser at det er tomt
        run: terraform state list

      - name: Slett parameterfila
        if: always()
        run: rm -f params.auto.tfvars
```

Kjørt tre ganger fra Actions-fanen:

- **#1** – `environment: dev`, bekreftelse `riv ned dev` → Success, 2m 29s
- **#2** – `environment: test`, bekreftelse `riv ned test` → Success, 2m 31s
- **#3** – `environment: prod`, bekreftelse `riv ned prod` → krevde godkjenning
  (samme port som utrulling), godkjent, Success, 8m 50s

Alle tre grønne, `terraform state list` tom etter hver kjøring. `CD dev`
deaktivert i Actions-fanen (`···` → Disable workflow) etterpå, slik at en
tilfeldig fremtidig push ikke ruller ut dev på nytt. Branch protection,
`prod`/`dev`/`test`-environmentene, backend-bootstrap og Key Vault står
fortsatt – uberørt, slik oppgaven ber om.

---

## Steg 9 – Refleksjon

*(Frivillig, ikke en del av innleveringskravet for denne enkle versjonen –
notert her kun til eget bruk før eksamen/modul 7.)*

**Håndhevet vs. bare fulgt selv.** GitHub håndhever to ting direkte: at
`main` ikke kan endres uten en pull request (Ruleset, bekreftet med
`GH013`-feilen), og at `prod` ikke kan rulles ut uten en godkjenning fra en
reviewer (Required reviewers, bekreftet med "Waiting"-tilstanden). Det jeg
bare følger selv, er selve *disiplinen* i å kopiere riktig SHA fra riktig
kjøring inn i `CD test`/`CD prod` – ingenting i oppsettet hindrer meg i å
lime inn feil SHA, så lenge den finnes på `main` (`git merge-base
--is-ancestor` sjekker bare at commiten er merget, ikke at den er *den
riktige* commiten jeg mente å teste).

**Promotering.** Hadde `test`/`prod` i stedet hentet "det nyeste på main",
ville et kappløp vært mulig: noen (eller jeg selv) kunne rukket å merge noe
nytt mellom at `dev` ble bekreftet og `test` ble trigget, og `test` ville da
testet kode som aldri gikk gjennom `dev`. Ved å sende én eksplisitt SHA
videre, er det garantert at alle tre miljøene kjører byte-for-byte samme
kode.

**Hva jeg godkjente.** I denne enkle versjonen lages prod-planen *inni* den
samme jobben som også krever godkjenning (`environment: prod` på hele
`rull-ut`-jobben) – så prod-planen fantes ikke før jeg hadde trykket
"Approve and deploy". Det jeg faktisk godkjente var en SHA jeg hadde sett
virke i `dev` og `test`, ikke en lest plan for `prod` spesifikt. Skulle jeg
sett planen før godkjenning, måtte `cd-prod.yml` vært delt i to jobber (plan
og apply) med et eget `prod-plan`-environment uten port for plan-jobben –
akkurat det "Vil du videre"-delen av oppgaven (og den fulle versjonen av
Oppgave 6) beskriver.

**0 påkrevde godkjenninger på PR-nivå.** Ingen andre enn meg selv har lest
koden før merge (`Required approvals: 0`, fordi jeg er alene i repoet).
Dette ligner mer på arbeidsformen der forfatteren selv har fullt ansvar og
tillit (push-til-main-stilen, bare med et sikkerhetsnett av automatiserte
sjekker i stedet for et menneske), snarere enn code review-arbeidsformen fra
kapittel 15 der en annen person må godkjenne innholdet før det når `main`.
