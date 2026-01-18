#!/usr/bin/env python3
"""
UI Testing Tool for AI Coding Agents

A Playwright-based utility that allows AI agents to directly test webapps,
take screenshots, check elements, and view console logs without needing
full browser MCP integration.

Usage:
    ui-test.py --url http://localhost:3000
    ui-test.py --url http://localhost:3000 --screenshot home.png
    ui-test.py --url http://localhost:3000 --check-elements "button.submit,#login-form"
    ui-test.py --url http://localhost:3000 --console
    ui-test.py --url http://localhost:3000 --screenshot test.png --console --json

Requirements:
    pip install playwright
    playwright install chromium
"""

import argparse
import json
import sys
import time
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("Error: Playwright not installed. Run: pip install playwright && playwright install chromium")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="UI testing tool for AI coding agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Basic page load check
    %(prog)s --url http://localhost:3000

    # Take a screenshot
    %(prog)s --url http://localhost:3000 --screenshot home.png

    # Check for specific elements
    %(prog)s --url http://localhost:3000 --check-elements "button,form,#main"

    # Get console logs
    %(prog)s --url http://localhost:3000 --console

    # Full test with JSON output
    %(prog)s --url http://localhost:3000 --screenshot test.png --console --json

    # Wait for specific element before screenshot
    %(prog)s --url http://localhost:3000 --wait-for "#app-loaded" --screenshot ready.png
        """
    )

    parser.add_argument("--url", required=True, help="URL to navigate to")
    parser.add_argument("--screenshot", metavar="FILE", help="Take screenshot and save to FILE")
    parser.add_argument("--check-elements", metavar="SELECTORS",
                        help="Comma-separated CSS selectors to check for")
    parser.add_argument("--console", action="store_true", help="Capture and show console logs")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    parser.add_argument("--wait-for", metavar="SELECTOR",
                        help="Wait for element before proceeding")
    parser.add_argument("--timeout", type=int, default=30000,
                        help="Timeout in ms (default: 30000)")
    parser.add_argument("--viewport", default="1280x720",
                        help="Viewport size WIDTHxHEIGHT (default: 1280x720)")
    parser.add_argument("--headless", action="store_true", default=True,
                        help="Run in headless mode (default: True)")
    parser.add_argument("--no-headless", action="store_false", dest="headless",
                        help="Run with visible browser")

    args = parser.parse_args()

    # Parse viewport
    try:
        width, height = map(int, args.viewport.split("x"))
    except ValueError:
        print(f"Error: Invalid viewport format '{args.viewport}'. Use WIDTHxHEIGHT (e.g., 1280x720)")
        sys.exit(1)

    result = {
        "url": args.url,
        "success": False,
        "load_time_ms": None,
        "title": None,
        "console_logs": [],
        "errors": [],
        "elements_found": {},
        "screenshot": None,
    }

    console_logs = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=args.headless)
        context = browser.new_context(viewport={"width": width, "height": height})
        page = context.new_page()

        # Capture console logs if requested
        if args.console:
            def handle_console(msg):
                console_logs.append({
                    "type": msg.type,
                    "text": msg.text,
                    "location": f"{msg.location.get('url', '')}:{msg.location.get('lineNumber', '')}"
                })
            page.on("console", handle_console)

            def handle_error(error):
                result["errors"].append(str(error))
            page.on("pageerror", handle_error)

        try:
            # Navigate to URL
            start_time = time.time()
            response = page.goto(args.url, timeout=args.timeout, wait_until="networkidle")
            load_time = int((time.time() - start_time) * 1000)

            result["load_time_ms"] = load_time
            result["title"] = page.title()
            result["status_code"] = response.status if response else None

            # Wait for specific element if requested
            if args.wait_for:
                try:
                    page.wait_for_selector(args.wait_for, timeout=args.timeout)
                except PlaywrightTimeout:
                    result["errors"].append(f"Timeout waiting for element: {args.wait_for}")

            # Check for elements
            if args.check_elements:
                selectors = [s.strip() for s in args.check_elements.split(",")]
                for selector in selectors:
                    try:
                        elements = page.query_selector_all(selector)
                        result["elements_found"][selector] = {
                            "count": len(elements),
                            "found": len(elements) > 0
                        }
                    except Exception as e:
                        result["elements_found"][selector] = {
                            "count": 0,
                            "found": False,
                            "error": str(e)
                        }

            # Take screenshot
            if args.screenshot:
                screenshot_path = Path(args.screenshot)
                page.screenshot(path=str(screenshot_path), full_page=True)
                result["screenshot"] = str(screenshot_path.absolute())

            result["success"] = True
            result["console_logs"] = console_logs

        except PlaywrightTimeout as e:
            result["errors"].append(f"Timeout: {e}")
        except Exception as e:
            result["errors"].append(f"Error: {e}")
        finally:
            browser.close()

    # Output results
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"\n{'='*60}")
        print(f"URL: {result['url']}")
        print(f"Success: {result['success']}")
        if result['title']:
            print(f"Title: {result['title']}")
        if result['load_time_ms']:
            print(f"Load time: {result['load_time_ms']}ms")
        if result.get('status_code'):
            print(f"Status: {result['status_code']}")

        if result['errors']:
            print(f"\nErrors ({len(result['errors'])}):")
            for err in result['errors']:
                print(f"  - {err}")

        if result['elements_found']:
            print(f"\nElements checked:")
            for selector, info in result['elements_found'].items():
                status = "FOUND" if info['found'] else "NOT FOUND"
                count = info['count']
                print(f"  {selector}: {status} ({count})")

        if result['console_logs']:
            print(f"\nConsole logs ({len(result['console_logs'])}):")
            for log in result['console_logs']:
                print(f"  [{log['type'].upper()}] {log['text']}")

        if result['screenshot']:
            print(f"\nScreenshot saved: {result['screenshot']}")

        print(f"{'='*60}\n")

    sys.exit(0 if result['success'] else 1)


if __name__ == "__main__":
    main()
