#!/usr/bin/env python3
#
# Puts the generated release notes into the TestFlight "What to Test" field of
# an uploaded build, one text per language, through the App Store Connect API.
#
#   upload-what-to-test.py <build number> <notes dir>
#
# Reads WhatToTest.<locale>.txt from <notes dir> (written by generate.sh) and
# the API key from ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 (the .p8 content).
#
# A freshly uploaded build only shows up in the API once App Store Connect has
# started processing it, usually a few minutes after the upload. The script
# waits for it, then updates the existing localization of each language or
# creates it.

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT

BUNDLE_ID = "de.sivery.toolbox"
LOCALES = ["de-DE", "en-US"]
API = "https://api.appstoreconnect.apple.com/v1"

# How long to wait for the build to appear in App Store Connect
WAIT_SECONDS = 30 * 60
POLL_SECONDS = 30


def token():
    """A short-lived JWT for the App Store Connect API."""
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


def request(method, path, body=None):
    """Calls the API and returns the decoded JSON response."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        details = error.read().decode(errors="replace")
        raise RuntimeError(f"{method} {path} failed with {error.code}: {details}") from None


def find_app_id():
    query = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID})
    apps = request("GET", f"/apps?{query}")["data"]
    if not apps:
        raise RuntimeError(f"No app with bundle ID {BUNDLE_ID} in App Store Connect")
    return apps[0]["id"]


def wait_for_build(app_id, build_number):
    """Returns the build's ID as soon as App Store Connect knows it."""
    query = urllib.parse.urlencode({"filter[app]": app_id, "filter[version]": build_number, "limit": 1})
    deadline = time.time() + WAIT_SECONDS
    while True:
        builds = request("GET", f"/builds?{query}")["data"]
        if builds:
            return builds[0]["id"]
        if time.time() > deadline:
            raise RuntimeError(f"Build {build_number} did not show up in App Store Connect within {WAIT_SECONDS // 60} minutes")
        print(f"Build {build_number} is not in App Store Connect yet, checking again in {POLL_SECONDS}s")
        time.sleep(POLL_SECONDS)


def set_what_to_test(build_id, locale, text, existing):
    # The API calls the "What to Test" field "whatsNew"
    if locale in existing:
        request("PATCH", f"/betaBuildLocalizations/{existing[locale]}", {
            "data": {"type": "betaBuildLocalizations", "id": existing[locale], "attributes": {"whatsNew": text}},
        })
    else:
        request("POST", "/betaBuildLocalizations", {
            "data": {
                "type": "betaBuildLocalizations",
                "attributes": {"locale": locale, "whatsNew": text},
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
            },
        })


def main():
    build_number, notes_dir = sys.argv[1], sys.argv[2]

    app_id = find_app_id()
    build_id = wait_for_build(app_id, build_number)
    print(f"Found build {build_number} ({build_id})")

    existing = {
        item["attributes"]["locale"]: item["id"]
        for item in request("GET", f"/builds/{build_id}/betaBuildLocalizations")["data"]
    }

    failed = []
    for locale in LOCALES:
        path = os.path.join(notes_dir, f"WhatToTest.{locale}.txt")
        if not os.path.isfile(path):
            print(f"::warning::{path} is missing, skipping {locale}")
            continue
        with open(path, encoding="utf-8") as file:
            text = file.read().strip()
        try:
            set_what_to_test(build_id, locale, text, existing)
            print(f"{locale}: What to Test set ({len(text)} characters)")
        except RuntimeError as error:
            # Usually means the language is not set up in TestFlight's test information
            print(f"::warning::{locale}: {error}")
            failed.append(locale)

    if failed:
        sys.exit(f"Could not set What to Test for: {', '.join(failed)}")


if __name__ == "__main__":
    main()
