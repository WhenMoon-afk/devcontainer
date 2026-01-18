# UI Test Tool

A Playwright-based utility for AI coding agents to test webapps directly.

## Setup

The tool requires Playwright. Install it in your project:

```bash
pip install playwright
playwright install chromium
```

Or with uv (pre-installed in this container):

```bash
uv pip install playwright
playwright install chromium
```

## Usage

```bash
# Basic page load check
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py --url http://localhost:3000

# Take a screenshot
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --screenshot home.png

# Check for specific elements
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --check-elements "button.submit,#login-form,nav"

# Capture console logs
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --console

# Full test with JSON output (good for programmatic use)
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --screenshot test.png \
    --console \
    --json

# Wait for an element before taking screenshot
python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
    --url http://localhost:3000 \
    --wait-for "[data-loaded='true']" \
    --screenshot ready.png
```

## Options

| Option | Description |
|--------|-------------|
| `--url URL` | URL to navigate to (required) |
| `--screenshot FILE` | Take screenshot and save to FILE |
| `--check-elements SELECTORS` | Comma-separated CSS selectors to check |
| `--console` | Capture and display browser console logs |
| `--json` | Output results as JSON |
| `--wait-for SELECTOR` | Wait for element before proceeding |
| `--timeout MS` | Timeout in milliseconds (default: 30000) |
| `--viewport WxH` | Viewport size (default: 1280x720) |
| `--no-headless` | Run with visible browser window |

## JSON Output Format

```json
{
  "url": "http://localhost:3000",
  "success": true,
  "load_time_ms": 1234,
  "title": "My App",
  "status_code": 200,
  "console_logs": [
    {"type": "log", "text": "App initialized", "location": "main.js:42"}
  ],
  "errors": [],
  "elements_found": {
    "button.submit": {"count": 1, "found": true},
    "#login-form": {"count": 1, "found": true}
  },
  "screenshot": "/absolute/path/to/screenshot.png"
}
```

## Example Workflow for Claude

1. Start your dev server: `npm run dev`
2. Run the test tool to check if the page loads:
   ```bash
   python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
       --url http://localhost:3000 \
       --console
   ```
3. If there are errors, check the console output
4. Take a screenshot to visually inspect:
   ```bash
   python ~/.local/share/devcontainer-tools/ui-test/ui-test.py \
       --url http://localhost:3000 \
       --screenshot debug.png
   ```
5. Read the screenshot with Claude's vision capabilities

## Alias (Optional)

Add to your shell profile for convenience:

```bash
alias ui-test="python ~/.local/share/devcontainer-tools/ui-test/ui-test.py"
```

Then use: `ui-test --url http://localhost:3000 --screenshot test.png`
