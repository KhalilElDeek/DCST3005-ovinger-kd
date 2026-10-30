# Oving 9 — Modulmønstre og miljødesign

## Oversikt

Oving 9 bygger videre på `oving8/` sin struktur og Terraform-kode
(`modules/network` og `stacks/network`), kopiert inn i en ny, isolert
`oving9/`-mappe. Alle ressurser, state-filer, parameterfiler og workflows
er navngitt spesifikt for oving9, slik at ingenting overlapper med
tidligere øvinger.

**Repo:** `KhalilElDeek/DCST3005-ovinger-kd`
**Nye workflows laget for denne øvingen:**
- `.github/workflows/ci-oving9.yml`
- `.github/workflows/cd-dev-oving9.yml`
- `.github/workflows/cd-test-oving9.yml`
- `.github/workflows/cd-prod-oving9.yml`
- `.github/workflows/riv-ned-oving9.yml`

**Key Vault-secrets laget (gjenbruker eksisterende Key Vault `kv-tf-kdqp6uud`,
nye secret-navn):**
- `tfvars-oving9-dev`
- `tfvars-oving9-test`
- `tfvars-oving9-prod`

**Branch protection:** Required status checks for `main` ble utvidet med
`fmt og validate (oving9)` og `plan mot dev (oving9)`, mens de tilsvarende
oving6/oving7-sjekkene ble fjernet fra required-listen (de testet uansett
ikke oving9-koden).

---

## S1 — Sett navn på modulen din

**Filer lest:** `oving9/modules/network/*.tf`, `oving9/stacks/network/main.tf`

### 1. Hvilket mønster passer best på modulen?

`modules/network` er en **Bundle Module**. Den lager fire ressurstyper –
`azurerm_virtual_network`, `azurerm_subnet`, `azurerm_network_security_group`
og `azurerm_subnet_network_security_group_association` – bak et grensesnitt
på fem variabler (`rg_name`, `location`, `base_name`, `vnet_cidr`, `subnets`,
`tags`). Kunnskapen om hvordan ressursene henger sammen ligger inne i
modulen: `for_each = var.subnets` bygger subnettene fra ett map,
`cidrsubnet(var.vnet_cidr, 8, each.value)` regner ut adressene automatisk,
og `for_each = azurerm_subnet.main` kobler hvert subnett til NSG-en uten at
den som kaller må holde styr på det selv.

### 2. Er modulen Unshared? Forsvarlig?

Ja. Modulen kalles kun fra ett sted: `module "nett"` i
`stacks/network/main.tf`. Dev, test og prod er tre instanser av den samme
stacken (tre `tfvars`-sett i Key Vault), ikke tre ulike brukere av modulen —
det ville vært akkurat like mange kall til modulen om vi bare hadde hatt ett
miljø.

