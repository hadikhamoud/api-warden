# API Warden

Process notifier written using only zig's std

## Installation

### Quick Install (Linux/macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/hadikhamoud/api-warden/main/install.sh | bash
```

### Build from Source

Requires [Zig 0.15.2+](https://ziglang.org/download/)

```bash
git clone https://github.com/hadikhamoud/api-warden.git
cd api-warden
zig build -Doptimize=ReleaseFast
sudo cp zig-out/bin/api-warden /usr/local/bin/
```
