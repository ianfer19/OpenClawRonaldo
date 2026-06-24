# 🔧 Troubleshooting — OpenClaw en AWS

Guía de solución de problemas comunes.

---

## Tabla de Contenidos

1. [No puedo conectarme al servidor](#1-no-puedo-conectarme-al-servidor)
2. [Docker/OpenClaw no arranca](#2-dockeropenclaw-no-arranca)
3. [El bot de Telegram no responde](#3-el-bot-de-telegram-no-responde)
4. [Errores de API/LLM](#4-errores-de-apillm)
5. [Problemas de disco/memoria](#5-problemas-de-discomemoria)
6. [Backups fallan](#6-backups-fallan)
7. [Recibo alertas de CloudWatch](#7-recibo-alertas-de-cloudwatch)

---

## 1. No puedo conectarme al servidor

### Error: "TargetNotConnected"

```
An error occurred (TargetNotConnected)
```

**Causas posibles:**
- La instancia está apagada
- El SSM Agent no está corriendo

**Solución:**
```bash
# Verificar que la instancia está corriendo
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=openclaw-ronaldo" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}" \
  --output table --region us-east-1

# Si está "stopped", encenderla
aws ec2 start-instances --instance-ids i-0abc123 --region us-east-1

# Esperar ~2 minutos y volver a intentar
aws ssm start-session --target i-0abc123 --region us-east-1
```

### Error: "Session Manager Plugin not found"

```
SessionManagerPlugin is not found
```

**Solución:** Instala el plugin:
- **Windows**: [Descargar instalador](https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe)
- **macOS**: `brew install --cask session-manager-plugin`
- **Linux**: `sudo apt install session-manager-plugin` o descarga el .deb

---

## 2. Docker/OpenClaw no arranca

### Verificar estado de los servicios

```bash
cd /opt/openclaw/docker
docker compose ps

# Si algún servicio está "Exited" o "Restarting"
docker compose logs openclaw --tail 50
docker compose logs caddy --tail 50
```

### OpenClaw se reinicia constantemente

**Ver qué error causa el reinicio:**
```bash
docker compose logs openclaw --tail 100 | grep -i "error\|fatal\|panic"
```

**Causas comunes:**
- **Falta de memoria** → Verificar con `free -h`
- **Configuración corrupta** → Restaurar desde backup
- **Imagen corrupta** → Re-descargar imagen

**Solución — recrear contenedores:**
```bash
docker compose down
docker compose pull
docker compose up -d
```

### El bootstrap (User Data) falló

```bash
# Ver log completo del bootstrap
cat /var/log/user-data.log

# Si Docker no se instaló
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker

# Si Compose no se instaló
apt-get install -y docker-compose-plugin
```

---

## 3. El bot de Telegram no responde

### Verificar que OpenClaw está conectado a Telegram

```bash
cd /opt/openclaw/docker
docker compose exec openclaw-gateway bash
openclaw status
```

Deberías ver:
```
Channels:
  ✓ Telegram — connected (long polling)
```

Si dice `disconnected`:

### Re-conectar Telegram

```bash
# Dentro del contenedor
openclaw channel remove telegram
openclaw channel add telegram
# Vuelve a pegar tu Bot Token
```

### Verificar que el Bot Token es válido

```bash
# Reemplaza TU_BOT_TOKEN con tu token real
curl -s "https://api.telegram.org/botTU_BOT_TOKEN/getMe" | python3 -m json.tool
```

Si devuelve `"ok": true`, el token es válido.

### El bot responde pero lento

**Causas:**
- API del LLM lenta → Es normal, depende del proveedor
- CPU al límite → Verificar con `top` o `htop`
- Rate limiting del LLM → Revisar tu plan del proveedor

---

## 4. Errores de API/LLM

### "API key invalid" o "Unauthorized"

```bash
# Dentro del contenedor de OpenClaw
openclaw onboard
# Selecciona el proveedor y re-ingresa tu API key
```

### "Rate limit exceeded"

Tu proveedor de LLM está limitando las peticiones. Opciones:
- Esperar unos minutos
- Subir de plan con tu proveedor
- Cambiar a otro proveedor: `openclaw config set model-provider openai`

### "Insufficient funds" / "Quota exceeded"

Necesitas agregar créditos en la plataforma de tu proveedor LLM:
- [Anthropic Billing](https://console.anthropic.com/settings/billing)
- [OpenAI Billing](https://platform.openai.com/account/billing)

---

## 5. Problemas de disco/memoria

### Verificar uso de disco

```bash
df -h /
```

Si está arriba del 80%:

```bash
# Limpiar logs de Docker antiguos
docker system prune -f

# Limpiar imágenes no usadas
docker image prune -a -f

# Ver qué ocupa más espacio
du -sh /var/lib/docker/* | sort -h
```

### Verificar uso de memoria

```bash
free -h

# Ver qué proceso consume más
top -o %MEM
```

Si la memoria está constantemente arriba del 85%, considera:
- Bajar el límite de memoria de Caddy en docker-compose.yml
- Subir a `t4g.large` (8 GB RAM) — cuesta ~$33/mes

---

## 6. Backups fallan

### Verificar que el cron está configurado

```bash
crontab -l -u ubuntu
```

Deberías ver:
```
0 */6 * * * /opt/openclaw/scripts/backup.sh >> /opt/openclaw/logs/backup.log 2>&1
```

### Ver logs del último backup

```bash
tail -50 /opt/openclaw/logs/backup.log
```

### Error de permisos S3

```bash
# Verificar que el IAM Role tiene acceso
aws s3 ls s3://openclaw-ronaldo-backups/ --region us-east-1

# Si da error "Access Denied", el IAM Role necesita ajuste
# Contacta a quien configuró el servidor
```

### Ejecutar backup manual

```bash
/opt/openclaw/scripts/backup.sh
```

---

## 7. Recibo alertas de CloudWatch

### "CPU High"
- **Normal si**: Acaba de procesar una tarea compleja
- **Preocupante si**: Está constante arriba del 80%
- **Acción**: Conectarse y verificar con `top`

### "Memory High"
- **Normal si**: OpenClaw está procesando algo pesado
- **Preocupante si**: No baja del 85%
- **Acción**: Reiniciar OpenClaw (`docker compose restart openclaw`)

### "Disk High"
- **Acción**: Limpiar logs y Docker (ver sección 5)

### "Status Check Failed"
- **Auto-Recovery**: AWS mueve la instancia a hardware sano automáticamente
- **Si persiste**: Verificar logs de la instancia en CloudWatch

---

## Contacto

Si nada de esto resuelve tu problema, contacta a quien configuró este servidor con:
1. El error exacto que ves
2. Output de `docker compose logs --tail 50`
3. Output de `docker compose ps`