Forsvarlig: den gir en ekte abstraksjon ("et nettverk med disse
subnettene"), stacken blir lettere å lese, og S2–S4 har vist at
versjonering med Git-tags fungerer helt uavhengig av om modulen faktisk er
delt med noen. Alternativt kunne alt stått direkte i
`stacks/network/main.tf` uten `module.nett.`-prefiks — det hadde vært like
gyldig siden ingen andre bruker den ennå (rule of three: vi har én bruker,
ikke tre).

### 3. Varselsignal å se etter først

`var.environment == "prod"` (eller et annet miljønavn) inne i
`modules/network/`. I dag finnes det ikke — `variables.tf` har ingen
`environment`-variabel, og modulen vet ingenting om hvilket miljø den
kjører i. Den dagen noen ber om en slik betingelse inne i modulen, er det
tegnet på at modulen er på vei fra Bundle til Spaghetti, og verdien burde
heller sendes inn som data (f.eks. en liste av tillatte CIDR-er), ikke som
et miljønavn modulen selv tolker.

---

## S2 — Tagg modulen

```bash
git switch main
git pull
git tag -a network-v1.0.0 -m "network: første versjon (oving9)"
git push origin network-v1.0.0
```

> **Fallgruve underveis:** Taggen ble først satt på en commit *før*
> `oving9/`-mappa i det hele tatt eksisterte (merget inn i en senere PR).
> Dette ble oppdaget i S3 da `terraform init` feilet med
> `Failed to expand subdir globs: subdir "oving9/modules/network" not found`.
> Taggen ble slettet (`git tag -d` + `git push origin --delete`) og satt på
> nytt på riktig commit (etter at `oving9/`-strukturen var merget inn).
> Siden taggen aldri hadde blitt brukt av noen kjøring før feilen ble
> oppdaget, var dette trygt.

**Verifisering:**
```
$ git ls-remote --tags origin
72d74da...  refs/tags/network-v1.0.0
11c71d6...  refs/tags/network-v1.0.0^{}
```
SHA `11c71d6` matcher merge-commiten for PR #25 (oppsett av `oving9/`).

**Resultat:** Ingen ny workflow-kjøring ble trigget av taggen (en tag er
ikke en push til `main`), og taggen er synlig under GitHub → Code → Tags.

---

## S3 — Bytt stacken over til taggen

**Endring:** `oving9/stacks/network/main.tf`, `source`-linjen i
`module "nett"`:

```diff
- source = "../../modules/network"
+ source = "git::https://github.com/KhalilElDeek/DCST3005-ovinger-kd.git//oving9/modules/network?ref=network-v1.0.0"
```

**PR:** #26 — `oving9: hent modules/network fra Git-tag network-v1.0.0 i stedet for sti`

**Lokal verifisering før PR:**
```
$ terraform init -backend=false
Initializing modules...
Downloading git::https://github.com/KhalilElDeek/DCST3005-ovinger-kd.git?ref=network-v1.0.0 for nett...
...
Terraform has been successfully initialized!

$ terraform validate
Success! The configuration is valid.
```

**Plan-kommentar på PR #26** (`plan mot dev (oving9)`):
```
No changes. Your infrastructure matches the configuration.
```
Kun `main.tf` ble endret i PR-en — `.terraform.lock.hcl` er uendret, siden
den kun gjelder providers, ikke moduler.

**Etter merge:** `CD dev (oving9)` kjørte automatisk og bekreftet samme
`No changes`-resultat mot de faktiske dev-ressursene:
```
module.nett.azurerm_virtual_network.main: Refreshing state...
...
No changes. Your infrastructure matches the configuration.
```

**Promotering til test og prod** (samme SHA, `ddbb2fe3...`):
```
$ gh workflow run cd-test-oving9.yml -f sha=ddbb2fe3d4c107d9eb5a79515257240f04d9cbec
$ gh workflow run cd-prod-oving9.yml -f sha=ddbb2fe3d4c107d9eb5a79515257240f04d9cbec
```
Begge kjøringer fullførte med `Plan: 9 to add, 0 to change, 0 to destroy` og
`Apply complete! Resources: 9 added` — forventet, siden dette var første
gang oving9-ressurser ble opprettet i test og prod.

---

## S4 — Fella, og en ny modulversjon

### PR 1 — endre modulen (fella)

**Endring:** `oving9/modules/network/main.tf`, kun `azurerm_virtual_network`
sin `tags`-linje:
```diff
resource "azurerm_virtual_network" "main" {
  ...
- tags = var.tags
+ tags = merge(var.tags, { modul = "network" })
}
```
NSG-ressursens `tags = var.tags` ble bevisst **ikke** endret, i tråd med
pensum og løsningsforslaget.

**PR:** #27 — `oving9: legg til Azure-tag modul=network på vnet i modules/network`

**Plan-kommentar på PR #27:**
```
No changes. Your infrastructure matches the configuration.
```
Dette er selve "fella": endringen ligger i modulmappa på `main`, men
stacken henter fortsatt fra `?ref=network-v1.0.0` — et frosset
øyeblikksbilde fra *før* denne endringen. Merget uten at noen ressurs ble
rørt.

### Ny tag

```bash
git switch main
git pull
git tag -a network-v1.1.0 -m "network: tag modul=network på vnet"
git push origin network-v1.1.0
```
MINOR-bump: ny funksjonalitet (en ekstra Azure-tag), ingen variabel fjernet
eller endret, ingen ressurs rives.

### PR 2 — ta i bruk ny versjon

**Endring:** `oving9/stacks/network/main.tf`:
```diff
- source = "git::...?ref=network-v1.0.0"
+ source = "git::...?ref=network-v1.1.0"
```

**PR:** #28 — `oving9: oppgrader modules/network til network-v1.1.0`

**Plan-kommentar på PR #28:**
```
# module.nett.azurerm_virtual_network.main will be updated in-place
~ resource "azurerm_virtual_network" "main" {
      ~ tags = {
            "environment" = "dev"
            "kurs"        = "dcst3005"
            "managedby"   = "terraform"
          + "modul"       = "network"
            "owner"       = "kd"
            "project"     = "oving9"
            "stack"       = "network"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```
Kun vnet-et endres — NSG, subnett og NSG-koblinger er urørt.

**Promotering til test og prod,** deretter verifisert i Azure:
```
$ az network vnet show --resource-group rg-nett-oving9-prod-kd \
    --name vnet-oving9-prod-kd --query tags
{
  "environment": "prod",
  "kurs": "dcst3005",
  "managedby": "terraform",
  "modul": "network",
  "owner": "kd",
  "project": "oving9",
  "stack": "network"
}
```
Taggen har nådd prod gjennom build-once-promotering, drevet av at `?ref=`
står i stack-koden og dermed følger commiten gjennom dev → test → prod.

**Hvorfor MINOR og ikke PATCH eller MAJOR?** Grensesnittet
(`variables.tf`/`outputs.tf`) er uendret, så en stack som oppgraderer fra
`v1.0.0` til `v1.1.0` trenger ikke endre noe utover `?ref=`. Det er altså
ikke MAJOR. Men modulen gjør noe nytt som faktisk synes i Azure (en ny
tag) — det er ikke en feilretting, så det er ikke PATCH heller.

---

## S5 — Hva er ulikt mellom miljøene?

**Kilder undersøkt:** Key Vault-secrets (`tfvars-oving9-dev/test/prod`),
GitHub Environments (`dev`/`test`/`prod`), diff av
`cd-test-oving9.yml`/`cd-prod-oving9.yml`, og Actions-historikken.

| Forskjell | Hvor den er uttrykt | Villet? |
|---|---|---|
| `environment = dev / test / prod` | `tfvars-oving9-<miljø>` i Key Vault | Ja — navnene må være ulike, ellers kolliderer ressursnavnene |
| `vnet_cidr = 10.10 / 10.20 / 10.30.0.0/16` | `tfvars-oving9-<miljø>` i Key Vault | Ja — valgt så miljøene kan peeres uten overlapp |
| Required reviewers (KhalilElDeek) | GitHub Environment `prod` | Ja — bare prod skal kreve godkjenning. Dev og test har ingen reviewers |
| Deployment branches: kun `main` | GitHub Environment `prod` (dev/test: «No restriction») | Ja — prod kan bare rulles ut fra main |
| Hvordan utrullingen startes (push vs. manuell SHA) | `on:` i `cd-dev-oving9.yml` mot `cd-test/prod-oving9.yml` | Ja — det er veien til prod |
| State-fil og parameterfil-navn | `key=env/<miljø>/oving9-network.tfstate` og `tfvars-oving9-<miljø>` i workflowene | Ja — segregation, ikke variation, med samme logikk per miljø |
| "Allow administrators to bypass configured protection rules" er på i alle tre, inkludert prod | GitHub Environment-innstillinger (standardverdi) | **Ikke bevisst valgt** — en snikende forskjell fra det tiltenkte designet: godkjenningsporten på prod har et innebygd admin-unntak som aldri er vurdert eksplisitt |
| SHA kjørt i hvert miljø | Actions-historikken | Ikke en reell forskjell i oppsettet — alle tre står nå på samme SHA (`d616bc8a...`) etter S4 |

**Workflow-diff test vs. prod** (`cd-test-oving9.yml` mot
`cd-prod-oving9.yml`) viser kun navn, `concurrency.group`, `environment:`,
secret-navn og state-key som ulikt — selve rekkefølgen av steg
(checkout → login → hent parameterfil → init → plan → apply) er identisk.
Det er consistency, ikke en snikende forskjell.

---

## S6 — Refleksjon

**1. Hvem bestemmer når prod får en ny modulversjon, og hvor skjer det?**

Etter S3 ligger modulversjonen i `?ref=`-verdien inne i
`stacks/network/main.tf`. Det betyr at det ikke finnes noe eget "velg
modulversjon for prod"-steg — modulversjonen følger rett og slett den
samme SHA-en som promoteres gjennom `cd-test-oving9.yml` og
`cd-prod-oving9.yml`. Jeg opplevde dette konkret i S4: da jeg kjørte
`gh workflow run cd-prod-oving9.yml -f sha=d616bc8a...` og godkjente
jobben, var det ikke noe eget valg av "hvilken modul" — den fulgte
automatisk med fordi den lå i samme commit. Den som faktisk bestemmer er
altså den som trigger `cd-prod-oving9.yml` med riktig SHA og den som
godkjenner i required reviewers-steget. Det er samme build once-prinsipp
som gjaldt for selve stack-koden fra tidligere øvinger, bare at det nå
også gjelder hvilken modulversjon som er "frosset inn" i den commiten.

**2. Hva er likt i alle tre miljøer, men burde kanskje ikke vært det?**

To ting pekte seg ut da jeg gikk gjennom Environments-innstillingene:

For det første identiteten — alle tre miljøer bruker samme
`AZURE_CLIENT_ID`/`AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID` (synlig som
identiske secret-navn under dev, test og prod i skjermbildene). En
dev-jobb logger inn som nøyaktig samme Azure-identitet som en prod-jobb,
og har dermed i prinsippet samme rettigheter i Azure, selv om GitHub
Environment-reglene bestemmer *når* jobben får lov til å kjøre.

For det andre, noe jeg ikke hadde tenkt over før jeg faktisk åpnet
prod-environmentet: "Allow administrators to bypass configured protection
rules" sto avkrysset for prod også. Godkjenningsporten jeg satte opp
("Required reviewers: KhalilElDeek") har altså et innebygd unntak for
admin-brukere — noe som i praksis betyr at porten kan omgås av meg selv
uten at det var et bevisst designvalg, bare en standardinnstilling jeg
aldri hadde justert. Å stramme inn dette (fjerne bypass-muligheten, eller
gi dev/test/prod hver sin egne identitet med rettigheter begrenset til
egen ressursgruppe) ville kostet mer oppsett — egne app registrations,
egne rolletildelinger per ressursgruppe, og en bootstrap-stack som lager
ressursgruppene på forhånd siden nettverksstacken da ikke lenger kunne
lage sin egen gruppe med en bredt scopet identitet.

**3. En medstudent vil bruke `modules/network` i sin egen stack. Hva
svarer jeg?**

Jeg ville sagt nei, i hvert fall ikke ennå. Modulen har i dag akkurat én
bruker (`stacks/network/`, med tre miljø-instanser som alle teller som
samme bruker), og rule of three sier at man bør vente til man faktisk har
tre reelle brukere før man låser et grensesnitt man ikke har erfaring nok
til å vite er riktig. Jeg har allerede sett i S4 at selv en liten endring
(en ekstra tag) krever to PR-er og en ny tag for å nå stacken trygt — det
er overhead jeg ikke ville pålagt en medstudent uten god grunn. Hvis
behovet likevel var reelt og presserende, ville svaret vært ja, men da
måtte medstudentens stack: hente modulen via samme `git::...?ref=`-mønster
(aldri en sti, og aldri `?ref=main`), lage sin egen ressursgruppe og sende
`rg_name` inn selv (modulen lager den ikke), velge et `vnet_cidr` som ikke
overlapper med dev/test/prod sine 10.10/10.20/10.30-rom, og selv bumpe
`?ref=` når hun ønsker en nyere versjon — ikke få endringer dyttet på seg
automatisk slik en sti-referanse ville gjort.

---

## Oversikt over alle endrede/opprettede filer

### Terraform-kode (`oving9/`)
- `oving9/modules/network/main.tf` — opprettet (kopi fra oving8), senere
  endret i PR #27 (ny Azure-tag på vnet)
- `oving9/modules/network/variables.tf`, `outputs.tf`,
  `.terraform.lock.hcl` — opprettet (kopi fra oving8, uendret)
- `oving9/stacks/network/main.tf` — opprettet (kopi fra oving8), endret i
  PR #26 (Git-tag som source) og PR #28 (ny ref-versjon)
- `oving9/stacks/network/variables.tf`, `outputs.tf`, `versions.tf`,
  `.terraform.lock.hcl` — opprettet (kopi fra oving8, uendret)
- `oving9/shared/backend.hcl` — opprettet (kopi fra oving8, uendret)

### Workflows (`.github/workflows/`)
- `ci-oving9.yml`, `cd-dev-oving9.yml`, `cd-test-oving9.yml`,
  `cd-prod-oving9.yml`, `riv-ned-oving9.yml` — alle nye, bygget etter
  mønsteret fra `ci-oving6.yml`/`cd-*-oving8.yml`

### Key Vault
- `tfvars-oving9-dev`, `tfvars-oving9-test`, `tfvars-oving9-prod` —
  nye secrets i eksisterende Key Vault `kv-tf-kdqp6uud`

### Git-tags
- `network-v1.0.0` (satt på nytt etter en feilrettet tag-plassering)
- `network-v1.1.0`

### Pull requests
- #25 — oppsett av `oving9/`-struktur, workflows og branch protection-justering
- #26 — S3: bytt `source` til Git-tag `network-v1.0.0`
- #27 — S4 PR 1: ny Azure-tag i modulen
- #28 — S4 PR 2: oppgrader stacken til `network-v1.1.0`
