#!/usr/bin/env python3
"""Member 1 cloud hardening for aquatrace-92e2e (Firebase CLI login required).

Actions:
  1. Enable Email/Password in Identity Toolkit
  2. Restrict Firebase auto-created API keys (Android/iOS/Browser)
  3. Seed bootstrap admin + technician Auth users and /users docs

Never prints access tokens or full Google API keys.
Staff passwords are written only to a gitignored local file.
"""

from __future__ import annotations

import json
import pathlib
import secrets
import string
import sys
import urllib.error
import urllib.request

PROJECT = "aquatrace-92e2e"
PACKAGE = "com.aquatrace.aquatrace"
BUNDLE = "com.aquatrace.aquatrace"
WEB_REFERRERS = [
    "http://localhost",
    "http://localhost:*",
    "http://127.0.0.1",
    "http://127.0.0.1:*",
    "https://aquatrace-92e2e.firebaseapp.com/*",
    "https://aquatrace-92e2e.web.app/*",
]
ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCAL_CREDS = ROOT / "scripts" / ".seed_credentials.local.json"


def load_access_token() -> str:
    cfg_path = pathlib.Path.home() / ".config/configstore/firebase-tools.json"
    data = json.loads(cfg_path.read_text())
    access = None

    def walk(obj):
        nonlocal access
        if isinstance(obj, dict):
            tok = obj.get("access_token")
            if isinstance(tok, str) and len(tok) > 20:
                access = tok
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)

    walk(data)
    if not access:
        raise SystemExit("No Firebase CLI access token. Run: firebase login")
    return access


def http_json(
    method: str,
    url: str,
    *,
    bearer: str | None = None,
    body: dict | None = None,
) -> dict:
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace")
        raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {err[:600]}") from e


def enable_email_password(token: str) -> None:
    url = (
        f"https://identitytoolkit.googleapis.com/admin/v2/projects/{PROJECT}/config"
        "?updateMask=signIn.email"
    )
    result = http_json(
        "PATCH",
        url,
        bearer=token,
        body={"signIn": {"email": {"enabled": True, "passwordRequired": True}}},
    )
    email = (result.get("signIn") or {}).get("email") or {}
    print("AUTH_EMAIL_PASSWORD=", "enabled" if email.get("enabled") else result)


def restrict_api_keys(token: str, sha1: str) -> None:
    list_url = (
        f"https://apikeys.googleapis.com/v2/projects/{PROJECT}/locations/global/keys"
    )
    keys = http_json("GET", list_url, bearer=token).get("keys", [])
    print("API_KEYS_FOUND=", len(keys))
    for key in keys:
        name = key["name"]
        display = key.get("displayName", "")
        existing = key.get("restrictions") or {}
        api_targets = existing.get("apiTargets") or []
        restrictions: dict = {"apiTargets": api_targets}
        if "Android" in display:
            restrictions["androidKeyRestrictions"] = {
                "allowedApplications": [
                    {"packageName": PACKAGE, "sha1Fingerprint": sha1}
                ]
            }
            kind = "android"
        elif "iOS" in display:
            restrictions["iosKeyRestrictions"] = {"allowedBundleIds": [BUNDLE]}
            kind = "ios"
        elif "Browser" in display:
            restrictions["browserKeyRestrictions"] = {
                "allowedReferrers": WEB_REFERRERS
            }
            kind = "browser"
        else:
            print("SKIP_UNKNOWN_KEY=", display)
            continue
        # List responses return relative resource names; PATCH needs absolute URL.
        resource = name if name.startswith("http") else (
            "https://apikeys.googleapis.com/v2/" + name.lstrip("/")
        )
        http_json(
            "PATCH",
            resource + "?updateMask=restrictions",
            bearer=token,
            body={"restrictions": restrictions},
        )
        # Verify
        updated = http_json("GET", resource, bearer=token)
        restr = updated.get("restrictions") or {}
        has_app = bool(
            restr.get("androidKeyRestrictions")
            or restr.get("iosKeyRestrictions")
            or restr.get("browserKeyRestrictions")
        )
        print(f"RESTRICTED_{kind.upper()}=", "ok" if has_app else "FAILED")


def gen_password() -> str:
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return "".join(secrets.choice(alphabet) for _ in range(20))


