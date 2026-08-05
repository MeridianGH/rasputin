## Environment Secrets

This repository stores the environment file in encrypted form as `.env.enc`.
The plaintext `.env` file must never be committed.

### Decrypting .env.enc

Run this command to decrypt. Depending on your setup, the age key path may differ.
```bash
age -d -i ~/.config/age/keys.txt -o .env .env.enc
```

### Encrypting .env

After editing `.env`, regenerate the encrypted file using the following command:
```bash
age -R age-recipients.txt -o .env.enc .env
```
