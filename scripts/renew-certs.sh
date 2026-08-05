#!/bin/bash
# renew-certs.sh
# Auto-renews rasputin.pi TLS certificate signed by rasputinCA
# Usage: ./renew-certs.sh [--force]

ROOT_DIR="../data/certs"
CERT_DIR="$ROOT_DIR/internal"
DOMAIN="rasputin.pi"
CERT="$CERT_DIR/$DOMAIN.crt"
KEY="$CERT_DIR/$DOMAIN.key"
CSR="$CERT_DIR/$DOMAIN.csr"
SAN_CONF="$CERT_DIR/rasputin_san.cnf"
CA_CERT="$ROOT_DIR/ca/rasputinCA.crt"
CA_KEY="$ROOT_DIR/ca/rasputinCA.key"
PEM="$CERT_DIR/$DOMAIN.pem"
DAYS_LEFT=30   # Renew if less than 30 days left
VALIDITY=825   # TLS certificate validity in days
FORCE=0

# Check for --force option
if [ "$1" == "--force" ]; then
    FORCE=1
    echo "Force renewal enabled."
fi

mkdir -p "$CERT_DIR"

# Check if certificate exists and days left
if [ -f "$CERT" ] && [ "$FORCE" -eq 0 ]; then
    REMAINING=$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
    REMAINING_SECONDS=$(date -d "$REMAINING" +%s)
    NOW_SECONDS=$(date +%s)
    DIFF_DAYS=$(( (REMAINING_SECONDS - NOW_SECONDS) / 86400 ))
    if [ "$DIFF_DAYS" -gt "$DAYS_LEFT" ]; then
        echo "Certificate is still valid for $DIFF_DAYS days. No renewal needed."
        exit 0
    fi
    echo "Certificate expires in $DIFF_DAYS days. Renewing..."
else
    echo "Certificate not found or force renewal requested. Generating new one..."
fi

# Generate server key
openssl genrsa -out "$KEY" 2048

# Generate CSR
openssl req -new -key "$KEY" -out "$CSR" -subj "/C=DE/O=Rasputin Inc./CN=$DOMAIN"

# Generate SAN config
cat > "$SAN_CONF" <<EOL
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = DE
O = Rasputin Inc.
CN = $DOMAIN

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOL

# Sign CSR with CA
openssl x509 -req -in "$CSR" \
  -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$CERT" -days $VALIDITY -sha256 \
  -extfile "$SAN_CONF" -extensions v3_req

# Combine server cert + CA cert for Traefik / Chromium
cat "$CERT" "$CA_CERT" > "$PEM"

echo "Certificate renewed successfully!"
echo "Server key: $KEY"
echo "Server cert: $CERT"
echo "Combined PEM: $PEM"
