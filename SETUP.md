# Configurazione Supabase (una volta sola, ~10 minuti)

## 1. Crea il progetto
1. Vai su https://supabase.com → **Start your project** → accedi con GitHub (o email).
2. **New project**: nome `scouting`, scegli una password per il database (salvala), regione **Central EU (Frankfurt)** o **West EU**.
3. Piano **Free**. Attendi un paio di minuti che il progetto sia pronto.

## 2. Crea le tabelle
1. Menu a sinistra → **SQL Editor** → **New query**.
2. Incolla tutto il contenuto di `supabase-setup.sql` → **Run**.

## 3. Blocca le registrazioni libere
**Authentication → Sign In / Providers** (o *Settings*): disattiva **Allow new users to sign up**.
Così può entrare solo chi crei tu.

## 4. Crea i 4 utenti
Gli accessi si fanno con **nome utente + password** (niente email personali).
Ogni nome utente in Supabase va scritto come `nomeutente@scouting.example.com`
(dominio riservato: nessuna email viene mai inviata). Nell'app si digita solo `nomeutente`.

**Authentication → Users → Add user → Create new user**, per ognuno:
| Nell'app si digita | Email da inserire in Supabase |
|---|---|
| `scout` | `scout@scouting.example.com` |
| `presidente` | `presidente@scouting.example.com` |
| `direttore` | `direttore@scouting.example.com` |
| `allenatore` | `allenatore@scouting.example.com` |

Scegli una password per ognuno e spunta **Auto Confirm User**.

## 5. Imposta ruoli e nomi
Torna in **SQL Editor** ed esegui:
```sql
update public.profili set ruolo = 'scout', nome = 'Nome Cognome scout' where email = 'scout@scouting.example.com';
update public.profili set nome = 'Presidente'          where email = 'presidente@scouting.example.com';
update public.profili set nome = 'Direttore sportivo'  where email = 'direttore@scouting.example.com';
update public.profili set nome = 'Allenatore'          where email = 'allenatore@scouting.example.com';
```
- `scout` = inserisce, modifica, elimina, commenta
- `staff` (predefinito) = consulta tutto, esporta PDF, commenta
- Il **nome** è quello che compare sotto i commenti.

## 6. Collega l'app
**Project Settings → API Keys** (o il pulsante **Connect**): copia
- **Project URL** (es. `https://abcdxyz.supabase.co`)
- **Publishable key** (`sb_publishable_...`) — oppure la *anon public* key

Mettile in cima allo script di `index.html`:
```js
const SUPABASE_URL='https://abcdxyz.supabase.co';
const SUPABASE_KEY='sb_publishable_...';
```
Fai commit: dopo 1–2 minuti l'app su GitHub Pages è collegata.
La chiave "publishable" è pensata per stare nel browser: i dati sono protetti dal login e dalle regole del database.
**Non usare mai la "secret" / "service_role" key nell'app.**

## 7. Keep-alive
Il file `.github/workflows/keep-alive.yml` interroga il database ogni 3 giorni, così il progetto gratuito non va in pausa.
Puoi provarlo da **GitHub → Actions → Supabase keep-alive → Run workflow**.
Nota: GitHub disattiva i job programmati nei repo senza commit da 60 giorni (manda una email): basta riattivarlo dalla scheda Actions.

## Gestione utenti in futuro
- Nuovo utente: ripeti i passi 4 e 5.
- Togliere l'accesso: Authentication → Users → elimina l'utente.
- Password dimenticata: non c'è recupero via email. Authentication → Users → utente → imposta una nuova password e comunicala.
