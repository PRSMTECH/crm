# PRSMTECH CRM Setup Guide

> Complete documentation for the PRSMTECH Frappe CRM + Supabase integration

## Overview

This project deploys **Frappe CRM** via Docker with a companion **Supabase** schema (`prsm_frappuccino`) for extended functionality. The setup provides a complete CRM solution with:

- **Frappe CRM**: Lead and deal pipeline management
- **Supabase Integration**: Extended data layer with RLS policies
- **GitHub Integration**: Custom fields for project/repo linking
- **API Access**: REST API for automation and integrations

---

## Quick Start

### Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Git
- PowerShell (Windows) or Bash (Linux/Mac)

### Start the CRM

```bash
cd J:\PRSMTECH\LOGIC\crm\docker
docker-compose up -d
```

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Frappe CRM | http://localhost:8000 | Administrator / admin |
| Socket.IO | http://localhost:9000 | - |
| MariaDB | localhost:3306 | root / 123 |
| Supabase | https://qewgfglkxmngvxezbern.supabase.co | See .env.local |

---

## Architecture

### Docker Stack

```
┌─────────────────────────────────────────────────────────┐
│                    PRSMTECH CRM Stack                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │   MariaDB   │  │    Redis    │  │     Frappe      │ │
│  │    10.8     │  │    Alpine   │  │   Bench v5.22   │ │
│  │   :3306     │  │   :6379     │  │  :8000 / :9000  │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│         │                │                  │          │
│         └────────────────┴──────────────────┘          │
│                    Internal Network                     │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    Supabase Cloud                       │
│              prsm_frappuccino schema                    │
│                   (22 tables)                           │
└─────────────────────────────────────────────────────────┘
```

### Container Details

| Container | Image | Purpose |
|-----------|-------|---------|
| crm-mariadb-1 | mariadb:10.8 | Primary database |
| crm-redis-1 | redis:alpine | Caching & queues |
| crm-frappe-1 | frappe/bench:v5.22.0 | Application server |

### Volume Persistence

- `mariadb-data`: Database files persist across restarts
- `./docker:/workspace`: Init scripts and configuration

---

## API Configuration

### Credentials

```
API Key:    abd2f9f24a649c2
API Secret: 689857568369383
Site:       crm.localhost
```

### Authentication Header

```bash
Authorization: token abd2f9f24a649c2:689857568369383
```

### Example API Calls

**List all DocTypes:**
```bash
docker exec -it crm-frappe-1 curl -s \
  -H "Authorization: token abd2f9f24a649c2:689857568369383" \
  http://localhost:8000/api/resource/DocType?limit_page_length=0
```

**Get Leads:**
```bash
docker exec -it crm-frappe-1 curl -s \
  -H "Authorization: token abd2f9f24a649c2:689857568369383" \
  http://localhost:8000/api/resource/CRM%20Lead
```

**Get Deals:**
```bash
docker exec -it crm-frappe-1 curl -s \
  -H "Authorization: token abd2f9f24a649c2:689857568369383" \
  http://localhost:8000/api/resource/CRM%20Deal
```

**Create a Lead:**
```bash
docker exec -it crm-frappe-1 curl -s -X POST \
  -H "Authorization: token abd2f9f24a649c2:689857568369383" \
  -H "Content-Type: application/json" \
  -d '{"lead_name": "ACME Corp", "email": "contact@acme.com"}' \
  http://localhost:8000/api/resource/CRM%20Lead
```

---

## Supabase Integration

### Schema: prsm_frappuccino

The Supabase schema mirrors and extends Frappe CRM with 22 tables:

#### Core Tables

| Table | Purpose |
|-------|---------|
| `contacts` | Contact records with sync_status |
| `organizations` | Company/organization data |
| `leads` | Lead pipeline with GitHub fields |
| `deals` | Deal pipeline with GitHub fields |
| `activities` | Activity log (calls, emails, meetings) |
| `notes` | Notes attached to any entity |
| `tasks` | Task management |

