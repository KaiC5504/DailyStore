# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke-test the Riot cookie-reauth -> storefront chain from this machine.

Run: uv run tools/probe.py            (store)
     uv run tools/probe.py --matches  (match history, match details, rank; prints shapes only)
     uv run tools/probe.py --names    (are names blank in match details, does name-service fill them)
Paste the Cookie header from an authenticated auth.riotgames.com/authorize request when prompted
(input is hidden). Nothing is written to disk; tokens are never printed.
"""

import base64
import getpass
import json
import os
import re
import secrets
import sys
import time
from collections import defaultdict
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
        if "--matches" in sys.argv:
            probe_matches(http, pd, f"https://shared.{shard}.a.pvp.net", puuid, riot_headers)
            return
        if "--names" in sys.argv:
            probe_names(http, pd, puuid, riot_headers)
            return
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


UUID_KEY = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
# Values safe to print: game enums only. Names, tags and PUUIDs never leave the shape tree.
ENUM_KEYS = {
    "queueID", "QueueID", "gameMode", "provisioningFlowID", "completionState", "isRanked", "isCompleted",
    "roundResult", "roundResultCode", "roundCeremony", "damageType", "plantSite", "CompetitiveMovement",
}


def new_shapes():
    return defaultdict(lambda: {"types": set(), "lens": set()})


def collect(value, path, shapes, enums):
    shapes[path]["types"].add("null" if value is None else type(value).__name__)
    key = path.rsplit(".", 1)[-1]
    if isinstance(value, dict):
        for k, v in value.items():
            collect(v, f"{path}.{'{uuid}' if UUID_KEY.match(k) else k}", shapes, enums)
    elif isinstance(value, list):
        shapes[path]["lens"].add(len(value))
        for item in value:
            collect(item, f"{path}[]", shapes, enums)
    elif key in ENUM_KEYS:
        enums[key].add(repr(value))
    elif key in ("teamId", "winningTeam", "damageItem", "weapon", "armor") and isinstance(value, str):
        if UUID_KEY.match(value):
            case = "upper" if value.upper() == value else "lower" if value.lower() == value else "mixed"
            enums[key].add(f"<uuid {case}>")
        elif value in ("Red", "Blue", "Neutral", "") or key in ("damageItem", "weapon", "armor"):
            enums[key].add(repr(value))
        else:
            enums[key].add(f"<other, {len(value)} chars>")


def describe(entry):
    text = "|".join(sorted(entry["types"]))
    if entry["lens"]:
        text += f"  n={min(entry['lens'])}..{max(entry['lens'])}"
    return text


def print_shape(title, shapes, baseline=None):
    print(f"\n  shape: {title}")
    for path in sorted(shapes):
        if baseline is None:
            print(f"    {path}: {describe(shapes[path])}")
        elif path not in baseline:
            print(f"    + {path}: {describe(shapes[path])}")
        elif shapes[path]["types"] != baseline[path]["types"]:
            print(f"    ~ {path}: {describe(shapes[path])} (was {describe(baseline[path])})")
    if baseline is not None:
        for path in sorted(set(baseline) - set(shapes)):
            print(f"    - {path}")


def print_enums(enums):
    for key in sorted(enums):
        print(f"    {key}: {', '.join(sorted(enums[key]))}")


def fetch(http, url, headers, label, quiet=False):
    time.sleep(0.4)
    r = http.get(url, headers=headers)
    extra = f", retry-after={r.headers['retry-after']}" if "retry-after" in r.headers else ""
    if not r.is_success:
        extra += f" {r.text[:160]}"
    if not quiet or not r.is_success:
        mark = "OK  " if r.is_success else "FAIL"
        print(f"[{mark}] {label} - HTTP {r.status_code}, {len(r.content) / 1024:.0f} KB{extra}")
    return r.json() if r.is_success else None


def day(ms):
    return time.strftime("%Y-%m-%d", time.gmtime(ms / 1000))


def probe_matches(http, pd, shared, puuid, headers):
    print("\n== Match history ==")
    page = fetch(http, f"{pd}/match-history/v1/history/{puuid}?startIndex=0&endIndex=20", headers, "history 0-20")
    if not page:
        return
    history = page.get("History", [])
    total = page.get("Total")
    queues = defaultdict(int)
    for h in history:
        queues[h.get("QueueID")] += 1
    print(f"       keys {sorted(page)}; Total={total}; returned {len(history)}")
    print(f"       history item keys: {sorted(history[0]) if history else '-'}")
    print(f"       queues on page 0: {dict(queues)}")
    if history:
        print(f"       newest {day(history[0]['GameStartTime'])}, page-0 oldest {day(history[-1]['GameStartTime'])}")

    wide = fetch(http, f"{pd}/match-history/v1/history/{puuid}?startIndex=0&endIndex=40", headers, "history 0-40 (page cap)")
    if wide:
        print(f"       asked for 40, got {len(wide.get('History', []))}")
    ranked = fetch(http, f"{pd}/match-history/v1/history/{puuid}?startIndex=0&endIndex=20&queue=competitive",
                   headers, "history queue=competitive")
    if ranked:
        seen = {h.get("QueueID") for h in ranked.get("History", [])}
        print(f"       Total={ranked.get('Total')}, queues returned {seen}")
    if isinstance(total, int) and total > 20:
        tail = fetch(http, f"{pd}/match-history/v1/history/{puuid}?startIndex={total - 20}&endIndex={total}",
                     headers, f"history last page ({total - 20}-{total})")
        if tail and tail.get("History"):
            print(f"       oldest match Riot still lists: {day(tail['History'][-1]['GameStartTime'])}")

    print("\n== valorant-api.com lookups ==")
    maps = {m["mapUrl"] for m in http.get("https://valorant-api.com/v1/maps").json()["data"]}
    agents = {a["uuid"].lower() for a in http.get("https://valorant-api.com/v1/agents?isPlayableCharacter=true").json()["data"]}
    weapons = {w["uuid"].lower() for w in http.get("https://valorant-api.com/v1/weapons").json()["data"]}
    gear = {g["uuid"].lower() for g in http.get("https://valorant-api.com/v1/gear").json()["data"]}
    print(f"       maps {len(maps)}, agents {len(agents)}, weapons {len(weapons)}, gear {len(gear)}")

    picked, seen_queues = [], set()
    for h in history:
        if not picked or h.get("QueueID") not in seen_queues:
            picked.append(h)
            seen_queues.add(h.get("QueueID"))
    picked = picked[:6]

    print("\n== Match details ==")
    baseline = None
    for index, h in enumerate(picked, 1):
        body = fetch(http, f"{pd}/match-details/v1/matches/{h['MatchID']}", headers,
                     f"details #{index} ({h.get('QueueID')!r})")
        if not body:
            continue
        shapes, enums = new_shapes(), defaultdict(set)
        collect(body, "$", shapes, enums)
        info = body.get("matchInfo", {})
        players = body.get("players") or []
        rounds = body.get("roundResults") or []
        teams = body.get("teams") or []
        me = next((p for p in players if p.get("subject") == puuid), None)
        print(f"       mode {info.get('gameMode')}, players {len(players)}, rounds {len(rounds)}, "
              f"teams {len(teams)}, length {(info.get('gameLengthMillis') or 0) // 60000} min, "
              f"owner in players: {me is not None}")
        if teams:
            print(f"       team fields: " + "; ".join(
                f"won={t.get('won')} roundsWon={t.get('roundsWon')} numPoints={t.get('numPoints')}" for t in teams[:4])
                + (" ..." if len(teams) > 4 else ""))
        weapon_ids = [k["finishingDamage"]["damageItem"] for r in rounds for s in r.get("playerStats") or []
                      for k in s.get("kills") or [] if UUID_KEY.match((k.get("finishingDamage") or {}).get("damageItem") or "")]
        econ = [s.get("economy") or {} for r in rounds for s in r.get("playerStats") or []]
        print(f"       joins: map {'OK' if info.get('mapId') in maps else 'MISSING ' + repr(info.get('mapId'))}; "
              f"agents unknown {sum(p.get('characterId', '').lower() not in agents for p in players)}/{len(players)}; "
              f"kill weapons unknown {sum(w.lower() not in weapons for w in weapon_ids)}/{len(weapon_ids)}; "
              f"loadout weapons unknown {sum(bool(e.get('weapon')) and e['weapon'].lower() not in weapons for e in econ)}; "
              f"armor unknown {sum(bool(e.get('armor')) and e['armor'].lower() not in gear for e in econ)}")
        print_shape(f"details #{index}" + (" (full)" if baseline is None else " (diff vs #1)"), shapes, baseline)
        print("  values:")
        print_enums(enums)
        if baseline is None:
            baseline = shapes

    print("\n== Rank ==")
    for end in (20, 40):
        updates = fetch(http, f"{pd}/mmr/v1/players/{puuid}/competitiveupdates?startIndex=0&endIndex={end}&queue=competitive",
                        headers, f"competitiveupdates 0-{end}")
        if updates:
            print(f"       returned {len(updates.get('Matches', []))}")
            if end == 20:
                shapes, enums = new_shapes(), defaultdict(set)
                collect(updates, "$", shapes, enums)
                print_shape("competitiveupdates", shapes)
                print_enums(enums)
                ids = {h["MatchID"] for h in history}
                print(f"       update MatchIDs also in history page 0: "
                      f"{sum(m['MatchID'] in ids for m in updates.get('Matches', []))}")

    mmr = fetch(http, f"{pd}/mmr/v1/players/{puuid}", headers, "mmr")
    if mmr:
        shapes, enums = new_shapes(), defaultdict(set)
        collect(mmr, "$", shapes, enums)
        print_shape("mmr", shapes)
        print(f"       QueueSkills keys: {sorted((mmr.get('QueueSkills') or {}).keys())}")

    content = fetch(http, f"{shared}/content-service/v3/content", headers, "content-service v3")
    if content:
        acts = [s for s in content.get("Seasons", []) if s.get("IsActive") and s.get("Type") == "act"]
        print(f"       keys {sorted(content)}; seasons {len(content.get('Seasons', []))}; "
              f"active act: {[(a.get('Name'), a.get('ID')) for a in acts]}")
        if mmr and acts:
            seasonal = ((mmr.get("QueueSkills") or {}).get("competitive") or {}).get("SeasonalInfoBySeasonID") or {}
            info = seasonal.get(acts[0]["ID"])
            print(f"       current act in mmr: {'yes, tier ' + str(info.get('CompetitiveTier')) if info else 'no entry'}")


def probe_names(http, pd, puuid, headers):
    """Counts only: names and tags are never printed."""
    page = fetch(http, f"{pd}/match-history/v1/history/{puuid}?startIndex=0&endIndex=5", headers, "history 0-5")
    for h in (page or {}).get("History", [])[:3]:
        body = fetch(http, f"{pd}/match-details/v1/matches/{h['MatchID']}", headers, f"details ({h.get('QueueID')!r})")
        if not body:
            continue
        players = body.get("players") or []
        owner = next((p for p in players if p.get("subject") == puuid), {})
        print(f"       players {len(players)}; blank gameName {sum(not p.get('gameName') for p in players)}; "
              f"blank tagLine {sum(not p.get('tagLine') for p in players)}; owner name blank: {not owner.get('gameName')}")
        ids = [p["subject"] for p in players]
        time.sleep(0.4)
        r = http.put(f"{pd}/name-service/v2/players", headers=headers, json=ids)
        print(f"[{'OK  ' if r.is_success else 'FAIL'}] name-service v2 - HTTP {r.status_code}"
              + ("" if r.is_success else f" {r.text[:160]}"))
        if r.is_success:
            rows = r.json()
            print(f"       rows {len(rows)}; keys {sorted(rows[0]) if rows else '-'}; "
                  f"GameName filled {sum(bool(x.get('GameName')) for x in rows)}; "
                  f"TagLine filled {sum(bool(x.get('TagLine')) for x in rows)}; "
                  f"subjects match {len({x.get('Subject') for x in rows} & set(ids))}/{len(ids)}")


if __name__ == "__main__":
    main()
