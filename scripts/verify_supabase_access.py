"""Read-only service checks. Login only with optional local test credentials.
No installer, import, user creation, membership change or Storage write.
Provider bodies, tokens, emails and endpoint values are never reported.
"""
from pathlib import Path
from urllib.parse import urlparse
import json
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]

def main():
    values = {}
    for name in ('.env', '.env.local'):
        file = ROOT / name
        if file.exists():
            for line in file.read_text(encoding='utf-8-sig').splitlines():
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    values[key.strip()] = value.strip().strip('"').strip("'")
    parsed = urlparse(values.get('NEXT_PUBLIC_SUPABASE_URL', ''))
    key = values.get('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY', '')
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or not key:
        raise SystemExit('Invalid or missing URL/publishable-key configuration; values omitted.')
    base = parsed.scheme + '://' + parsed.netloc
    checks = []

    def request(path, token=None, body=None):
        headers = {'apikey': key, 'Accept': 'application/json'}
        if token: headers['Authorization'] = 'Bearer ' + token
        data = None
        if body is not None:
            headers['Content-Type'] = 'application/json'
            data = json.dumps(body).encode()
        try:
            with urllib.request.urlopen(urllib.request.Request(base + path, headers=headers, data=data), timeout=15) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            # Preserve only an allowlisted machine error code, never provider messages.
            try: code = json.loads(error.read()).get('code')
            except Exception: code = None
            return error.code, {'code': code if code in ('PGRST205', 'PGRST301', '42501', 'PGRST106') else None}
        except (urllib.error.URLError, TimeoutError):
            return 0, None

    def record(name, status, ok, detail=None):
        item = {'check': name, 'result': 'passed' if ok else 'failed', 'http_status': status}
        if detail: item['detail'] = detail
        checks.append(item)
        print(json.dumps(item), flush=True)

    status, _ = request('/auth/v1/health')
    record('Auth health', status, status == 200)
    status, _ = request('/auth/v1/user', 'invalid-verification-token')
    record('Invalid Auth token rejected', status, status in (401, 403))

    def inspect(role, token=None):
        status, body = request('/rest/v1/products?select=id&limit=1', token)
        record(role + ' products endpoint', status, status == 200 and isinstance(body, list),
               'No row contents retained; endpoint reachability alone does not prove draft RLS.' if status == 200 else 'Check table, grants, exposed public schema and schema cache.')
        status, body = request('/rest/v1/rpc/is_admin', token, {})
        record(role + ' membership', status, status == 200 and body is (role == 'admin'))
        status, body = request('/rest/v1/rpc/admin_search_catalog', token, {'p_query': '', 'p_limit': 1, 'p_offset': 0})
        record(role + ' admin search authorization', status,
               status == 200 and isinstance(body, list) if role == 'admin' else status in (401, 403))
        for table in ('orders', 'import_records', 'audit_logs'):
            status, body = request('/rest/v1/' + table + '?select=id&limit=1', token)
            ok = status == 200 and isinstance(body, list) if role == 'admin' else status in (401, 403) or status == 200 and body == []
            record(role + ' ' + table + ' read restriction', status, ok,
                   'Empty results without seeded private fixtures are not a complete data-leak test.' if status == 200 and body == [] else None)
        status, body = request('/storage/v1/object/list/catalog-private', token, {'prefix': '', 'limit': 1})
        ok = status == 200 and isinstance(body, list) if role == 'admin' else status in (401, 403) or status == 200 and body == []
        record(role + ' private Storage listing', status, ok,
               'Listing only; known-object download/upload isolation remains pending.')

    inspect('anonymous')
    for role, prefix in [('non-admin', 'TEST_USER'), ('admin', 'TEST_ADMIN')]:
        email, password = values.get(prefix + '_EMAIL'), values.get(prefix + '_PASSWORD')
        if not email or not password:
            checks.append({'check': role + ' actual login/access', 'result': 'pending', 'detail': 'Local test-account credentials unavailable.'})
            continue
        status, session = request('/auth/v1/token?grant_type=password', body={'email': email, 'password': password})
        token = session.get('access_token') if isinstance(session, dict) else None
        record(role + ' login', status, status == 200 and bool(token))
        if not token: continue
        status, user = request('/auth/v1/user', token)
        expected_id = session.get('user', {}).get('id')
        valid = status == 200 and isinstance(user, dict) and expected_id and user.get('id') == expected_id
        record(role + ' server token validation', status, bool(valid))
        if valid: inspect(role, token)
    report = {'checks': checks, 'database_writes': 0, 'storage_writes': 0,
              'limitations': ['SQL grants/exposure metadata not directly inspected over a privileged connection.',
                              'No fixture rows or objects created; empty-result checks have limited coverage.',
                              'Server-only TypeScript wrapper not invoked by this Python HTTP verifier.']}
    (ROOT / 'docs/supabase-live-access-checks.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
