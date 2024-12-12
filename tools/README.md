# README.md

## Shell Script Formatter and Flow Control Tool

This script provides utilities to improve the readability, usability, and flow control of shell scripts. It includes functions for formatted output, handling user inputs, command execution with error handling, and dynamic flow control. These utilities are particularly helpful in complex environments, such as setting up ROSA clusters or deploying AI demo applications.

---

## Table of Contents
1. [Getting Started](#getting-started)
2. [Features and Commands](#features-and-commands)
   - [Formatted Output (`__`)](#formatted-output-__)
   - [Pause or Delay (`___`)](#pause-or-delay-___)
   - [Execute Commands (`cmd`)](#execute-commands-cmd)
   - [Prompt for Input (`_?`)](#prompt-for-input-__)
   - [Flow Control (`oo`)](#flow-control-oo)
3. [Examples and Use Cases](#examples-and-use-cases)
   - [Complex Use Case 1: AI Demo Setup](#complex-use-case-1-ai-demo-setup)
   - [Complex Use Case 2: ROSA Configuration](#complex-use-case-2-rosa-configuration)
4. [Missing Features](#missing-features)
5. [Contributing](#contributing)

---

## Getting Started

### Prerequisites
Ensure you have the following:
- A Unix-based shell environment
- Basic knowledge of shell scripting

### Installation
1. Copy the script to your working directory and name it `format.sh`.
2. Source the script to use its functions:
   ```bash
   source format.sh
   ```

---

## Features and Commands

### Formatted Output (`__`)
The `__` function prints messages with customizable styles to improve script readability.

#### Syntax:
```bash
__ "<message>" <format_code>
```

#### Format Codes:
- `1`: Large double-bordered box
- `2`: Single-bordered box
- `3`: Header with tilde borders
- `4`: Small dot-borders
- `5`: Simple bullet point
- `6`: Asterisk bullet point
- `sameline`: Print on the same line

#### Example:
```bash
__ "Starting the script..." 1
__ "Loading data" 2
```

### Pause or Delay (`___`)
The `___` function pauses the script or delays execution for a specified time.

#### Syntax:
```bash
___ "<message>" <seconds>
```

#### Example:
```bash
___ "Processing, please wait..." 5
___ "Press any key to continue..."
```

### Execute Commands (`cmd`)
The `cmd` function runs shell commands with error handling and formatted output.

#### Syntax:
```bash
cmd "<command>"
```

#### Example:
```bash
cmd "ls -al"
cmd "mkdir test_directory"
```

If a command fails, the script will prompt the user to press a key to continue.

### Prompt for Input (`_?`)
The `_?` function prompts the user for input and stores it in a variable.

#### Syntax:
```bash
_? "<message>" <variable_name> <default_value> [optional_direct_value]
```

#### Example:
```bash
_? "Enter the file name" FILE_NAME "default.txt"
```

This will prompt the user and store the input in the `FILE_NAME` environment variable.

### Flow Control (`oo`)
The `oo` function executes a command repeatedly until a specific condition is met or interrupted.

#### Syntax:
```bash
oo <target_value> "<command>"
```

#### Example:
```bash
oo 5 "ls | wc -l"
```

This example waits until the output of `ls | wc -l` reaches 5.

---

## Examples and Use Cases

### Use Case 1: Setup Script with Formatted Logs
```bash
source format.sh

__ "Starting setup..." 1
cmd "mkdir /tmp/setup_dir"
___ "Setup directory created. Pausing for 3 seconds..." 3
__ "Setup complete." 2
```

### Use Case 2: Interactive User Input
```bash
source format.sh

__ "Welcome to the configuration wizard." 3
_? "Enter the server name" SERVER_NAME "localhost"
cmd "ping -c 3 $SERVER_NAME"
___ "Configuration complete."
```

### Use Case 3: Repeated Polling
```bash
source format.sh

__ "Monitoring the file count..." 2
oo 10 "ls | wc -l"
__ "Target file count reached!" 5
```

### Complex Use Case 1: AI Demo Setup
This script can be used to deploy a complete AI demo application stack, including:
- Setting up namespaces and projects
- Installing Keycloak, PostgreSQL, Strapi, Redis, and other components
- Managing Helm charts and secrets

#### Example Workflow:
```bash
source format.sh

__ "Install AI Demo App" 1
cmd "git clone https://github.com/demo-repo/ai-starter.git /path/to/demo"
cmd "oc new-project ai-demo"
cmd "helm install keycloak /path/to/charts/keycloak"
___ "Demo setup complete."
```

### Complex Use Case 2: ROSA Configuration
The script can also automate ROSA cluster configurations, including machine pools, upgrades, and operator installations.

#### Example Workflow:
```bash
source format.sh

__ "Set up ROSA cluster" 1
_? "Enter bastion host" BASTION_HOST "bastion.example.com"
cmd "ssh-copy-id user@$BASTION_HOST"
cmd "rosa create cluster"
___ "Cluster setup complete."
```

---

## Missing Features
1. **Enhanced Error Reporting:**
   - Include detailed logs for failed commands.
   - Add an option to retry commands automatically.

2. **Parallel Command Execution:**
   - Support running multiple commands concurrently with progress tracking.

3. **Dynamic Input Validation:**
   - Allow validation of user inputs against custom criteria (e.g., regex).

4. **Configuration File Support:**
   - Enable loading variables and settings from a configuration file.

5. **Modular Architecture:**
   - Break the script into smaller, reusable modules for scalability.

---

## Contributing
To contribute to this project:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with your changes.

---

## License
This script is open-source and free to use. Feel free to customize it for your needs.

