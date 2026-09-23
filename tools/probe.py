# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke-test the Riot cookie-reauth -> storefront chain from this machine.

Run: uv run tools/probe.py
Paste the Cookie header from an authenticated auth.riotgames.com/authorize request when prompted
(input is hidden). Nothing is written to disk; tokens are never printed.
"""

import base64
import getpass
import json
import os
import secrets
import sys
from urllib.parse import parse_qs, urlparse

import httpx

AUTH_URL = (
    "https://auth.riotgames.com/authorize"
    "?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in"
    "&client_id=play-valorant-web-prod"
    "&response_type=token%20id_token"
    "&nonce={nonce}"
    "&scope=account%20openid"
)
USER_AGENT = "RiotGamesApi/24.11.0.4602 rso-auth (Windows;10;;Professional, x64) riot_client/0"
CLIENT_PLATFORM = (
    "ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6"
    "ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIlVua25vd24iDQp9"
)
VP = "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
CURRENCIES = {
    VP: "VP",
    "e59aa87c-4cbf-517a-5983-6e81511be9b7": "Radianite",
    "85ca954a-41f2-ce94-9b45-8ca3dd39a00d": "Kingdom Credits",
}
# Riot's geo service returns regions; the store lives on shards.
REGION_TO_SHARD = {"na": "na", "latam": "na", "br": "na", "pbe": "pbe", "eu": "eu", "ap": "ap", "kr": "kr"}
WANTED_COOKIES = ("ssid", "clid", "csid", "tdid", "asid")


def step(name: str, ok: bool, detail: str = "") -> None:
    mark = "OK  " if ok else "FAIL"
    print(f"[{mark}] {name}" + (f" - {detail}" if detail else ""))
    if not ok:
        sys.exit(1)


def parse_cookie_header(raw: str) -> dict[str, str]:
    raw = raw.strip()
    if raw.lower().startswith("cookie:"):
        raw = raw[7:]
    jar = {}
    for part in raw.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            jar[k.strip()] = v.strip()
    return {k: v for k, v in jar.items() if k in WANTED_COOKIES}


def jwt_claims(token: str) -> dict:
    payload = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))


def main() -> None:
    raw = os.environ.get("RIOT_COOKIES") or getpass.getpass("Paste Cookie header (hidden): ")
    cookies = parse_cookie_header(raw)
    step("cookies parsed", "ssid" in cookies, f"found {sorted(cookies)}")

    with httpx.Client(timeout=20, follow_redirects=False, headers={"User-Agent": USER_AGENT}) as http:
        version = http.get("https://valorant-api.com/v1/version").json()["data"]["riotClientVersion"]
        step("client version", True, version)

        cookie_header = "; ".join(f"{k}={v}" for k, v in cookies.items())
        r = http.get(
            AUTH_URL.format(nonce=secrets.token_hex(16)),
            headers={"Cookie": cookie_header, "Accept-Language": "en-US,en;q=0.9"},
        )
        location = r.headers.get("location", "")
        if "authenticate.riotgames.com/login" in location or "/login" in location:
            step("cookie reauth", False, f"HTTP {r.status_code}, session expired -> log in again with 'Stay signed in'")
        fragment = parse_qs(urlparse(location).fragment)
        access_token = fragment.get("access_token", [""])[0]
        id_token = fragment.get("id_token", [""])[0]
        step("cookie reauth", bool(access_token), f"HTTP {r.status_code}, expires_in={fragment.get('expires_in')}")

        # Informs the dual-ssid strategy: does Riot rotate ssid, and with what lifetime?
        for c in r.headers.get_list("set-cookie"):
            name = c.split("=", 1)[0]
            if name in WANTED_COOKIES:
                attrs = [a.strip() for a in c.split(";")[1:] if a.strip().lower().startswith(("expires", "max-age"))]
                print(f"       set-cookie {name}: {attrs or 'session cookie (no expiry)'}")

        bearer = {"Authorization": f"Bearer {access_token}"}
        r = http.post("https://entitlements.auth.riotgames.com/api/token/v1", headers=bearer, json={})
        entitlements = r.json().get("entitlements_token", "") if r.is_success else ""
        step("entitlements", bool(entitlements), f"HTTP {r.status_code}")

        r = http.get("https://auth.riotgames.com/userinfo", headers=bearer)
        puuid = r.json().get("sub", "") if r.is_success else ""
        step("userinfo", bool(puuid), f"HTTP {r.status_code}")

        r = http.put(
            "https://riot-geo.pas.si.riotgames.com/pas/v1/product/valorant",
            headers=bearer,
            json={"id_token": id_token},
        )
        region = r.json().get("affinities", {}).get("live", "") if r.is_success else ""
        if not region:
            region = jwt_claims(id_token).get("affinity", {}).get("pp", "")
        shard = REGION_TO_SHARD.get(region, region)
        step("region", bool(shard), f"HTTP {r.status_code}, region={region} shard={shard}")

        riot_headers = {
            **bearer,
            "X-Riot-Entitlements-JWT": entitlements,
            "X-Riot-ClientPlatform": CLIENT_PLATFORM,
            "X-Riot-ClientVersion": version,
        }
        pd = f"https://pd.{shard}.a.pvp.net"
        r = http.post(f"{pd}/store/v3/storefront/{puuid}", headers=riot_headers, json={})
        step("storefront v3", r.is_success, f"HTTP {r.status_code}" + ("" if r.is_success else f" {r.text[:200]}"))
        store = r.json()
        print(f"       top-level keys: {sorted(store)}")

        r = http.get(f"{pd}/store/v1/wallet/{puuid}", headers=riot_headers)
        step("wallet", r.is_success, f"HTTP {r.status_code}")
        balances = r.json().get("Balances", {})
        print("       " + ", ".join(f"{CURRENCIES[k]}: {v}" for k, v in balances.items() if k in CURRENCIES))

        panel = store.get("SkinsPanelLayout", {})
        hours = panel.get("SingleItemOffersRemainingDurationInSeconds", 0) / 3600
        print(f"\nDaily store (resets in {hours:.1f}h):")
        for offer in panel.get("SingleItemStoreOffers", []):
            level_id = offer["Rewards"][0]["ItemID"]
            name = http.get(f"https://valorant-api.com/v1/weapons/skinlevels/{level_id}").json()["data"]["displayName"]
            print(f"  - {name}  {offer['Cost'].get(VP, '?')} VP")

        bonus = store.get("BonusStore")
        print(f"\nNight market: {'LIVE, ' + str(len(bonus['BonusStoreOffers'])) + ' offers' if bonus else 'not active'}")
        bundles = store.get("FeaturedBundle", {}).get("Bundles", [])
        print(f"Featured bundles: {len(bundles)}")


if __name__ == "__main__":
    main()
