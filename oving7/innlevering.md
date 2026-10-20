# Oppgave 7 – Testing av infrastrukturkode

Bygger videre på øving 6: koden i `oving7/stacks/network/` og
`oving7/modules/network/` er kopiert derfra. Ruller ikke ut noe i Azure –
alt frem til og med S5 kjører offline, ingen `Azure/login`, ingen kostnad.

---

## Del 0 – Oppsett

### Mappestruktur

```bash
mkdir -p oving7/stacks/network oving7/modules oving7/scripts
cp -r oving6/modules/network oving7/modules/network
cp -r oving6/stacks/network/* oving7/stacks/network/
```

### Verktøy installert

```bash
terraform version
tflint --version
checkov --version
```

```
Terraform v1.16.1
TFLint version 0.64.0
+ ruleset.terraform (0.15.0-bundled)
3.3.21
```

**Reelle installasjonsproblemer underveis:**
- `brew install tflint` feilet (`No available formula with the name "tflint"`)
  – TFLint ligger ikke lenger i `homebrew-core` under det navnet. Løst med
  den offisielle tappen: `brew install terraform-linters/tap/tflint`.
- `pip3 install checkov==3.3.21` feilet med `externally-managed-environment`
  (PEP 668 – macOS/Homebrew Python tillater ikke system-wide pip-installer
  lenger). Løst med `pipx`.
- `pipx install checkov` installerte, men `checkov --version` feilet med
  `bad interpreter: /Users/khalil/Library/Application: no such file or
  directory` – mellomrommet i `~/Library/Application Support/` ødela
  shebang-linja pipx skrev. Løst ved å flytte pipx sin lagringsplass til en
  sti uten mellomrom:

```bash
pipx uninstall checkov
echo 'export PIPX_HOME="$HOME/.pipx"' >> ~/.zshrc
echo 'export PIPX_BIN_DIR="$HOME/.local/bin"' >> ~/.zshrc
source ~/.zshrc
pipx install checkov==3.3.21
checkov --version
```

---

## S1 – TFLint lokalt, med egne regler

### `oving7/.tflint.hcl`

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
```

### Første kjøring – ekte funn

```bash
cd oving7
tflint --init
tflint --recursive --config "$(pwd)/.tflint.hcl"
```

```
6 issue(s) found:

Warning: terraform "required_version" attribute is required (terraform_required_version)
  on modules/network/main.tf line 1

Notice: `vnet_id` output has no description (terraform_documented_outputs)
  on modules/network/outputs.tf line 1

Notice: `vnet_name` output has no description (terraform_documented_outputs)
  on modules/network/outputs.tf line 5

Notice: `resource_group_name` output has no description (terraform_documented_outputs)
  on stacks/network/outputs.tf line 1

Notice: `vnet_name` output has no description (terraform_documented_outputs)
  on stacks/network/outputs.tf line 5

Notice: `subnet_ids` output has no description (terraform_documented_outputs)
  on stacks/network/outputs.tf line 9
```

### Punkt 3 – test at reglene faktisk virker (camelCase-brudd)

```bash
sed -i '' 's/variable "vnet_cidr"/variable "vnetCidr"/' stacks/network/variables.tf
tflint --recursive --config "$(pwd)/.tflint.hcl"
```

Første forsøk feilet rett og slett fordi bare variabel*deklarasjonen* ble
endret, ikke referansene til den (`var.vnet_cidr` i `main.tf`), noe som gjorde
at Terraform selv (ikke TFLint) ikke klarte å løse opp konfigurasjonen:

```
Error: Reference to undeclared input variable
  on stacks/network/main.tf line 28, in module "network":
  28:   vnet_cidr = var.vnet_cidr
An input variable with the name "vnet_cidr" has not been declared. Did you mean "vnetCidr"?
```

Rettet ved å oppdatere referansen også:

```bash
sed -i '' 's/var\.vnet_cidr/var.vnetCidr/g' stacks/network/main.tf
tflint --recursive --config "$(pwd)/.tflint.hcl"
```

```
7 issue(s) found:
...
Notice: variable name `vnetCidr` must match the following format: snake_case (terraform_naming_convention)
  on stacks/network/variables.tf line 27
