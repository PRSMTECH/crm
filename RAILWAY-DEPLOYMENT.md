# PRSMTECH CRM - Railway Deployment Guide

## Quick Deploy

### Option 1: Railway Dashboard (Recommended)

1. **Go to Railway**: https://railway.app/dashboard
2. **Create New Project** → "Deploy from GitHub repo"
3. **Connect**: `PRSMTECH/crm` repository
4. **Add Services**:
   - **MariaDB**: Click "Add Service" → "Database" → "MySQL"
   - **Redis**: Click "Add Service" → "Database" → "Redis"

### Option 2: CLI Deployment

```bash
# Login to Railway (run in your terminal, not Claude Code)
railway login

# Initialize project
cd J:\PRSMTECH\LOGIC\crm
railway init --name prsmtech-crm

# Link to GitHub repo
railway link

# Add MariaDB plugin
railway add --plugin mysql

# Add Redis plugin
railway add --plugin redis

# Deploy
railway up
```

## Required Environment Variables

Set these in Railway Dashboard → Variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ADMIN_PASSWORD` | CRM admin password | `admin` |
| `DB_ROOT_PASSWORD` | MariaDB root password | `123` |
| `FRAPPE_SITE_NAME` | Site name | `crm.localhost` |

**Auto-Configured by Railway**:
- `MYSQL_URL` - Database connection
- `REDIS_URL` - Redis connection

## Architecture

```
Railway Project: prsmtech-crm
├── crm-web (Frappe/CRM)
│   ├── Port: 8000 (HTTP)
│   └── Port: 9000 (Socket.IO)
├── mysql (MariaDB 10.8)
│   └── Port: 3306
└── redis (Redis Alpine)
    └── Port: 6379
```

## Post-Deployment

1. **Get Domain**: Railway Settings → Domains → Generate Domain
2. **Access CRM**: `https://your-domain.railway.app`
3. **Login**: Administrator / [ADMIN_PASSWORD]

## Monitoring

- **Logs**: Railway Dashboard → Deployments → View Logs
- **Metrics**: Railway Dashboard → Metrics
- **Health**: `/api/method/frappe.ping`

## Scaling

```bash
# Scale replicas
railway service update --replicas 2

# Upgrade plan
railway plan upgrade
```

## Troubleshooting

### Build Fails
- Check Dockerfile syntax
- Ensure all dependencies in requirements

### Database Connection Error
- Verify MYSQL_URL is set
- Check Railway plugin is provisioned

### Site Not Loading
- Wait for health check (up to 5 min)
- Check logs for initialization errors

## Local Development

For local development, use Docker Compose:

```bash
cd J:\PRSMTECH\LOGIC\crm\docker
docker-compose up -d
```

Access at: http://localhost:8000

---

**Repository**: https://github.com/PRSMTECH/crm
**Documentation**: See PRSMTECH-CRM-SETUP.md
