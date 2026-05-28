---
trigger: always_on
---

# Execution & Behavioral Constraints

## 🛡️ Sandbox Environment Constraints (CRITICAL)
- **You are running inside an isolated NixOS Podman sandbox.** 
- You do **not** have access to the user's underlying host machine.
- You have full `root` access to this container environment, however, **do not imperatively install any tools or packages**. Rely exclusively on the tools already provided in the environment.
- You may run local servers, execute tests, and run bash scripts without worrying about breaking the user's host machine.
- **No External Network Calls**: Do NOT make outbound network requests, `curl` external APIs, or contact third-party services on your own. You must rely solely on local data and tools.
- **Strict Isolation (No SSH or Git access)**: Do NOT attempt to touch, mount, read, or configure host SSH keys, SSH agent sockets, or host Git configurations. You must remain completely contained inside this container.
- **No Rule Modifications**: You are strictly forbidden from modifying, editing, deleting, or appending to any rule files (including this one or other files in the `.agents/rules/` directory).
- Your current workspace directory (`/home/hampus/workspace/nixos` on the host) is mounted as `/workspace`. Any code changes you make here will be saved permanently on the host. 
- The CLI state is mounted to a persistent volume, so your login and internal data will persist across sessions.

## 📂 Directory Boundaries & Usage Rules
The repository is structured strictly. Adhere to the following directory rules:

### ✅ Permitted Directories (You may edit these)
- `cad/`: contains openscad files for the project.
- `containers/`: Contains declarative OCI container definitions (e.g., `homeassistant.nix`, `antigravity-sandbox.nix`).
- `software/`: Contains static configuration files for services (e.g., `configuration.yaml` for Home Assistant). 
- `scripts/`: Contains shared shell scripts.
- `docs/` and `README.md`: Documentation files.