def ensure_auth_user(token: str, email: str, password: str, display_name: str) -> str:
    """Create Auth users via Admin API (works after Browser API-key restrictions)."""
    create_url = (
        f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts"
    )
    try:
        resp = http_json(
            "POST",
            create_url,
            bearer=token,
            body={
                "email": email,
                "password": password,
                "displayName": display_name,
                "emailVerified": True,
            },
        )
        uid = resp.get("localId") or resp.get("userId")
        if not uid:
            raise RuntimeError(f"create_missing_uid keys={list(resp.keys())}")
        return uid
    except RuntimeError as e:
        if "EMAIL_EXISTS" not in str(e) and "EMAIL_EXISTS" not in str(e).upper():
            # Try lookup by email
            lookup = (
                f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:lookup"
            )
            try:
                looked = http_json(
                    "POST",
                    lookup,
                    bearer=token,
                    body={"email": [email]},
                )
                users = looked.get("users") or []
                if users:
                    # Reset password so local seed file remains usable
                    uid = users[0]["localId"]
                    http_json(
                        "POST",
                        f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:update",
                        bearer=token,
                        body={
                            "localId": uid,
                            "password": password,
                            "displayName": display_name,
                        },
                    )
                    return uid
            except RuntimeError:
                pass
            raise
        # EMAIL_EXISTS path
        lookup = (
            f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:lookup"
        )
        looked = http_json("POST", lookup, bearer=token, body={"email": [email]})
        users = looked.get("users") or []
        if not users:
            raise
        uid = users[0]["localId"]
        http_json(
            "POST",
            f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:update",
            bearer=token,
            body={
                "localId": uid,
                "password": password,
                "displayName": display_name,
            },
        )
        return uid


def write_user_doc(token: str, uid: str, person: dict) -> None:
    doc_url = (
        f"https://firestore.googleapis.com/v1/projects/{PROJECT}/"
        f"databases/(default)/documents/users/{uid}"
    )
    fields = {
        "uid": {"stringValue": uid},
        "email": {"stringValue": person["email"]},
        "displayName": {"stringValue": person["displayName"]},
        "phoneNumber": {"stringValue": person["phoneNumber"]},
        "role": {"stringValue": person["role"]},
        "assignedArea": {"stringValue": person["assignedArea"]},
        "employeeId": {"stringValue": person["employeeId"]},
        "createdAt": {"stringValue": "2026-11-03T18:30:00.000Z"},
    }
    http_json("PATCH", doc_url, bearer=token, body={"fields": fields})


def seed_staff(token: str) -> None:
    staff = [
        {
            "email": "admin@aquatrace.lk",
            "displayName": "Water Board Admin",
            "role": "admin",
            "employeeId": "WB-ADMIN-001",
            "assignedArea": "Colombo",
            "phoneNumber": "+94 11 000 0001",
        },
        {
            "email": "tech@aquatrace.lk",
            "displayName": "Field Technician",
            "role": "technician",
            "employeeId": "WB-2024-087",
            "assignedArea": "Colombo 03",
            "phoneNumber": "+94 77 000 0002",
        },
    ]
    out = {"project": PROJECT, "users": []}
    for person in staff:
        password = gen_password()
        try:
            uid = ensure_auth_user(
                token, person["email"], password, person["displayName"]
            )
        except RuntimeError as e:
            print(f"SEED_AUTH_FAIL role={person['role']} err={str(e)[:220]}")
            continue
        write_user_doc(token, uid, person)
        out["users"].append(
            {
                "email": person["email"],
                "role": person["role"],
                "uid": uid,
                "password": password,
                "note": "Change immediately after first login",
            }
        )
        print(f"SEEDED role={person['role']} email={person['email']} uid={uid[:8]}…")
    LOCAL_CREDS.write_text(json.dumps(out, indent=2) + "\n")
    print("SEED_CREDENTIALS_FILE=", str(LOCAL_CREDS.relative_to(ROOT)))


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: member1_cloud_hardening.py <sha1-with-or-without-colons>")
        raise SystemExit(2)
    sha1 = "".join(ch for ch in sys.argv[1] if ch.isalnum()).upper()
    token = load_access_token()
    print("PROJECT=", PROJECT)
    enable_email_password(token)
    restrict_api_keys(token, sha1)
    seed_staff(token)
    print("DONE")


if __name__ == "__main__":
    main()
