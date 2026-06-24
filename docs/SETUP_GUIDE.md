# 📖 Guía de Setup — OpenClaw en AWS

Guía paso a paso para configurar y usar tu agente AI personal OpenClaw desplegado en AWS.

---

## Tabla de Contenidos

1. [Pre-requisitos](#1-pre-requisitos)
2. [Conectarte al servidor](#2-conectarte-al-servidor)
3. [Configurar OpenClaw](#3-configurar-openclaw)
4. [Conectar Telegram](#4-conectar-telegram)
5. [Verificar que todo funciona](#5-verificar-que-todo-funciona)
6. [Operaciones del día a día](#6-operaciones-del-día-a-día)
7. [Backups y restauración](#7-backups-y-restauración)
8. [Costos y optimización](#8-costos-y-optimización)

---

## 1. Pre-requisitos

Antes de empezar necesitas:

- [ ] **AWS CLI** instalado en tu computadora ([descargar aquí](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- [ ] **Credenciales AWS** configuradas (te las daré yo)
- [ ] **Session Manager Plugin** para AWS CLI ([descargar aquí](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html))
- [ ] **Una API key** de tu proveedor LLM favorito:
  - [Claude (Anthropic)](https://console.anthropic.com/) — Recomendado
  - [OpenAI](https://platform.openai.com/)
  - [Google Gemini](https://aistudio.google.com/apikey)
- [ ] **Un bot de Telegram** — Lo crearás en el paso 4

### Instalar AWS CLI

**Windows (PowerShell):**
```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Configurar credenciales

```bash
aws configure
# AWS Access Key ID: [te lo daré]
# AWS Secret Access Key: [te lo daré]
# Default region name: us-east-1
# Default output format: json
```

### Instalar Session Manager Plugin

**Windows:** Descarga e instala desde [aquí](https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe)

**macOS:**
```bash
brew install --cask session-manager-plugin
```

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

---

## 2. Conectarte al servidor

No usamos SSH. Usamos **SSM Session Manager** que es más seguro.

### Paso 2.1 — Obtener tu Instance ID

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=openclaw-ronaldo" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}" \
  --output table --region us-east-1
```

Deberías ver algo como:
```
---------------------------------------------------
|              DescribeInstances                    |
+-----------+------------+-------------------------+
|    ID     |   State    |          IP             |
+-----------+------------+-------------------------+
| i-0abc123 |  running   |  54.xxx.xxx.xxx         |
+-----------+------------+-------------------------+
```

### Paso 2.2 — Conectarte

```bash
aws ssm start-session --target i-0abc123 --region us-east-1
```

> **¡Estás dentro del servidor!** Deberías ver un prompt como:
> ```
> sh-5.1$
> ```

Cambia a bash para una mejor experiencia:
```bash
bash
cd /opt/openclaw/docker
```

---

## 3. Configurar OpenClaw

### Paso 3.1 — Verificar que Docker está corriendo

```bash
docker compose ps
```

Deberías ver los servicios `openclaw-gateway` y `openclaw-caddy` en estado `Up`.

### Paso 3.2 — Entrar al contenedor de OpenClaw

```bash
docker compose exec openclaw-gateway bash
```

### Paso 3.3 — Ejecutar el onboarding

```bash
openclaw onboard
```

Esto te pedirá:
1. **Nombre de tu agente** — Ponle el nombre que quieras
2. **Proveedor de LLM** — Selecciona tu proveedor (Claude, OpenAI, etc.)
3. **API Key** — Pega tu API key del proveedor elegido
4. **Otras configuraciones** — Sigue las instrucciones en pantalla

### Paso 3.4 — Salir del contenedor

```bash
exit
```

---

## 4. Conectar Telegram

### Paso 4.1 — Crear un Bot de Telegram

1. Abre Telegram y busca **@BotFather**
2. Envía el comando `/newbot`
3. Elige un **nombre** para tu bot (ejemplo: `Ronaldo AI Assistant`)
4. Elige un **username** para tu bot (debe terminar en `bot`, ejemplo: `ronaldo_ai_bot`)
5. BotFather te dará un **token**. Cópialo — lo necesitas en el siguiente paso.

> ⚠️ **IMPORTANTE**: No compartas este token con nadie. Quien lo tenga puede controlar tu bot.

### Paso 4.2 — Configurar el bot en OpenClaw

```bash
# Desde /opt/openclaw/docker
docker compose exec openclaw-gateway bash

# Configurar el canal de Telegram
openclaw channel add telegram
```

Te pedirá:
- **Bot Token**: Pega el token que te dio BotFather
- **Modo**: Selecciona **long polling** (recomendado, no requiere dominio)
- **Usuarios permitidos**: Tu username de Telegram (para que solo tú puedas hablar con el bot)

### Paso 4.3 — Verificar la conexión

```bash
openclaw status
```

Deberías ver:
```
Channels:
  ✓ Telegram — connected (long polling)
```

Sal del contenedor:
```bash
exit
```

### Paso 4.4 — Probar el bot

1. Abre Telegram
2. Busca tu bot por el username que elegiste
3. Envíale un mensaje: `Hola, ¿estás activo?`
4. Deberías recibir una respuesta del agente 🎉

---

## 5. Verificar que todo funciona

### Health check rápido

```bash
# Desde el servidor (via SSM)
cd /opt/openclaw/docker

# Estado de los servicios
docker compose ps

# Logs en tiempo real
docker compose logs -f --tail 50

# Health check manual
curl -s http://localhost:18789/healthz
```

### Verificar backups

```bash
# Ver últimos backups en S3
aws s3 ls s3://openclaw-ronaldo-backups/workspace/ --region us-east-1 | tail -5
```

---

## 6. Operaciones del día a día

### Ver logs

```bash
# Conectarte al servidor
aws ssm start-session --target i-0abc123 --region us-east-1

# Ver logs de OpenClaw
cd /opt/openclaw/docker
docker compose logs -f openclaw

# Ver logs de Caddy
docker compose logs -f caddy
```

### Reiniciar servicios

```bash
cd /opt/openclaw/docker

# Reiniciar todo
docker compose restart

# Reiniciar solo OpenClaw
docker compose restart openclaw
```

### Actualizar OpenClaw

```bash
cd /opt/openclaw/docker

# Hacer backup primero
/opt/openclaw/scripts/backup.sh

# Actualizar
docker compose pull
docker compose up -d

# Verificar
docker compose ps
docker compose logs -f --tail 20
```

### Detener servicios (temporalmente)

```bash
cd /opt/openclaw/docker
docker compose down
```

### Iniciar servicios

```bash
cd /opt/openclaw/docker
docker compose up -d
```

---

## 7. Backups y restauración

### Backups automáticos

Los backups se ejecutan **automáticamente cada 6 horas** y se suben a S3.

Se respalda:
- ✅ `workspace/` — Memoria del agente (MEMORY.md, SOUL.md, etc.)
- ✅ `config/` — Configuración (openclaw.json, API keys)

### Backup manual

```bash
/opt/openclaw/scripts/backup.sh
```

### Restaurar desde backup

```bash
/opt/openclaw/scripts/restore.sh
```

El script te mostrará los backups disponibles y te pedirá confirmar antes de restaurar.

---

## 8. Costos y optimización

### Costo mensual estimado

| Recurso | Costo/mes |
|---------|-----------|
| EC2 t4g.medium | ~$16.50 |
| EBS 20GB | ~$1.60 |
| CloudWatch | ~$2.50 |
| S3 backups | ~$0.06 |
| Data transfer | ~$0.45 |
| **Total** | **~$21** |

### Reducir costos

**Opción 1 — Savings Plan** (recomendado si lo usas más de 6 meses):
- Compromiso de 1 año → ahorra ~30% en EC2
- Total baja a ~$14-16/mes

**Opción 2 — Apagar cuando no lo uses** (si no lo necesitas 24/7):
```bash
# Parar la instancia (no se cobra EC2, solo EBS)
aws ec2 stop-instances --instance-ids i-0abc123 --region us-east-1

# Encender la instancia
aws ec2 start-instances --instance-ids i-0abc123 --region us-east-1
```

> ⚠️ Si apagas la instancia, el bot de Telegram dejará de responder hasta que la enciendas.

---

## Comandos de Referencia Rápida

| Acción | Comando |
|--------|---------|
| Conectar al servidor | `aws ssm start-session --target i-0abc123 --region us-east-1` |
| Ver estado servicios | `docker compose ps` |
| Ver logs | `docker compose logs -f` |
| Reiniciar todo | `docker compose restart` |
| Actualizar OpenClaw | `docker compose pull && docker compose up -d` |
| Backup manual | `/opt/openclaw/scripts/backup.sh` |
| Restaurar backup | `/opt/openclaw/scripts/restore.sh` |
| Parar instancia | `aws ec2 stop-instances --instance-ids i-0abc123 --region us-east-1` |
| Iniciar instancia | `aws ec2 start-instances --instance-ids i-0abc123 --region us-east-1` |

---

## ¿Necesitas ayuda?

Consulta la [guía de troubleshooting](TROUBLESHOOTING.md) para problemas comunes, o contacta a quien configuró este servidor.
