# Homelab CLI

`homelab.sh` is the main command-line interface for managing the homelab environment.

It provides commands for:

- Managing Docker Compose stacks
- Controlling individual services
- Updating deployments
- Creating required infrastructure
- Installing the CLI command

The command is available as:

```bash
homelab <command>
```

---

# Installation

Install the CLI globally:

```bash
homelab install
```

After installation, `homelab` can be run from any directory.

---

# Command Reference

| Command | Description | Example |
|---|---|---|
| `homelab up` | Start all stacks | `homelab up` |
| `homelab up <stack> [stack...]` | Start specific stacks | `homelab up core apps` |
| `homelab down` | Stop all stacks | `homelab down` |
| `homelab down <stack> [stack...]` | Stop specific stacks | `homelab down apps` |
| `homelab restart` | Restart all stacks | `homelab restart` |
| `homelab restart <stack> [stack...]` | Restart specific stacks | `homelab restart core` |
| `homelab update` | Update and redeploy all stacks | `homelab update` |
| `homelab update <stack> [stack...]` | Update and redeploy specific stacks | `homelab update apps` |
| `homelab service up <service>` | Start a single service | `homelab service up traefik` |
| `homelab service down <service>` | Stop a single service | `homelab service down pihole` |
| `homelab service restart <service>` | Restart a single service | `homelab service restart grafana` |
| `homelab logs <service>` | Follow logs for a service | `homelab logs traefik` |
| `homelab networks` | Create required Docker networks | `homelab networks` |
| `homelab install` | Install the `homelab` command globally | `homelab install` |
| `homelab help` | Display available commands | `homelab help` |

---

# Available Stacks

Stacks are managed in dependency order:

```text
core
metrics
mail
apps
```

When operating on multiple stacks, the CLI maintains this order automatically.

---

# Common Workflows

## Start the complete environment

```bash
homelab up
```

## Start selected stacks

```bash
homelab up core apps
```

## Update deployments

```bash
homelab update
```

## Restart a service

```bash
homelab service restart traefik
```

## Follow service logs

```bash
homelab logs traefik
```