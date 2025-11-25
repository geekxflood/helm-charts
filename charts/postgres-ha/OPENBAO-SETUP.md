# OpenBao Integration for Jellyfin PostgreSQL

This guide configures OpenBao's database secrets engine to manage dynamic credentials for the Jellyfin PostgreSQL cluster.

## Prerequisites

- OpenBao cluster running and unsealed
- PostgreSQL cluster deployed via CloudNativePG
- Vault Secrets Operator installed

## Step 1: Store Admin Credentials in OpenBao

First, store the PostgreSQL superuser and openbao_admin credentials in OpenBao KV store:

```bash
# Get the PostgreSQL superuser password from the cluster
SUPERUSER_PASSWORD=$(kubectl get secret postgres-ha-superuser -n database -o jsonpath='{.data.password}' | base64 -d)

# Store superuser credentials
vault kv put secret/postgres/superuser \
    username=postgres \
    password="${SUPERUSER_PASSWORD}" \
    host='postgres-ha-rw.database.svc.cluster.local' \
    port=5432

# Create openbao_admin role in PostgreSQL
kubectl exec postgres-ha-1 -n database -- psql -U postgres -c "
CREATE ROLE openbao_admin WITH
    LOGIN
    PASSWORD 'CHANGE_ME_TO_SECURE_PASSWORD'
    CREATEROLE
    CREATEDB
    CONNECTION LIMIT 10;

GRANT ALL PRIVILEGES ON DATABASE jellyfin TO openbao_admin;
ALTER DEFAULT PRIVILEGES IN DATABASE jellyfin GRANT ALL ON TABLES TO openbao_admin;
ALTER DEFAULT PRIVILEGES IN DATABASE jellyfin GRANT ALL ON SEQUENCES TO openbao_admin;
"

# Store openbao_admin credentials
vault kv put secret/postgres/openbao-admin \
    username=openbao_admin \
    password='CHANGE_ME_TO_SECURE_PASSWORD' \
    host='postgres-ha-rw.database.svc.cluster.local' \
    port=5432
```

## Step 2: Enable Database Secrets Engine

```bash
# Enable the database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/jellyfin-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="jellyfin-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgres-ha-rw.database.svc.cluster.local:5432/jellyfin?sslmode=disable" \
    username="openbao_admin" \
    password="CHANGE_ME_TO_SECURE_PASSWORD" \
    username_template="v-jellyfin-{{random 8}}-{{unix_time}}" \
    max_open_connections=10 \
    max_idle_connections=5 \
    max_connection_lifetime=3600

# Test the connection
vault read database/config/jellyfin-postgres
```

## Step 3: Create Jellyfin Role for Dynamic Credentials

```bash
vault write database/roles/jellyfin-role \
    db_name=jellyfin-postgres \
    creation_statements="
CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT;
GRANT CONNECT ON DATABASE jellyfin TO \"{{name}}\";
GRANT ALL PRIVILEGES ON DATABASE jellyfin TO \"{{name}}\";
GRANT ALL PRIVILEGES ON SCHEMA public TO \"{{name}}\";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO \"{{name}}\";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"{{name}}\";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"{{name}}\";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO \"{{name}}\";
" \
    revocation_statements="
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM \"{{name}}\";
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM \"{{name}}\";
REVOKE ALL PRIVILEGES ON SCHEMA public FROM \"{{name}}\";
REVOKE ALL PRIVILEGES ON DATABASE jellyfin FROM \"{{name}}\";
DROP ROLE IF EXISTS \"{{name}}\";
" \
    default_ttl="24h" \
    max_ttl="72h"
```

## Step 4: Test Dynamic Credential Generation

```bash
# Generate test credentials
vault read database/creds/jellyfin-role

# Example output:
# Key                Value
# ---                -----
# lease_id           database/creds/jellyfin-role/AbC123XyZ
# lease_duration     24h
# lease_renewable    true
# password           A1a-DyNaMiC-PaSsWoRd-XyZ
# username           v-jellyfin-abc12345-1234567890
```

## Step 5: Create Kubernetes Policy and ServiceAccount

```bash
# Create policy for Jellyfin to read dynamic credentials
vault policy write jellyfin-db - <<EOF
path "database/creds/jellyfin-role" {
  capabilities = ["read"]
}
EOF

# Enable Kubernetes auth if not already enabled
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

# Create role for Jellyfin service account
vault write auth/kubernetes/role/jellyfin \
    bound_service_account_names=jellyfin \
    bound_service_account_namespaces=media \
    policies=jellyfin-db \
    ttl=24h
```

## Step 6: Deploy VaultDynamicSecret

The Vault Secrets Operator will be configured via Helm chart to automatically:
1. Request credentials from OpenBao on pod startup
2. Inject them as Kubernetes secrets
3. Renew credentials before expiration
4. Handle rotation automatically

See `values.yaml` for OpenBao configuration options.

## Monitoring

### View Active Leases

```bash
vault list sys/leases/lookup/database/creds/jellyfin-role
```

### View Specific Lease

```bash
vault lease lookup <lease_id>
```

### Manually Renew Lease

```bash
vault lease renew <lease_id>
```

### Revoke Lease

```bash
vault lease revoke <lease_id>
```

## Troubleshooting

### Check PostgreSQL Roles

```bash
kubectl exec postgres-ha-1 -n database -- psql -U postgres -d jellyfin -c "\du"
```

### Check Active Connections

```bash
kubectl exec postgres-ha-1 -n database -- psql -U postgres -d jellyfin -c "
SELECT usename, application_name, client_addr, state, query_start
FROM pg_stat_activity
WHERE datname = 'jellyfin';
"
```

### Test Credentials Manually

```bash
# Get current credentials
CREDS=$(vault read -format=json database/creds/jellyfin-role)
USERNAME=$(echo $CREDS | jq -r '.data.username')
PASSWORD=$(echo $CREDS | jq -r '.data.password')

# Test connection
kubectl run -it --rm psql-test --image=postgres:16-alpine --restart=Never -- \
  psql "postgresql://${USERNAME}:${PASSWORD}@postgres-ha-rw.database.svc.cluster.local:5432/jellyfin" \
  -c "SELECT current_user, current_database();"
```

## Security Best Practices

1. **Rotate openbao_admin password regularly**
   ```bash
   vault write -force database/rotate-root/jellyfin-postgres
   ```

2. **Monitor credential usage**
   - Set up alerts for failed authentications
   - Monitor lease expiration

3. **Use appropriate TTLs**
   - Short TTLs for development (1h)
   - Longer TTLs for production (24h)
   - Balance security vs. performance

4. **Audit logging**
   - Enable OpenBao audit logging
   - Monitor credential access patterns

## Resources

- [OpenBao Database Secrets](https://openbao.org/docs/secrets/databases/postgresql/)
- [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