#### Pipeline Configuration

| Table | Purpose |
|-------|---------|
| `lead_statuses` | Lead pipeline stages (7 default) |
| `deal_stages` | Deal pipeline stages (7 default) |
| `pipelines` | Pipeline definitions |

#### Extended Features

| Table | Purpose |
|-------|---------|
| `github_integration` | GitHub project/repo links |
| `email_sync` | Email synchronization |
| `call_logs` | Phone call records |
| `templates` | Email/document templates |
| `sequences` | Sales sequences |
| `sequence_steps` | Sequence automation steps |

### Default Pipeline Stages

**Lead Statuses (7):**
1. New (5% probability)
2. Contacted (15%)
3. Qualified (30%)
4. Interested (45%)
5. Proposal Sent (60%)
6. Negotiation (75%)
7. Won/Lost (100%/0%)

**Deal Stages (7):**
1. Discovery (10%)
2. Qualification (25%)
3. Proposal (40%)
4. Negotiation (60%)
5. Contract (80%)
6. Closed Won (100%)
7. Closed Lost (0%)

### Row Level Security

All tables have RLS policies enabled:
- Users can only see their own data (`user_id = auth.uid()`)
- Insert/update/delete restricted to data owners
- Service role bypasses RLS for admin operations

---

## GitHub Integration

### Custom Fields (To Be Created)

The following custom fields link CRM deals to GitHub projects:

| Field | DocType | Type | Description |
|-------|---------|------|-------------|
| `github_project_url` | CRM Deal | Data | GitHub Project board URL |
| `github_repo_url` | CRM Deal | Data | GitHub Repository URL |

### Creating Custom Fields

**Via Frappe UI:**
1. Go to http://localhost:8000/app/custom-field
2. Click "New"
3. Fill in:
   - DocType: `CRM Deal`
   - Field Name: `github_project_url`
   - Label: `GitHub Project URL`
   - Type: `Data`

**Via Bench CLI:**
```bash
docker exec -it crm-frappe-1 bash -c "cd /home/frappe/frappe-bench && \
  bench --site crm.localhost console" << 'EOF'
from frappe.custom.doctype.custom_field.custom_field import create_custom_field
create_custom_field('CRM Deal', {
    'fieldname': 'github_project_url',
    'label': 'GitHub Project URL',
    'fieldtype': 'Data',
    'insert_after': 'deal_owner'
})
create_custom_field('CRM Deal', {
    'fieldname': 'github_repo_url',
    'label': 'GitHub Repo URL',
    'fieldtype': 'Data',
    'insert_after': 'github_project_url'
})
frappe.db.commit()
EOF
```

---

## Docker Deployment Details

### docker-compose.yml

```yaml
version: "3.7"
name: crm
services:
  mariadb:
    image: mariadb:10.8
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
      - --skip-innodb-read-only-compressed
    environment:
      MYSQL_ROOT_PASSWORD: 123
    volumes:
      - mariadb-data:/var/lib/mysql

  redis:
    image: redis:alpine

  frappe:
    image: frappe/bench:v5.22.0
    command: bash /workspace/init.sh
    environment:
      - SHELL=/bin/bash
    working_dir: /home/frappe
    volumes:
      - .:/workspace
    ports:
      - 8000:8000
      - 9000:9000
    depends_on:
      - mariadb
      - redis

volumes:
  mariadb-data:
```

### Fixes Applied

The Docker setup includes fixes for common issues:

| Issue | Fix |
|-------|-----|
| Windows CRLF line endings | Convert init.sh to LF |
| Python 3.14 incompatibility | Use frappe/bench:v5.22.0 |
| Node.js 16 incompatibility | Use frappe/bench:v5.22.0 |
| Redis URL format | Remove protocol prefix |

---

## Common Commands

### Docker Management