```

Reglene virker – det nye funnet (naming convention) dukket opp i tillegg til
de 6 opprinnelige. Satt tilbake:

```bash
sed -i '' 's/variable "vnetCidr"/variable "vnet_cidr"/' stacks/network/variables.tf
sed -i '' 's/var\.vnetCidr/var.vnet_cidr/g' stacks/network/main.tf
tflint --recursive --config "$(pwd)/.tflint.hcl"
# exit code: 0, 6 funn (tilbake til utgangspunktet)
```

### Punkt 4 – rett de ekte funnene

**Fiks 1 – `required_version` i `modules/network/main.tf`:**

```bash
sed -i '' 's/terraform {/terraform {\n  required_version = ">= 1.5.0"\n/' modules/network/main.tf
```

**Fiks 2–6 – manglende `description` på fem outputs.**

`modules/network/outputs.tf` (hadde alt description på `subnet_ids` og
`resource_group_name` – manglet bare på `vnet_id` og `vnet_name`):

```hcl
output "vnet_id" {
  description = "Ressurs-ID til virtual network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Navnet på virtual network."
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map: subnett-navn => subnett-ID"
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

output "resource_group_name" {
  value       = var.rg_name
  description = "Ressursgruppa (videreformidlet, til verifiseringssteg i workflowen)."
}
```

`stacks/network/outputs.tf`:

```hcl
output "resource_group_name" {
  description = "Ressursgruppa stacken opprettet."
  value       = azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "Navnet på virtual network, videreformidlet fra modulen."
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Map: subnett-navn => subnett-ID, videreformidlet fra modulen."
  value       = module.network.subnet_ids
}
```

### Sluttresultat

```bash
tflint --recursive --config "$(pwd)/.tflint.hcl"
echo "exit code: $?"
```

```
exit code: 0
```

Ingen funn, exit 0.

---

## S2 – Checkov lokalt, og et svar på hvert funn

### `oving7/.checkov.yaml`

```yaml
framework:
  - terraform
compact: true
quiet: true
```

### Første kjøring – før `.checkov.yaml` fantes, med standardinnstillinger

```bash
checkov -d .
```

```
terraform scan results:

Passed checks: 5, Failed checks: 2, Skipped checks: 0

Check: CKV_AZURE_10: "Ensure that SSH access is restricted from the internet"
        FAILED for resource: module.network.azurerm_network_security_group.main
        File: /modules/network/main.tf:30-60
        Calling File: /stacks/network/main.tf:22-31

Check: CKV_AZURE_160: "Ensure that HTTP (port 80) access is restricted from the internet"
        FAILED for resource: module.network.azurerm_network_security_group.main
        File: /modules/network/main.tf:30-60
        Calling File: /stacks/network/main.tf:22-31
```

To ekte, pre-eksisterende funn i NSG-en: SSH (port 22) og HTTP (port 80) åpne
fra `*`. Ingen ressurs i stacken trenger offentlig inngående tilgang ennå –
begge rettet, ikke unntatt, ved å fjerne begge `security_rule`-blokkene helt:

```hcl
# Ingen inbound-regler fra internett: ingenting i denne stacken trenger det
# ennå. Azure NSG-er denyer alt inbound som standard når ingen regel tillater
# det - en tom NSG her er derfor et bevisst, sikkert utgangspunkt, ikke en
# forglemmelse.
resource "azurerm_network_security_group" "main" {
  name                = lower(format("nsg-%s", var.base_name))
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}
```

### Etter retting

```bash
checkov -d .
```

```
Passed checks: 7, Failed checks: 0, Skipped checks: 0
```

### Punkt 3 – plant SSH-regelen igjen, bekreft `Calling File`

SSH-regelen lagt midlertidig tilbake i NSG-blokken:

```bash
checkov -d .
```

```
Passed checks: 6, Failed checks: 1, Skipped checks: 0

Check: CKV_AZURE_10: "Ensure that SSH access is restricted from the internet"
        FAILED for resource: module.network.azurerm_network_security_group.main
        File: /modules/network/main.tf:34-52
        Calling File: /stacks/network/main.tf:22-31
```

`Calling File` viser linja i stacken der modulen faktisk kalles – ikke der
selve ressursen er definert. Nyttig for å spore funn tilbake til riktig
instansiering når samme modul brukes flere steder.

### Fjernet igjen, bekreftet rent

```bash
checkov -d .
```

```
Passed checks: 7, Failed checks: 0, Skipped checks: 0
```

### S2-tabellen

| ID | Ressurs | Rettet eller unntak? | Begrunnelse |
|---|---|---|---|
| CKV_AZURE_10 | NSG i `modules/network` | Rettet | Fjernet SSH-inbound-regelen helt – ingen ressurs i stacken trenger offentlig tilgang på port 22 ennå, og Azure NSG-er denyer alt som standard uten en eksplisitt allow-regel. |
| CKV_AZURE_160 | NSG i `modules/network` | Rettet | Samme begrunnelse, for HTTP (port 80). |

(Ingen "unntak"-rader her, siden øving7s scope kun er nettverksstacken, ikke
hele `backend-bootstrap/`-treet referanseløsningens egen tabell dekker.)

---

## S3 – Ett skript som kjører alt

### `oving7/scripts/valider.sh`

```bash
#!/usr/bin/env bash
# valider.sh - kjører fmt, validate, TFLint og Checkov. Ingen "set -e": alle
# kontrollene kjøres selv om en tidligere feiler, slik at du ser ALLE feilene
# i én kjøring i stedet for å rette én om gangen.

set -u

cd "$(dirname "$0")/.."

TERRAFORM_MAPPER=(
  "stacks/network"
  "modules/network"
)

FEILET=()

echo "== terraform fmt -check =="
if ! terraform fmt -check -recursive; then
  FEILET+=("fmt")
fi

for mappe in "${TERRAFORM_MAPPER[@]}"; do
  echo "== terraform validate ($mappe) =="
  (
    cd "$mappe" || exit 1
    terraform init -backend=false -input=false >/dev/null 2>&1
    terraform validate
  )
  if [ $? -ne 0 ]; then
    FEILET+=("validate:$mappe")
  fi
done

echo "== TFLint =="
tflint --init >/dev/null 2>&1
if ! tflint --recursive --config "$(pwd)/.tflint.hcl"; then
  FEILET+=("tflint")
fi

echo "== Checkov =="
if ! checkov -d .; then
  FEILET+=("checkov")
fi

echo
if [ ${#FEILET[@]} -eq 0 ]; then
  echo "Alle kontrollene er grønne."
  exit 0
else
  echo "Feilet: ${FEILET[*]}"
  exit 1
fi
```

```bash
chmod +x scripts/valider.sh
```

### `.gitattributes` i rota av repoet

```bash
cd ..
cat > .gitattributes << 'EOF'
*.sh text eol=lf
EOF
cd oving7
```

### Første kjøring, alt grønt

```bash
cd ..
bash oving7/scripts/valider.sh
```

```
== terraform fmt -check ==
== terraform validate (stacks/network) ==
Success! The configuration is valid.
== terraform validate (modules/network) ==
Success! The configuration is valid.
== TFLint ==
== Checkov ==
Passed checks: 7, Failed checks: 0, Skipped checks: 0

Alle kontrollene er grønne.
```

### Punkt 4 – to feil samtidig (formatering + Checkov)

Plantet feil innrykk på `tags`-linja OG SSH-regelen samtidig, kjørte
skriptet én gang:

```bash
bash oving7/scripts/valider.sh
```

```
== terraform fmt -check ==
modules/network/main.tf
== terraform validate (stacks/network) ==
Success! The configuration is valid.
== terraform validate (modules/network) ==
Success! The configuration is valid.
== TFLint ==
== Checkov ==
Passed checks: 6, Failed checks: 1, Skipped checks: 0

Check: CKV_AZURE_10: "Ensure that SSH access is restricted from the internet"
...

Feilet: fmt checkov
```

Begge feilene vist i samme kjøring, nettopp fordi skriptet ikke har
`set -e` – hadde det hatt det, ville det stoppet på `fmt` og aldri vist
Checkov-funnet i samme kjøring.

### Begge feil fjernet, bekreftet rent igjen

```bash
bash oving7/scripts/valider.sh
```

```
Passed checks: 7, Failed checks: 0, Skipped checks: 0

Alle kontrollene er grønne.
```

---

## S4 – Porten

Egen workflow laget for øving7 (ikke lagt inn i øving6s `ci.yml`, siden
øving6s egen `plan-dev`-jobb fortsatt lever som historikk):

### `.github/workflows/ci-oving7.yml`

```yaml
name: CI (oving7)

on:
  pull_request:
    branches: [main]
    paths:
      - 'oving7/**'
      - '.github/workflows/ci-oving7.yml'

permissions:
  contents: read

jobs:
  kontroll:
    name: kodekontroll
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Installer TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.64.0

      - name: Installer Checkov
        run: pip install checkov==3.3.21

      - name: Kjør valider.sh
        run: bash oving7/scripts/valider.sh
```

Job-ID-en er fortsatt `kontroll` (som S4 ber om), men `name:` er
`kodekontroll` – det er navnet som vises som status-sjekk.

```bash
git switch -c steg-s1-s4-oving7
git add oving7/ .gitattributes .github/workflows/ci-oving7.yml
git commit -m "S1-S4: TFLint, Checkov, valider.sh og kodekontroll-port for oving7"
git push -u origin steg-s1-s4-oving7
gh pr create --base main --fill
```

**PR #11** – `kodekontroll` grønn, 45–46s. Merget.

### Reelt avvik: `kodekontroll` ble aldri lagt til som påkrevd sjekk først

Etter første merge trodde vi branch protection ("Do not allow bypassing")
stoppet merge på en etterfølgende rød PR, fordi Merge-knappen virket grå –
men den var faktisk fortsatt klikkbar, og en test-PR (#12) ble merget inn med
en SSH-regel og et tomt `checkov:skip`-unntak uten at noen reell sperre
stoppet det. Årsaken: `CI (oving7) / kodekontroll` var aldri lagt til i
Ruleset-ets "Required status checks" – bare øving6s `fmt og validate` og
`plan mot dev` sto der.

**Rettet i to steg:**

1. Reverterte/fjernet den feilaktig mergede SSH-regelen (PR #13):
   ```bash
   git switch -c fix-revert-s5-merge
   # (SSH-regelen fjernet manuelt i samme stil som S2-rettingen)
   git commit -m "fix: fjern SSH-regel og tomt checkov:skip-unntak fra S5-testen"
   git push
   gh pr create --base main --fill
   ```
2. La til `kodekontroll` i Settings → Rulesets → `protect-main` → Required
   status checks → Add checks. Listen viser nå alle tre: `fmt og validate`,
   `plan mot dev`, `kodekontroll`.

Dette er selve beviset for S4s "Hva skjedde?"-avsnitt, bare på hardveien:
porten gjør ingenting før den faktisk er lagt til som en påkrevd sjekk – en
grå knapp er ikke det samme som en håndhevet sperre.

---

## S5 – Prøv å lure porten

(Kjørt på nytt, `steg-5-lure-porten-v2`, etter at `kodekontroll` faktisk var
en håndhevet, påkrevd sjekk.)

### Punkt 1–2 – planter SSH-regelen, pusher uten å kjøre lokalt

```bash
git switch -c steg-5-lure-porten-v2
# SSH-regelen satt tilbake i modules/network/main.tf
git add oving7/modules/network/main.tf
git commit -m "S5: SSH-regel plantet, ikke kjort lokalt (v2)"
git push -u origin steg-5-lure-porten-v2
gh pr create --base main --fill
```

**PR #14** – `kodekontroll` feilet etter 43s. Merge-knappen genuint sperret
denne gangen, med tooltip:

> **Merging is blocked due to failing merge requirements**

Skjermbilde viser: `CI (oving7) / kodekontroll` rødt og merket **Required**,
`fmt og validate` og `plan mot dev` grønne, Merge-knappen grå og
ikke-klikkbar med forklaringsteksten synlig.

### Punkt 3 – unntak uten begrunnelse

```bash
#checkov:skip=CKV_AZURE_10:
  security_rule {
    name                       = "AllowSSH"
    ...
  }
```

```bash
git add oving7/modules/network/main.tf
git commit -m "S5: checkov:skip uten begrunnelse"
git push
```

**Sjekk:** `kodekontroll` gikk grønt, 40s. Alle tre påkrevde sjekker grønne,
Merge-knappen aktiv igjen.

### Punkt 4–5 – lukk uten å merge

```bash
gh pr close 14
git switch main
git branch -D steg-5-lure-porten-v2
git push origin --delete steg-5-lure-porten-v2
```

### Svar på spørsmålene i S5

**Hvilken farge fikk kontrollen etter punkt 3?** Grønn – til tross for at
unntaket ikke har noen begrunnelse (teksten etter andre kolon er tom).

**Hvilken avkrysning ville gjort at det andre forsøket (å merge med rød
kontroll) lyktes, og hvorfor er det viktig at den gjelder deg som eier
repoet også?** Dersom "Required status checks" ikke hadde inneholdt
`kodekontroll` i det hele tatt (noe som faktisk skjedde i den første
runden, se avviket over) – da er det ikke en avkrysning som svikter, men
fraværet av én. Hadde en slik avkrysning i stedet vært et eksplisitt
"bypass for administrators"-unntak og den var på, ville jeg som repo-eier
kunnet trykke meg forbi en rød kontroll, selv om alle andre ble stoppet. Det
er viktig at sperren også gjelder eieren, fordi eieren er den personen med
mest tilgang og minst ekstern kontroll – en sperre som bare gjelder andre,
beskytter ikke mot feil eieren selv gjør under tidspress.

---

## S6 – Refleksjon


**1. Ett unntak fra S2-tabellen jeg ville rettet i et ekte produksjonsmiljø,
og hva det ville kostet.** Begge radene i tabellen ble faktisk rettet, ikke
unntatt – nettopp fordi scope her er en bar nettverksstack uten noe bak NSG-en
ennå. Men dersom jeg tenker meg videre, til når et faktisk VM eller en
database skal stå bak dette nettverket: å holde SSH stengt fra `*` slik jeg
gjorde nå, ville i et ekte miljø kostet meg at jeg må sette opp en Bastion-
tjeneste eller en VPN for å i det hele tatt nå maskinen for drift – et
engangsarbeid i oppsett, og en liten driftskostnad videre, men en kostnad jeg
uansett bør ta heller enn å la SSH stå åpent fra internett.

**2. `valider.sh` er grønt hos meg, men `kodekontroll` er rød på samme
commit – to mulige grunner, og hva jeg ville sjekket først.** (a) Verktøy-
versjonene er ulike: jeg kjører en annen TFLint- eller Checkov-versjon
lokalt enn det `ci-oving7.yml` installerer (`tflint_version: v0.64.0`,
`checkov==3.3.21`) – en nyere regel kan ha kommet til i en versjon jeg ikke
har oppdatert lokalt ennå. (b) Jeg kjørte skriptet fra feil mappe eller med
en gammel `.tflint.hcl`/`.checkov.yaml` i cache lokalt som ikke matcher det
som faktisk er committet. Det første jeg ville sjekket, er å diffe
verktøyversjonene (`terraform version`, `tflint --version`,
`checkov --version`) mot nøyaktig det `ci-oving7.yml` installerer, og
deretter kjøre `git status`/`git diff` for å være sikker på at det jeg
testet lokalt faktisk er det samme som ble pushet.

**3. Sveitserost – én risiko ved nettverksstacken min som ingen av
kontrollene fanger.** Ingen av de fire offline-kontrollene eller `plan` sjekker
om subnettene faktisk har riktig *størrelse* for fremtidig vekst, eller om
CIDR-blokkene til dev/test/prod faktisk er ikke-overlappende hvis de en dag
skal peeres sammen. TFLint og Checkov ser på én fils statiske innhold, og
`plan` viser bare hva som vil skje med *denne* staten – ingen av dem
simulerer et scenario der to miljøer kobles sammen. Det er en type test jeg
ikke har: en **integrasjonstest** som faktisk ruller opp flere miljøer
samtidig og verifiserer at de kan snakke sammen uten adressekollisjon.
