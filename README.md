# OpenClaw + Claude Code CLI Template

Template Docker pour utiliser **OpenClaw** (anciennement Clawdbot) avec votre **abonnement Claude Code CLI** au lieu de payer des crédits API.

## TL;DR - Démarrage en 30 secondes

```bash
git clone https://github.com/kevin-ghfr/openclaw-claude-code-template.git
cd openclaw-claude-code-template
cp .env.example .env
# Éditer .env et mettre votre token (obtenu via: claude setup-token)
docker compose up -d
```

Votre API est prête sur `http://localhost:18789` !

## Contexte

### Le problème

Le token OAuth Claude Code (`sk-ant-oat01-...`) obtenu via `claude setup-token` :
- **Ne peut PAS** être utilisé directement avec l'API Anthropic
- **DOIT** passer par Claude Code CLI qui est installé sur votre machine

### L'historique

| Version | Sync Claude CLI | Statut |
|---------|-----------------|--------|
| **Clawdbot <= 2026.1.24** | Automatique (natif) | Fonctionnait |
| **OpenClaw >= 2026.2.0** | **Supprimé** | Ne fonctionne plus nativement |

Les mainteneurs d'OpenClaw ont **intentionnellement supprimé** la synchronisation automatique des credentials Claude Code CLI dans la version 2026.2+. Le profil `anthropic:claude-cli` est désormais marqué comme "deprecated".

### Notre solution

Ce template **contourne** cette limitation en créant manuellement le fichier `auth-profiles.json` que OpenClaw utilise pour s'authentifier.

---

## Prérequis

1. **Token OAuth Claude Code CLI** (validité : **1 an**)
   ```bash
   # Installer Claude Code CLI
   npm install -g @anthropic-ai/claude-code

   # Obtenir le token (ouvre le navigateur pour OAuth)
   claude setup-token

   # Le token s'affiche : sk-ant-oat01-...
   # Copiez-le !
   ```

2. **Docker** installé sur votre machine

---

## Démarrage rapide

### 1. Cloner le repo

```bash
git clone https://github.com/kevin-ghfr/openclaw-claude-code-template.git
cd openclaw-claude-code-template
```

### 2. Configurer le token

**C'est tout ce qu'il y a à faire :**

```bash
# Copier le template
cp .env.example .env

# Éditer et remplacer VOTRE_TOKEN_ICI par votre token
nano .env   # ou vim, code, etc.
```

Le fichier `.env` doit contenir :
```env
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-xxxxxxxxxxxxx
```

> **Note :** Le `.env` est ignoré par git (listé dans `.gitignore`), vos credentials restent privés.

### 3. Démarrer

```bash
docker compose up -d
```

C'est prêt ! L'API est accessible sur `http://localhost:18789`.

### 4. Tester

```bash
# Récupérer le token gateway (généré automatiquement)
GATEWAY_TOKEN=$(docker exec openclaw cat /home/node/.openclaw/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin)['gateway']['auth']['token'])")

# Tester l'API
curl -X POST http://localhost:18789/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -d '{"model":"default","messages":[{"role":"user","content":"Bonjour!"}]}'
```

Réponse attendue :
```json
{"id":"chatcmpl_...","choices":[{"message":{"content":"Bonjour ! Comment puis-je vous aider ?"}}]}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      DOCKER CONTAINER                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐      ┌─────────────────────────────┐  │
│  │  OpenClaw       │      │  Claude Code CLI            │  │
│  │  Gateway        │ ───► │  (@anthropic-ai/claude-code)│  │
│  │  :18789         │      │                             │  │
│  └─────────────────┘      └──────────────┬──────────────┘  │
│                                          │                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ~/.openclaw/agents/main/agent/auth-profiles.json   │   │
│  │  (créé par notre entrypoint)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                          │                  │
└──────────────────────────────────────────┼──────────────────┘
                                           │
                                           ▼
                              ┌─────────────────────────┐
                              │  API Claude (Anthropic) │
                              │  (utilise abonnement    │
                              │   Claude Code, pas API) │
                              └─────────────────────────┘
```

---

## Fichiers

| Fichier | Description |
|---------|-------------|
| `Dockerfile` | Image Docker avec OpenClaw officiel + Claude Code CLI |
| `entrypoint.sh` | Script qui configure les credentials et démarre le gateway |
| `docker-compose.yml` | Configuration Docker Compose |
| `.env.example` | Template des variables d'environnement |

---

## Comment ça fonctionne

### Le contournement

L'entrypoint fait ce que OpenClaw ne fait plus automatiquement :

1. **Crée** `~/.claude/.credentials.json` (format Claude Code CLI)
2. **Crée** `~/.openclaw/agents/main/agent/auth-profiles.json` (format OpenClaw)
3. **Configure** le gateway avec `bind: "lan"` pour accès externe
4. **Active** l'endpoint `/v1/chat/completions`
5. **Restaure** le auth-profiles.json si `openclaw doctor` le supprime