```bash
# Start all services
cd J:\PRSMTECH\LOGIC\crm\docker
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f frappe

# Restart a service
docker-compose restart frappe

# Shell into Frappe container
docker exec -it crm-frappe-1 bash
```

### Bench Commands

All bench commands must run from `/home/frappe/frappe-bench`:

```bash
# Enter Frappe container with correct working directory
docker exec -it -w /home/frappe/frappe-bench crm-frappe-1 bash

# Inside container:
bench --site crm.localhost console    # Python console
bench --site crm.localhost mariadb    # Database CLI
bench --site crm.localhost migrate    # Run migrations
bench --site crm.localhost clear-cache # Clear cache
bench --site crm.localhost set-admin-password <password> # Reset admin password
```

### Install Additional Apps

```bash
docker exec -it -w /home/frappe/frappe-bench crm-frappe-1 bash

# Get app from GitHub
bench get-app helpdesk
bench get-app hrms
bench get-app erpnext

# Install app on site
bench --site crm.localhost install-app helpdesk
bench --site crm.localhost install-app hrms
bench --site crm.localhost install-app erpnext
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker ps -a

# Check logs
docker-compose logs frappe

# Rebuild containers
docker-compose down
docker-compose up -d --build
```

### Database Connection Issues

```bash
# Verify MariaDB is running
docker exec -it crm-mariadb-1 mysql -uroot -p123 -e "SHOW DATABASES;"

# Check Frappe site config
docker exec -it crm-frappe-1 cat /home/frappe/frappe-bench/sites/crm.localhost/site_config.json
```

### Redis Connection Issues

```bash
# Verify Redis is running
docker exec -it crm-redis-1 redis-cli ping
# Should return: PONG
```

### API 403 Forbidden

1. Verify API key/secret are correct
2. Check if user has API access enabled
3. Regenerate API keys if needed:

```bash
docker exec -it -w /home/frappe/frappe-bench crm-frappe-1 bench --site crm.localhost console
>>> user = frappe.get_doc("User", "Administrator")
>>> user.api_key = frappe.generate_hash(length=15)
>>> user.api_secret = frappe.generate_hash(length=15)
>>> user.save()
>>> frappe.db.commit()
>>> print(f"Key: {user.api_key}, Secret: {user.get_password('api_secret')}")
```

### Reset Admin Password

```bash
docker exec -it -w /home/frappe/frappe-bench crm-frappe-1 \
  bench --site crm.localhost set-admin-password NewPassword123
```

---

## File Structure

```
J:\PRSMTECH\LOGIC\crm\
├── .memory-bank/           # Memory Bank context files
│   ├── activeContext.md    # Current session context
│   ├── decisionLog.md      # Technical decisions
│   ├── productContext.md   # Product overview
│   ├── progress.md         # Development progress
│   └── systemPatterns.md   # Architecture patterns
├── docker/                 # Docker deployment
│   ├── docker-compose.yml  # Container orchestration
│   └── init.sh             # Frappe initialization script
├── frontend/               # Vue.js frontend (optional custom UI)
├── PRSMTECH-CRM-SETUP.md   # This documentation
└── README.md               # Original Frappe CRM readme
```

---

## Next Steps

### Pending Tasks

1. **Install Additional Apps**
   - Helpdesk: Customer support ticketing
   - HRMS: Employee management
   - ERPNext: Full ERP integration for invoicing

2. **GitHub Integration**
   - Create custom fields for project/repo URLs
   - Set up webhooks for status sync
   - Implement GitHub Actions workflows

3. **Production Deployment**
   - Set up SSL/TLS certificates
   - Configure production database
   - Enable backups
   - Set up monitoring

---

## References

- [Frappe CRM Documentation](https://docs.frappe.io/crm)
- [Frappe Framework](https://frappeframework.com)
- [Supabase Documentation](https://supabase.com/docs)
- [PRSMTECH LOGIC Repository](file:///J:/PRSMTECH/LOGIC)

---

*Last Updated: December 28, 2025*
*Version: 1.0.0*
