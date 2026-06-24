# 🤖 OpenClaw para Ronaldo — Infraestructura AWS

Infraestructura como código para desplegar [OpenClaw](https://github.com/openclaw/openclaw) como agente AI personal en AWS.

## ¿Qué es esto?

Un servidor AWS pre-configurado que ejecuta OpenClaw — un agente AI autónomo que se conecta a **Telegram** y puede ejecutar tareas, gestionar archivos, navegar la web, y más. Tu amigo Ronaldo solo necesita conectarse y configurar sus credenciales.

## Arquitectura

| Componente | Tecnología |
|-----------|-----------|
| **Compute** | EC2 `t4g.medium` (ARM64 Graviton) |
| **OS** | Ubuntu 24.04 LTS |
| **Contenedores** | Docker + Docker Compose |
| **Reverse Proxy** | Caddy (Auto-TLS, opcional) |
| **Mensajería** | Telegram (long polling) |
| **Backups** | S3 cada 6h + EBS Snapshots |
| **Monitoring** | CloudWatch + SNS Email |
| **Acceso** | SSM Session Manager (zero SSH) |
| **Región** | us-east-1 (N. Virginia) |

**Costo estimado: ~$21 USD/mes** (on-demand)

## Estructura del Proyecto

```
├── cloudformation/          # Templates de infraestructura
│   ├── 01-network.yml       # VPC, Subnet, IGW, Flow Logs
│   ├── 02-compute.yml       # EC2, EBS, EIP, IAM, S3, User Data
│   ├── 03-security.yml      # Security Groups
│   └── 04-monitoring.yml    # CloudWatch, SNS, Auto-Recovery
├── docker/                  # Configuración de contenedores
│   ├── docker-compose.yml   # OpenClaw + Caddy stack
│   └── Caddyfile            # Reverse proxy config
├── scripts/
│   └── deploy.sh            # Script de despliegue automatizado
├── docs/
│   ├── SETUP_GUIDE.md       # Guía paso a paso para Ronaldo
│   └── TROUBLESHOOTING.md   # Solución de problemas
├── ARCHITECTURE.md          # Diseño detallado de arquitectura
└── README.md                # Este archivo
```

## Despliegue Rápido

### Pre-requisitos
- AWS CLI configurado con credenciales
- Cuenta AWS con permisos de administrador

### Desplegar

```bash
# Clonar este repo
git clone https://github.com/tu-usuario/OpenClawRonaldo.git
cd OpenClawRonaldo

# Hacer ejecutable el script
chmod +x scripts/deploy.sh

# Desplegar (con email de notificaciones)
./scripts/deploy.sh openclaw-ronaldo ronaldo@email.com
```

El script:
1. ✅ Valida todos los templates
2. ✅ Despliega los 4 stacks en orden
3. ✅ Muestra el comando SSM para conectarse

### Conectarse al Servidor

```bash
# Conectar via SSM (output del deploy)
aws ssm start-session --target i-0xxxxx --region us-east-1
```

### Configurar OpenClaw

```bash
# Dentro del servidor (via SSM)
cd /opt/openclaw/docker
docker compose exec openclaw-gateway bash
openclaw onboard
```

## Documentación

- 📖 [**Guía de Setup para Ronaldo**](docs/SETUP_GUIDE.md) — Paso a paso completo
- 🏗️ [**Arquitectura Detallada**](ARCHITECTURE.md) — Diseño y decisiones técnicas  
- 🔧 [**Troubleshooting**](docs/TROUBLESHOOTING.md) — Problemas comunes y soluciones

## Seguridad

- 🔒 **Zero SSH** — Acceso exclusivo por SSM Session Manager
- 🛡️ **IMDSv2** enforced contra SSRF
- 🔐 **EBS encrypted** con KMS
- 🚫 **Security Groups mínimos** — Solo puertos necesarios
- 🔄 **Unattended upgrades** — Parches de seguridad automáticos
- 📦 **Docker resource limits** — Previene consumo excesivo

## Licencia

Uso privado. OpenClaw está bajo [MIT License](https://github.com/openclaw/openclaw/blob/main/LICENSE).
