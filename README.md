# gcloud-docker-network

Docker iptables management tool for GCloud environments. Easily manage iptables rules to allow host access to Docker containers through Docker bridge interfaces.

## Features

- ✅ Add/remove iptables rules for Docker container access
- ✅ Check port rule status
- ✅ Duplicate rule detection
- ✅ INPUT policy checking with confirmation prompts
- ✅ Dry-run mode for safe testing
- ✅ List Docker-related iptables rules
- ✅ Colored output for better readability

## Installation

### Quick Install (Recommended)

```bash
curl -LsSf https://raw.githubusercontent.com/YOUR_USERNAME/gcloud-docker-network/main/install.sh | sh
```

### Manual Installation

```bash
# Download and install
curl -LsSf https://raw.githubusercontent.com/YOUR_USERNAME/gcloud-docker-network/main/run.sh -o /usr/local/bin/gcloud-docker-network
chmod +x /usr/local/bin/gcloud-docker-network
```

### Uninstall

```bash
curl -LsSf https://raw.githubusercontent.com/YOUR_USERNAME/gcloud-docker-network/main/install.sh | sh -s -- --uninstall
```

## Usage

### Basic Syntax

```bash
gcloud-docker-network <command> [options] <ports...>
```

### Commands

#### List Docker Rules
```bash
gcloud-docker-network list
```
Display Docker-related iptables rules with headers.

#### Check Port Status
```bash
gcloud-docker-network check 8080 3000
```
Check if specified ports are allowed through iptables.

#### Add Port Rules
```bash
gcloud-docker-network add 8080 3000 5000
```
Add iptables rules to allow traffic on specified ports.

**Options:**
- `--dry-run`: Show what would be done without executing
- `-f, --force`: Skip INPUT policy confirmation prompt

**Examples:**
```bash
# Add port with confirmation
gcloud-docker-network add 8080

# Add port without confirmation
gcloud-docker-network add -f 8080

# Test what would happen (dry-run)
gcloud-docker-network add --dry-run 8080 3000

# Combine options
gcloud-docker-network add --dry-run -f 8080 3000
```

#### Delete Port Rules
```bash
gcloud-docker-network del 8080
```
Remove iptables rules for specified ports.

**Options:**
- `--dry-run`: Show what would be deleted without executing

**Examples:**
```bash
# Delete port rule
gcloud-docker-network del 8080

# Test deletion (dry-run)
gcloud-docker-network del --dry-run 8080
```

#### Show All Rules
```bash
gcloud-docker-network show-all
```
Display all INPUT chain rules with statistics.

#### Help
```bash
gcloud-docker-network help
```
Show detailed help message.

#### Version
```bash
gcloud-docker-network version
```
Display version information.

## Options

- `--dry-run` - Show commands without executing (available for add/del/check)
- `-f, --force` - Skip INPUT policy confirmation prompt (add command only)

## Important Notes

1. **Port Requirements**
   - Ports are required arguments (no default values)
   - Must be numbers between 1-65535

2. **INPUT Policy Check**
   - The `add` command checks if INPUT chain policy is DROP
   - If INPUT policy is not DROP, a confirmation prompt is shown
   - Use `-f` to skip the confirmation prompt
   - Dry-run mode automatically skips confirmation

3. **Command Order**
   ```bash
   command [options] ports...
   ```
   Options must come before port numbers.

4. **Rule Pattern**
   The tool manages iptables rules with this pattern:
   ```bash
   iptables -A INPUT -i br+ -p tcp --dport PORT -m comment --comment "Docker-Host access rule DATE" -j ACCEPT
   ```

5. **Persistence**
   After making changes, save them permanently:
   ```bash
   sudo iptables-save > /etc/iptables/rules.v4
   ```

## Examples

### Common Workflows

```bash
# Check if ports are allowed
gcloud-docker-network check 8080 3000

# Add multiple ports
gcloud-docker-network add 8080 3000 5000

# Test before adding (recommended)
gcloud-docker-network add --dry-run 8080

# Force add without confirmation
gcloud-docker-network add -f 8080

# Remove port rules
gcloud-docker-network del 8080

# List all Docker-related rules
gcloud-docker-network list

# Show all iptables rules
gcloud-docker-network show-all
```

### Complete Example

```bash
# 1. Check current status
gcloud-docker-network check 8080

# 2. Test adding the rule
gcloud-docker-network add --dry-run 8080

# 3. Actually add the rule
gcloud-docker-network add 8080

# 4. Verify it was added
gcloud-docker-network list

# 5. Save permanently
sudo iptables-save > /etc/iptables/rules.v4
```

## Requirements

- Linux environment
- `sudo` access for iptables commands
- Docker installed and running
- Standard utilities: `iptables`, `grep`, `awk`, `head`, `tail`, `wc`

## Use Case

This tool is designed for GCloud environments where:
- INPUT chain policy is set to DROP for security
- Docker containers need to be accessed from the host
- You need to manage iptables rules for Docker bridge interfaces (`br+`)

## License

MIT License

## Version

Current version: 1.0.2

## Contributing

Issues and pull requests are welcome!

## Repository

https://github.com/YOUR_USERNAME/gcloud-docker-network
