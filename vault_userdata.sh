#!/bin/bash
set -e

# Install dependencies
sudo apt-get update -y
sudo apt-get install -y unzip jq awscli

# Install Vault
VAULT_VERSION="1.15.0"
curl -o vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
sudo unzip vault.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/vault
vault -autocomplete-install

# Create Vault data dir
sudo mkdir -p /data/vault
sudo chown ubuntu:ubuntu /data/vault

# Vault config
cat <<EOF | sudo tee /etc/vault.hcl
storage "file" {
  path = "/data/vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

ui            = true
cluster_name  = "aws-vault-cluster"
api_addr      = "http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8200"
EOF

# Systemd service
cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=Vault service
After=network.target

[Service]
ExecStart=/usr/local/bin/vault server -config=/etc/vault.hcl
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault

# Backup script
cat <<'EOS' | sudo tee /usr/local/bin/vault-backup.sh
#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
aws s3 cp /data/vault s3://vault_daily_backup/$TIMESTAMP --recursive
EOS
sudo chmod +x /usr/local/bin/vault-backup.sh

# Cronjob for backups
echo "*/5 * * * * root /usr/local/bin/vault-backup.sh" | sudo tee /etc/cron.d/vault-backup