### Le fichier auth-profiles.json

```json
{
  "version": 1,
  "profiles": {
    "anthropic:claude-cli": {
      "type": "oauth",
      "provider": "anthropic",
      "access": "sk-ant-oat01-...",
      "refresh": "sk-ant-oat01-...",
      "expires": 4102444800000
    }
  },
  "lastGood": {
    "anthropic": "anthropic:claude-cli"
  }
}
```

Ce fichier est normalement créé par la fonction `syncExternalCliCredentials()` dans OpenClaw, mais cette fonction a été modifiée dans v2026.2+ pour ne plus synchroniser les credentials Claude CLI.

---

## Configuration avancée

### Variables d'environnement

| Variable | Requis | Description |
|----------|--------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Oui | Token OAuth Claude Code (sk-ant-oat01-...) |
| `OPENCLAW_CONFIG` | Non | Config JSON complète (remplace la config par défaut) |

### Config par défaut

Si `OPENCLAW_CONFIG` n'est pas défini, l'entrypoint génère cette config :

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/node/workspace",
      "model": {
        "primary": "anthropic/claude-opus-4-5"
      },
      "skipBootstrap": true
    }
  },
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "<généré aléatoirement>"
    },
    "http": {
      "endpoints": {
        "chatCompletions": {
          "enabled": true
        }
      }
    }
  }
}
```

### Changer le modèle

Modifier `OPENCLAW_CONFIG` pour utiliser un autre modèle :

```env
OPENCLAW_CONFIG={"agents":{"defaults":{"model":{"primary":"anthropic/claude-sonnet-4"}}},"gateway":{"mode":"local","bind":"lan","http":{"endpoints":{"chatCompletions":{"enabled":true}}}}}
```

---

## Obtenir le token OAuth (détails)

Le token OAuth Claude Code est **différent** d'une clé API Anthropic :

| Type | Format | Durée | Usage |
|------|--------|-------|-------|
| Clé API | `sk-ant-api03-...` | Illimitée | API directe |
| Token OAuth | `sk-ant-oat01-...` | **1 an** | Claude Code CLI uniquement |

### Étapes pour obtenir le token

1. Installer Claude Code CLI :
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```

2. Lancer la commande :
   ```bash
   claude setup-token
   ```

3. Un navigateur s'ouvre pour l'authentification OAuth Anthropic

4. Après connexion, le token s'affiche dans le terminal :
   ```
   Your token is: sk-ant-oat01-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

5. **Copiez ce token** et utilisez-le comme `CLAUDE_CODE_OAUTH_TOKEN`

### Renouvellement

Le token expire après **1 an**. Pour le renouveler :
```bash
claude setup-token
```

---

## Dépannage

### "No API key found for provider anthropic"

Le fichier `auth-profiles.json` n'est pas créé ou a été supprimé par `openclaw doctor`.

**Solution :** Vérifiez que `CLAUDE_CODE_OAUTH_TOKEN` est défini dans `.env` et redémarrez le container.

### Gateway écoute sur 127.0.0.1 (non accessible)

La config n'a pas `"bind": "lan"`.

**Solution :** Utilisez la config par défaut ou ajoutez `"bind": "lan"` dans `OPENCLAW_CONFIG`.

### "Method Not Allowed" sur /v1/chat/completions

L'endpoint n'est pas activé.

**Solution :** Ajoutez dans la config :
```json
"http": {"endpoints": {"chatCompletions": {"enabled": true}}}
```

### "Deprecated external CLI auth profiles detected"

C'est normal. OpenClaw affiche ce message mais notre entrypoint restaure le profil après.

---

## Utiliser un fork stable (optionnel)

Par défaut, le Dockerfile installe OpenClaw via npm (`openclaw@latest`). Si vous préférez utiliser une version fixe/stable :

### Option 1 : Utiliser notre fork de référence

Modifiez le `Dockerfile` :

```dockerfile
# Remplacer :
RUN npm install -g openclaw@latest

# Par :
RUN git clone --depth 1 https://github.com/kevin-ghfr/openclaw.git /opt/openclaw && \
    cd /opt/openclaw && npm install && npm install -g .
```

### Option 2 : Créer votre propre fork

1. Forkez [kevin-ghfr/openclaw](https://github.com/kevin-ghfr/openclaw) ou [l'officiel](https://github.com/clawdbot/clawdbot)
2. Modifiez le Dockerfile pour pointer vers votre fork

Cela vous permet de contrôler les mises à jour et d'éviter les breaking changes.

---

## Références

- [OpenClaw officiel](https://github.com/clawdbot/clawdbot) - Repo upstream
- [Fork de référence](https://github.com/kevin-ghfr/openclaw) - Fork stable pour ce template
- [Claude Code CLI](https://www.npmjs.com/package/@anthropic-ai/claude-code) - Package npm

---

## Licence

MIT
