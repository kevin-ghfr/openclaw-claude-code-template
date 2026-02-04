#!/bin/bash
set -e

echo '=== OpenClaw + Claude Code CLI ==='

OPENCLAW_DIR="${HOME}/.openclaw"
CLAUDE_DIR="${HOME}/.claude"
WORKSPACE="${HOME}/workspace"
AUTH_PROFILES_DIR="${OPENCLAW_DIR}/agents/main/agent"

rm -f "${OPENCLAW_DIR}"/*.lock "${OPENCLAW_DIR}"/*.pid 2>/dev/null || true

mkdir -p "${OPENCLAW_DIR}"
mkdir -p "${OPENCLAW_DIR}/agents/main/sessions"
mkdir -p "${OPENCLAW_DIR}/agents/main/agent"
mkdir -p "${OPENCLAW_DIR}/credentials"
mkdir -p "${CLAUDE_DIR}"
mkdir -p "${WORKSPACE}"
chmod 700 "${OPENCLAW_DIR}" "${CLAUDE_DIR}"

echo '=== Configuration des credentials Claude Code ==='
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    # 1. Creer le fichier credentials Claude Code CLI
    cat > "${CLAUDE_DIR}/.credentials.json" << EOF
{
  "claudeAiOauth": {
    "accessToken": "${CLAUDE_CODE_OAUTH_TOKEN}",
    "expiresAt": 4102444800000,
    "refreshToken": "${CLAUDE_CODE_OAUTH_TOKEN}"
  }
}
EOF
    chmod 600 "${CLAUDE_DIR}/.credentials.json"
    echo "OK - Claude Code CLI credentials"

    # 2. Creer DIRECTEMENT le auth-profiles.json pour OpenClaw
    # (Contourne le sync automatique supprime dans v2026.2+)
    mkdir -p "${AUTH_PROFILES_DIR}"
    cat > "${AUTH_PROFILES_DIR}/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "anthropic:claude-cli": {
      "type": "oauth",
      "provider": "anthropic",
      "access": "${CLAUDE_CODE_OAUTH_TOKEN}",
      "refresh": "${CLAUDE_CODE_OAUTH_TOKEN}",
      "expires": 4102444800000
    }
  },
  "lastGood": {
    "anthropic": "anthropic:claude-cli"
  }
}
EOF
    chmod 600 "${AUTH_PROFILES_DIR}/auth-profiles.json"
    echo "OK - OpenClaw auth-profiles.json cree"
else
    echo "ERREUR: CLAUDE_CODE_OAUTH_TOKEN non defini!"
    exit 1
fi

echo '=== Configuration OpenClaw ==='
if [ -n "$OPENCLAW_CONFIG" ]; then
    echo "$OPENCLAW_CONFIG" > "${OPENCLAW_DIR}/openclaw.json"
else
    # Generer un token aleatoire pour le gateway auth
    GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    cat > "${OPENCLAW_DIR}/openclaw.json" << EOF
{
  "agents": {
    "defaults": {
      "workspace": "${WORKSPACE}",
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
      "token": "${GATEWAY_TOKEN}"
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
EOF
fi
chmod 600 "${OPENCLAW_DIR}/openclaw.json"

echo '=== Verification (doctor) ==='
# Doctor peut supprimer notre profil claude-cli (deprecie dans v2026.2+)
# On le restaure apres si necessaire
openclaw doctor 2>/dev/null || true

# Re-creer auth-profiles.json si doctor l'a supprime
if [ ! -f "${AUTH_PROFILES_DIR}/auth-profiles.json" ] || ! grep -q "anthropic:claude-cli" "${AUTH_PROFILES_DIR}/auth-profiles.json" 2>/dev/null; then
    echo "Re-creation du auth-profiles.json..."
    cat > "${AUTH_PROFILES_DIR}/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "anthropic:claude-cli": {
      "type": "oauth",
      "provider": "anthropic",
      "access": "${CLAUDE_CODE_OAUTH_TOKEN}",
      "refresh": "${CLAUDE_CODE_OAUTH_TOKEN}",
      "expires": 4102444800000
    }
  },
  "lastGood": {
    "anthropic": "anthropic:claude-cli"
  }
}
EOF
    chmod 600 "${AUTH_PROFILES_DIR}/auth-profiles.json"
fi

echo '=== Demarrage OpenClaw Gateway ==='
exec openclaw gateway
