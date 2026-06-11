module {
  name: "bar/librelinkup",
  summary: "Use the LibreLinkup API to continuously print blood glucose values from the FreeStyle Libre continuous glucose monitor. Currently very basic."
};

def request:
  ["curl", "-L",
    ("-X", .method // "GET"),
    ("--compressed"),
    (if .data then "--data", (.data | tojson) else empty end),
    (.headers // empty | to_entries[] | "-H", "\(.key): \(.value)"),
    "\(.domain)\(.endpoint)"
  ] |
  exec(.) | fromjson;

def sha256:
  exec(["cksum", "--algorithm=sha256", "--untagged"]) |
  split(" ")[0];

def regions: {
    "eu": "https://api-eu.libreview.io",
    "eu2": "https://api-eu2.libreview.io",
    "us": "https://api.libreview.io",
    "ae": "https://api-ae.libreview.io",
    "ap": "https://api-ap.libreview.io",
    "au": "https://api-au.libreview.io",
    "ca": "https://api-ca.libreview.io",
    "de": "https://api-de.libreview.io",
    "fr": "https://api-fr.libreview.io",
    "jp": "https://api-jp.libreview.io",
    "la": "https://api-la.libreview.io",
    "ru": "https://api.libreview.ru"
};

def base_headers:
  {
    "Cache-control": "no-cache",
    "Content-type": "application/json",
    "Product": "llu.android",
    "Version": "4.16.0",
  };

def request_base_from_token:
  if "LIBRELINKUP_TOKEN" | in(env) then
    env.LIBRELINKUP_TOKEN as $token |
    ($token | split(".")[1] | @base64d | fromjson) as {$region, $id} |
    {
      domain: regions[$region],
      headers: base_headers + {
        "Authorization": "Bearer \($token)",
        "account-id": $id | sha256
      }
    }
  else
    error("no LIBRELINKUP_TOKEN in environment")
  end;

# Produce LIBRELINKUP_TOKEN from a {email: "", password: ""} object
def login($domain):
  {
    domain: $domain,
    endpoint: "/llu/auth/login",
    headers: base_headers,
    data: .
  } | request;

def current_glucose:
  request_base_from_token |
  .endpoint = "/llu/connections" |
  request |
  .data[0].glucoseItem.Value;

def blocks:
  (current_glucose | [{full_text: "\uf043 \(.)"}]),
  sleep(60),
  blocks;
