#!/bin/bash

PANEL_PATH="/var/www/pterodactyl"
GITHUB_ZIP="https://raw.githubusercontent.com/CodeByCruel/AvtixTheme/main/Hyper-modified.zip"
API_URL="https://vt-panel-api.vercel.app/api/index"
THEME_DB_KEY="settings::app:theme:hyperv2"

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Must be run as root."
    exit 1
fi

php() { php8.4 "$@"; }
composer() { php8.4 /usr/local/bin/composer "$@"; }
export -f php
export -f composer

send_approval_request() {
    VPS_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    VPS_HOSTNAME=$(hostname -f 2>/dev/null || hostname)
    VPS_OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -sr)
    echo "[*] Sending install request to VexyThemes..."
    RESPONSE=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "{\"_endpoint\":\"install\",\"action\":\"request\",\"ip\":\"$VPS_IP\",\"hostname\":\"$VPS_HOSTNAME\",\"os\":\"$VPS_OS\"}")
    REQUEST_ID=$(echo "$RESPONSE" | grep -o '"requestId":"[^"]*"' | cut -d'"' -f4)
    if [[ -z "$REQUEST_ID" ]]; then echo "Warning: Could not send request. Continuing..."; return; fi
    echo "Waiting for approval (Request: $REQUEST_ID)..."
    MAX_WAIT=300; ELAPSED=0; STATUS="pending"
    while [[ "$STATUS" == "pending" && $ELAPSED -lt $MAX_WAIT ]]; do
        sleep 5; ELAPSED=$((ELAPSED + 5))
        CHECK=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "{\"_endpoint\":\"install\",\"action\":\"check\",\"requestId\":\"$REQUEST_ID\"}")
        STATUS=$(echo "$CHECK" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [[ "$STATUS" == "approved" ]]; then echo "Approved!"; break; fi
        if [[ "$STATUS" == "denied" ]]; then echo "Denied."; exit 1; fi
    done
    if [[ "$STATUS" == "pending" ]]; then echo "Timed out."; exit 1; fi
}

download_theme() {
    TMP=$(mktemp -d)
    THEME_ZIP="$TMP/Hyper-modified.zip"
    if [[ -f "./Hyper-modified.zip" ]]; then
        cp "./Hyper-modified.zip" "$THEME_ZIP"
    elif [[ -f "$SCRIPT_DIR/Hyper-modified.zip" ]]; then
        cp "$SCRIPT_DIR/Hyper-modified.zip" "$THEME_ZIP"
    else
        echo "Downloading Avtix theme..."
        curl -fSL --retry 3 --progress-bar -o "$THEME_ZIP" "$GITHUB_ZIP"
    fi
    echo "Extracting theme..."
    unzip -oq "$THEME_ZIP" -d "$TMP/extract"
    INNER="$TMP/extract"
    [[ -d "$TMP/extract/Hyper-modified" ]] && INNER="$TMP/extract/Hyper-modified"
}

apply_theme() {
    echo "Applying theme..."
    rm -rf "$PANEL_PATH/public/assets" "$PANEL_PATH/public/DGEN" 2>/dev/null || true
    cp -rf "$INNER/public/"* "$PANEL_PATH/public/" 2>/dev/null || true
    rm -rf "$PANEL_PATH/resources/views" 2>/dev/null || true
    cp -rf "$INNER/resources/views" "$PANEL_PATH/resources/" 2>/dev/null || true
    cp -rf "$INNER/resources/lang" "$PANEL_PATH/resources/" 2>/dev/null || true
    cp -f "$INNER/routes/"*.php "$PANEL_PATH/routes/" 2>/dev/null || true
    for f in "$INNER/config/"*.php; do
        fname=$(basename "$f")
        case "$fname" in database.php|app.php|cache.php|sessions.php|queue.php|logging.php|mail.php) continue ;; esac
        cp -f "$f" "$PANEL_PATH/config/" 2>/dev/null || true
    done
    rm -rf "$PANEL_PATH/database" 2>/dev/null || true
    cp -rf "$INNER/database" "$PANEL_PATH/"
    cp -f "$INNER/composer.json" "$INNER/composer.lock" "$PANEL_PATH/" 2>/dev/null || true
    echo "Theme applied."
}

cleanup_duplicates() {
    echo "Cleaning up duplicate files..."
    # Remove nested controller duplicates (from bad copy operations)
    rm -rf "$PANEL_PATH/app/Http/Controllers/app/" 2>/dev/null || true
    echo "  Duplicate directories cleaned"
}

replace_ioncube_files() {
    echo "Replacing ionCube files..."
    COUNT=$(find "$PANEL_PATH/app" -name '*.php' -exec grep -l 'ionCube' {} \; 2>/dev/null | wc -l)
    echo "Found $COUNT ionCube files."
    if [[ "$COUNT" -gt 0 ]]; then
        find "$PANEL_PATH/app" -name '*.php' -exec grep -l 'ionCube' {} \; 2>/dev/null | while IFS= read -r filepath; do
            classname=$(basename "$filepath" .php)
            relpath="${filepath#$PANEL_PATH/app/}"
            dirpath=$(dirname "$relpath")
            namespace="Pterodactyl"
            [[ "$dirpath" != "." ]] && namespace="Pterodactyl\\$(echo "$dirpath" | sed 's|/|\\|g')"
            cat > "$filepath" <<STUBEOF
<?php
namespace $namespace;
class $classname { public function __call(\$m, \$a) { return response()->json(["data" => []]); } public static function __callStatic(\$m, \$a) { return response()->json(["data" => []]); } }
STUBEOF
        done
        echo "Replaced $(find "$PANEL_PATH/app" -name '*.php' -exec grep -l 'ionCube' {} \; 2>/dev/null | wc -l) remaining."
    fi
}

patch_js_files() {
    echo "Patching JS files..."

    # 1. Replace entry.8ve3mcm4.js with always-valid license service
    cat > "$PANEL_PATH/public/assets/entry.8ve3mcm4.js" << 'JSEOF'
class i{static instance;cachedVerification={valid:!0,tier:"ultimate",status:"active",validity:"Valid",community:!1,sso_connected:!0,features:["sso","billing","store","subdomains","recyclebin","serversplitter","fivem","minecraft","arma"],panel_type:"Avtix Game Panel",panel_version:"v1.0",license_key:"avtix-enterprise",verified_at:new Date().toISOString()};pendingVerification=null;cachedStatus={status:{valid:!0,tier:"ultimate",status:"active"},ts:Date.now()};statusTTL=43200000;constructor(){}static getInstance(){if(!i.instance)i.instance=new i;return i.instance}async fetchFromServer(){return this.cachedVerification}async requestVerification(){return this.cachedVerification}async verifyLicense(){window.dispatchEvent(new CustomEvent("license-verified",{detail:this.cachedVerification}));return this.cachedVerification}async getLicenseStatus(){return this.cachedStatus.status}hasCategory(){return!0}isBasicModeEnabled(){return!0}isPremiumModeEnabled(){return!0}isUltimateModeEnabled(){return!0}isMinecraftModeEnabled(){return!0}isEssentialsModeEnabled(){return!0}isSpecialModeEnabled(){return!0}isMinecraftFeatureEnabled(){return!0}isEssentialsFeatureEnabled(){return!0}isSpecialFeatureEnabled(){return!0}isPrivateModeEnabled(){return!0}isPrivateFeatureEnabled(){return!0}shouldEnableMinecraftAddon(){return!0}shouldEnableEssentialsAddon(){return!0}shouldEnableSpecialAddon(){return!0}shouldEnablePrivateAddon(){return!0}isArkModeEnabled(){return!0}isArkFeatureEnabled(){return!0}shouldEnableArkAddon(){return!0}isHytaleModeEnabled(){return!0}isHytaleFeatureEnabled(){return!0}shouldEnableHytaleAddon(){return!0}hasSpecificFeature(){return!0}isFivemModeEnabled(){return!0}isFivemFeatureEnabled(){return!0}shouldEnableFivemAddon(){return!0}isPartnershipModeEnabled(){return!0}isCommunityVersion(){return!1}hasCachedVerification(){return!0}getCachedVerification(){return this.cachedVerification}backgroundReVerify(){}clearVerificationData(){}clearLegacyBrowserVerification(){}}
var n=i.getInstance(),s=n;
export{n as Bp,s as Cp};
JSEOF
    echo "  entry.8ve3mcm4.js replaced (always valid)"

    # 2. Replace LicenseMonitor
    echo 'export default function LicenseMonitor(){return null;}' > "$PANEL_PATH/public/assets/LicenseMonitor.wvnehtfj.js"

    # 3. Replace licenseService
    cat > "$PANEL_PATH/public/assets/licenseService.1tf8btsy.js" << 'LSEOF'
export function verifyLicense(){return Promise.resolve({valid:true,reason:null})}
export function getLicenseStatus(){return Promise.resolve({valid:true,status:"active"})}
export function clearVerificationData(){}
export default {verifyLicense:function(){return Promise.resolve({valid:true,reason:null})},getLicenseStatus:function(){return Promise.resolve({valid:true,status:"active"})},clearVerificationData:function(){}};
LSEOF
    echo "  LicenseMonitor + licenseService stubbed"

    # 4. Stub StarsCanvas (JSX -> null to prevent SyntaxError)
    echo 'export default function StarsCanvas(){return null;}' > "$PANEL_PATH/public/assets/StarsCanvas.gqjbwh14.js"
    echo "  StarsCanvas stubbed (removed broken particles)"

    # 5. Patch App.z9y3z1nk.js - neutralize Yo (dialog), Nr, Tr, MutationObserver fix
    python3 << 'PYEOF'
import re, os

path = "/var/www/pterodactyl/public/assets/App.z9y3z1nk.js"
if not os.path.exists(path):
    print("  App.js not found, skipping")
    exit()

with open(path, "r") as fh:
    c = fh.read()

orig_len = len(c)

# Replace Yo function - find "Yo=()=>a(ro,{open:!0" and replace entire expression
idx = c.find("Yo=()=>a(ro,{open:!0")
if idx >= 0:
    depth = 0
    end = idx
    started = False
    for i in range(idx + len("Yo=()=>"), len(c)):
        if c[i] == '(':
            depth += 1
            started = True
        elif c[i] == ')':
            depth -= 1
            if started and depth == 0:
                end = i + 1
                break
    c = c[:idx] + "Yo=()=>null" + c[end:]
    print("  Yo patched (dialog removed)")
else:
    print("  Yo not found")

# Replace Nr function
idx = c.find("Nr=")
if idx >= 0 and idx < 100:
    rest = c[idx:]
    depth = 0
    started = False
    end_rel = 0
    for i, ch in enumerate(rest):
        if ch == '{':
            depth += 1
            started = True
        elif ch == '}':
            depth -= 1
            if started and depth == 0:
                end_rel = i + 1
                break
    if end_rel > 0:
        c = c[:idx] + "Nr=()=>false" + c[end_rel:]
        print("  Nr patched")

# Replace Tr function
idx = c.find("Tr=")
if idx >= 0 and idx < 100:
    rest = c[idx:]
    depth = 0
    started = False
    end_rel = 0
    for i, ch in enumerate(rest):
        if ch == '{':
            depth += 1
            started = True
        elif ch == '}':
            depth -= 1
            if started and depth == 0:
                end_rel = i + 1
                break
    if end_rel > 0:
        c = c[:idx] + "Tr=()=>false" + c[end_rel:]
        print("  Tr patched")

# Fix MutationObserver cascade (prevents 10-15 reload loop when changing colors)
old_observer = "B=new MutationObserver(()=>{Zr.forEach((o)=>o())})"
new_observer = "B=new MutationObserver(()=>{if(!window.__hyperObsP){window.__hyperObsP=1;requestAnimationFrame(()=>{window.__hyperObsP=0;Zr.forEach((o)=>o())})}})"
if old_observer in c:
    c = c.replace(old_observer, new_observer)
    print("  MutationObserver batch fix applied")
else:
    # Try alternate pattern
    old2 = "B=new MutationObserver("
    if old2 in c:
        idx = c.find(old2)
        # Find the callback start
        cb_start = c.find("()=>{", idx)
        if cb_start >= 0 and cb_start - idx < 30:
            # Find the closing of this callback
            depth = 0
            started = False
            for i in range(cb_start + 5, min(cb_start + 500, len(c))):
                if c[i] == '{':
                    depth += 1
                    started = True
                elif c[i] == '}':
                    depth -= 1
                    if started and depth == 0:
                        old_cb = c[cb_start:i+1]
                        new_cb = "()=>{if(!window.__hyperObsP){window.__hyperObsP=1;requestAnimationFrame(()=>{window.__hyperObsP=0;" + old_cb[6:-1] + "})}}"
                        c = c[:cb_start] + new_cb + c[i+1:]
                        print("  MutationObserver batch fix applied (alt)")
                        break

# Remove license text strings
for text in [
    "DGEN License Account Required",
    "License Account Required",
    "Avtix License Account Required",
    "Connect the panel DGEN account in Hyper Settings to activate your license or Community Version.",
    "Connect the panel Avtix account in Avtix Settings to activate your license or Community Version.",
    "Connect Avtix Account to activate your license or activate the free Community Version.",
    "Admin access is paused until a DGEN license account is connected for this panel.",
    "admin access is paused until a DGEN license account is connected for this panel.",
    "Unable to load DGEN license account status. Please reload and try again.",
    "Loading license information...",
    "Avtix license account status unavailable",
    "Open Hyper Settings",
    "Open Avtix Settings",
]:
    c = c.replace(text, "")

with open(path, "w") as fh:
    fh.write(c)
print(f"  App.js: {orig_len} -> {len(c)} bytes")
PYEOF

    # 6. Patch HyperThemeSettings - remove license text, license section, reload, dgenx
    python3 << 'PYEOF2'
import os, glob

for js_file in glob.glob("/var/www/pterodactyl/public/assets/HyperThemeSettings*.js"):
    with open(js_file, "r") as fh:
        c = fh.read()
    orig = c

    # Remove license-related text strings
    for text in [
        "DGEN License Account Required",
        "License Account Required",
        "Connect the panel DGEN account in Hyper Settings to activate your license or Community Version.",
        "Connect the panel Avtix account in Avtix Settings to activate your license or Community Version.",
        "Connect Avtix Account to activate your license or activate the free Community Version.",
        "Admin access is paused until a DGEN license account is connected for this panel.",
        "admin access is paused until a DGEN license account is connected for this panel.",
        "Unable to load DGEN license account status. Please reload and try again.",
        "Loading license information...",
        "Avtix license account status unavailable",
        "Open Hyper Settings",
        "Open Avtix Settings",
    ]:
        c = c.replace(text, "")

    # Fix License section UI
    c = c.replace('children:"License Information"', 'children:"License Active"')
    c = c.replace('children:"No Avtix Account is Connected"', 'children:"License Active"')
    c = c.replace(',"Connect Avtix Account"]', ',"Active"]')

    # Remove page reloads (causes 10-15 reload loop)
    c = c.replace("e2.clearVerificationData(),window.location.reload()", "e2.clearVerificationData()")

    # Remove dgenx.net references
    c = c.replace("hyper-r2.dgenx.net", "hyper-r2.example.net")
    c = c.replace("auth.dgenx.net", "auth.example.net")

    if c != orig:
        with open(js_file, "w") as fh:
            fh.write(c)
        print(f"  HyperThemeSettings patched (license, reload, dgenx removed)")

# 7. Patch AccountOverviewContainer - remove connected accounts / SSO section
for js_file in glob.glob("/var/www/pterodactyl/public/assets/AccountOverviewContainer*.js"):
    with open(js_file, "r") as fh:
        c = fh.read()
    orig = c
    c = c.replace('"Connected Accounts"', '"Account Settings"')
    c = c.replace('"Connect Avtix"', '"Active"')
    c = c.replace("window.location.reload()", "void 0")
    # Remove dgenx SSO redirect
    import re
    c = re.sub(r'window\.location\.href\s*=\s*`https://auth\.dgenx\.net/authorize[^`]*`', 'void 0', c)
    if c != orig:
        with open(js_file, "w") as fh:
            fh.write(c)
        print(f"  AccountOverviewContainer patched (SSO removed)")

PYEOF2
    echo "JS patching complete."
}

create_controllers() {
    echo "Creating controllers..."
    CTRL="$PANEL_PATH/app/Http/Controllers"
    mkdir -p "$CTRL/Api/Client/Theme" "$CTRL/Api/Client/DGEN/Billing" "$CTRL/Api/Client/DGEN" \
        "$CTRL/Api/Client/Servers/DGEN" "$CTRL/Api/Client/Admin/DGEN" "$CTRL/Api/Client" \
        "$CTRL/Api/Application" "$CTRL/Base" "$CTRL/Auth" "$CTRL/Admin"

    # Helper
    mkctrl() {
        local path="$1" ns="$2" cls="$3"
        cat > "$path" <<CEOF
<?php
namespace $ns;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\Request;
class $cls extends Controller {
    public function __call(\$m, \$a) { return response()->json(["data" => []]); }
}
CEOF
    }

    # Theme controllers
    mkctrl "$CTRL/Api/Client/Theme/HyperV2ThemeController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\Theme" "HyperV2ThemeController"

    # HyperV2AddonController - returns proper addon settings with UserRegister enabled
    cat > "$CTRL/Api/Client/Theme/HyperV2AddonController.php" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\Theme;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
class HyperV2AddonController extends Controller {
    public function show(): JsonResponse {
        return response()->json(['addons' => [
            'UserRegister' => ['enabled' => true, 'name' => 'User Registration', 'description' => 'Enhanced user registration system', 'category' => 'User Management'],
            'theme-settings' => ['enabled' => true, 'name' => 'Theme Settings', 'description' => 'User theme customization', 'category' => 'Appearance'],
            'SiteAlerts' => ['enabled' => true, 'name' => 'Site Alerts', 'description' => 'Configure site-wide alert banners', 'category' => 'User Experience', 'alerts' => []],
            'Notifications' => ['enabled' => true, 'name' => 'System Notifications', 'description' => 'Configure system notifications and alerts', 'category' => 'User Experience', 'notifications' => ['serverEnabled' => false, 'soundsEnabled' => false]],
        ], 'updated_at' => now()->toIso8601String(), 'app_url' => config('app.url', '')]);
    }
    public function defaults(): JsonResponse { return response()->json(['addons' => []]); }
    public function update(Request $r): JsonResponse { return response()->json(['updated' => true]); }
    public function exportRaw(): JsonResponse { return response()->json(['data' => []]); }
    public function checkServerAvailability(): JsonResponse { return response()->json(['available' => true]); }
}
EOF

    # Billing - enhanced stubs with real DB queries
    cat > "$CTRL/Api/Client/DGEN/Billing/BillingController.php" <<'BILLEOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\DGEN\Billing;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
class BillingController extends Controller {
    public function getBalance(): JsonResponse {
        $user = request()->user();
        $balance = $user ? ($user->credits ?? 0) : 0;
        return response()->json(['balance' => $balance, 'currency' => 'USD']);
    }
    public function initiateTopUp(Request $r): JsonResponse {
        return response()->json(['message' => 'Top-up initiated', 'amount' => $r->input('amount', 0), 'method' => $r->input('method', 'balance'), 'status' => 'pending']);
    }
    public function verifyTransaction(Request $r): JsonResponse {
        return response()->json(['verified' => true, 'transaction_id' => $r->input('transaction_id', ''), 'amount' => $r->input('amount', 0)]);
    }
    public function getTransactions(): JsonResponse {
        $user = request()->user(); $transactions = [];
        if ($user) { try { $transactions = \DB::table('billing_transactions')->where('user_id', $user->id)->orderBy('created_at', 'desc')->limit(50)->get()->toArray(); } catch (\Throwable $e) {} }
        return response()->json(['data' => $transactions]);
    }
    public function getAdminStats(): JsonResponse {
        try { $totalRevenue = \DB::table('billing_transactions')->where('status', 'completed')->sum('amount') ?? 0; $totalUsers = \DB::table('users')->count(); $totalServers = \DB::table('servers')->count(); } catch (\Throwable $e) { $totalRevenue = 0; $totalUsers = 0; $totalServers = 0; }
        return response()->json(['total_revenue' => $totalRevenue, 'total_users' => $totalUsers, 'total_servers' => $totalServers, 'monthly_revenue' => $totalRevenue, 'active_services' => $totalServers]);
    }
    public function getAllTransactions(): JsonResponse {
        try { $transactions = \DB::table('billing_transactions')->orderBy('created_at', 'desc')->limit(100)->get()->toArray(); } catch (\Throwable $e) { $transactions = []; }
        return response()->json(['data' => $transactions]);
    }
    public function getUsersWithCredits(): JsonResponse {
        try { $users = \DB::table('users')->where('credits', '>', 0)->orderBy('credits', 'desc')->limit(50)->get(['id', 'email', 'credits', 'username'])->toArray(); } catch (\Throwable $e) { $users = []; }
        return response()->json(['data' => $users]);
    }
    public function getReferralOverview(): JsonResponse {
        try { $referrals = \DB::table('referrals')->orderBy('created_at', 'desc')->limit(50)->get()->toArray(); $totalReferrals = count($referrals); $totalPaid = \DB::table('referrals')->sum('amount') ?? 0; } catch (\Throwable $e) { $referrals = []; $totalReferrals = 0; $totalPaid = 0; }
        return response()->json(['data' => $referrals, 'total_referrals' => $totalReferrals, 'total_paid' => $totalPaid]);
    }
    public function getReferralInfo(): JsonResponse {
        $user = request()->user(); $code = null; $balance = 0; $referrals = 0;
        if ($user) { try { $code = $user->referral_code ?? substr(md5($user->id . 'ref'), 0, 8); $balance = $user->referral_balance ?? 0; $referrals = \DB::table('referrals')->where('referrer_id', $user->id)->count(); } catch (\Throwable $e) {} }
        return response()->json(['code' => $code, 'balance' => $balance, 'referrals' => $referrals]);
    }
    public function updateReferralCode(Request $r): JsonResponse {
        $user = request()->user(); $code = $r->input('code', substr(md5(uniqid()), 0, 8));
        if ($user) { try { $user->referral_code = $code; $user->save(); } catch (\Throwable $e) {} }
        return response()->json(['updated' => true, 'code' => $code]);
    }
    public function withdrawReferralBalance(Request $r): JsonResponse {
        $amount = $r->input('amount', 0); $user = request()->user();
        if ($user && ($user->referral_balance ?? 0) >= $amount) { try { $user->referral_balance -= $amount; $user->credits = ($user->credits ?? 0) + $amount; $user->save(); return response()->json(['success' => true, 'amount' => $amount]); } catch (\Throwable $e) {} }
        return response()->json(['error' => 'Insufficient balance'], 400);
    }
    public function getDiscount(): JsonResponse { return response()->json(['discount' => 0]); }
    public function litepayWebhook(Request $r): JsonResponse { return response()->json(['ok' => true]); }
    public function smepayWebhook(Request $r): JsonResponse { return response()->json(['ok' => true]); }
}
BILLEOF

    cat > "$CTRL/Api/Client/DGEN/Billing/StoreController.php" <<'STOREEOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\DGEN\Billing;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
class StoreController extends Controller {
    public function index(): JsonResponse {
        try { $categories = \DB::table('store_categories')->where('enabled', true)->orderBy('sort_order')->get()->toArray(); } catch (\Throwable $e) { $categories = []; }
        return response()->json(['data' => $categories]);
    }
    public function getNodes(): JsonResponse {
        try { $nodes = \DB::table('nodes')->select('id', 'name', 'fqdn', 'public', 'location_id')->get()->toArray(); } catch (\Throwable $e) { $nodes = []; }
        return response()->json(['data' => $nodes]);
    }
    public function showCategory(string $shortUrl): JsonResponse {
        try { $category = \DB::table('store_categories')->where('short_url', $shortUrl)->first(); $products = []; if ($category) { $products = \DB::table('store_products')->where('category_id', $category->id)->where('enabled', true)->get()->toArray(); } } catch (\Throwable $e) { $category = null; $products = []; }
        return response()->json(['category' => $category, 'products' => $products]);
    }
}
STOREEOF

    cat > "$CTRL/Api/Client/DGEN/Billing/OrderController.php" <<'ORDEREOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\DGEN\Billing;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
class OrderController extends Controller {
    public function createServer(Request $r): JsonResponse {
        $user = request()->user(); if (!$user) { return response()->json(['error' => 'Unauthorized'], 401); }
        try { $balance = $user->credits ?? 0; $price = $r->input('price', 0); if ($balance < $price) { return response()->json(['error' => 'Insufficient balance', 'balance' => $balance, 'required' => $price], 400); } $user->credits = $balance - $price; $user->save(); return response()->json(['success' => true, 'remaining_balance' => $user->credits]); } catch (\Throwable $e) { return response()->json(['error' => 'Failed: ' . $e->getMessage()], 500); }
    }
    public function renewServer(Request $r, string $uuid): JsonResponse { return response()->json(['success' => true, 'message' => 'Server renewed']); }
    public function updateAutoRenew(Request $r, string $uuid): JsonResponse { return response()->json(['updated' => true, 'auto_renew' => $r->input('auto_renew', false)]); }
    public function cancelServer(Request $r, string $uuid): JsonResponse { return response()->json(['cancelled' => true]); }
    public function reactivateServer(Request $r, string $uuid): JsonResponse { return response()->json(['reactivated' => true]); }
    public function getServices(): JsonResponse {
        $user = request()->user(); $services = [];
        if ($user) { try { $services = \DB::table('servers')->where('owner_id', $user->id)->get(['uuid', 'name', 'created_at', 'suspended'])->toArray(); } catch (\Throwable $e) {} }
        return response()->json(['data' => $services]);
    }
}
ORDEREOF

    cat > "$CTRL/Api/Client/DGEN/Billing/PromoCodeController.php" <<'PROMOEOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\DGEN\Billing;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
class PromoCodeController extends Controller {
    public function validateCode(Request $r): JsonResponse {
        $code = $r->input('code', ''); if (empty($code)) { return response()->json(['valid' => false, 'error' => 'No code provided'], 400); }
        try { $promo = \DB::table('promo_codes')->where('code', $code)->where('active', true)->first(); if ($promo) { return response()->json(['valid' => true, 'discount' => $promo->discount ?? 0, 'type' => $promo->type ?? 'percentage', 'description' => $promo->description ?? '']); } } catch (\Throwable $e) {}
        return response()->json(['valid' => false, 'discount' => 0]);
    }
}
PROMOEOF
    echo "  Billing controllers created (enhanced)"

    # DGEN features
    for c in LoginActivityController DdosAlertController WingsAddonController; do
        mkctrl "$CTRL/Api/Client/DGEN/${c}.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\DGEN" "$c"
    done

    # Client controllers
    mkctrl "$CTRL/Api/Client/ReverseProxyController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client" "ReverseProxyController"
    mkctrl "$CTRL/Api/Client/DiscordVerificationController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client" "DiscordVerificationController"

    # Server DGEN controllers
    for c in StaffRequestController RecycleBinController SubdomainManagerController QuickFileAccessController ServerImporterController ServerSplitterController CommandHistoryController CustomModManagerController NodeStatusController CustomMonitorController ReverseProxyWhitelistController ServerSplitterWhitelistController ServerTypeChangerWhitelistController FiveMUtilsController MinecraftModpackController ArmaReforgerModManagerController MinecraftController MinecraftPluginController MinecraftModController MinecraftWorldController MinecraftPlayerManagerController MinecraftBedrockAddonController MinecraftBedrockVersionController MinecraftBedrockAddonCacheController MinecraftModCacheController MinecraftModpackCacheController MinecraftWorldCacheController MinecraftVotifierTesterController MinecraftPluginCacheController ArmaReforgerConfigController ArmaReforgerAdminToolsController HytaleWorldController HytaleWorldCacheController HytaleModController ServerWiperController ServerSplitterMigrationController ServerTypeChangerController ServerAgentTicketController ServerStatsController ServerTimeChangerController AutoSuspendController ConfigEditorController FirewallManagerController GithubSourceControlController NetworkStatisticsController SchedulePresetsController StartupPresetsController UploadFromUrlController FastDLController FastDLNginxController ArkModController ArkModCacheController; do
        mkctrl "$CTRL/Api/Client/Servers/DGEN/${c}.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\Servers\\DGEN" "$c"
    done

    # Admin DGEN
    mkctrl "$CTRL/Api/Client/Admin/DGEN/DiscordBotController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\Admin\\DGEN" "DiscordBotController"
    mkctrl "$CTRL/Api/Client/Admin/DGEN/AdminBillingController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\Admin\\DGEN" "AdminBillingController"
    mkctrl "$CTRL/Api/Client/Admin/DGEN/PermissionRoleController.php" "Pterodactyl\\Http\\Controllers\\Api\\Client\\Admin\\DGEN" "PermissionRoleController"

    # Admin controllers
    cat > "$CTRL/Admin/AdminStatisticsController.php" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Admin;
use Pterodactyl\Http\Controllers\Controller;
class AdminStatisticsController extends Controller {
    public function __call($m, $a) { return response()->json(["data" => []]); }
}
EOF
    mkctrl "$CTRL/Admin/AuditLogController.php" "Pterodactyl\\Http\\Controllers\\Admin" "AuditLogController"
    mkctrl "$CTRL/Admin/PanelLogsController.php" "Pterodactyl\\Http\\Controllers\\Admin" "PanelLogsController"

    # Base controllers
    mkctrl "$CTRL/Base/HyperV2ThemePublicController.php" "Pterodactyl\\Http\\Controllers\\Base" "HyperV2ThemePublicController"
    mkctrl "$CTRL/Base/PublicNodeStatusController.php" "Pterodactyl\\Http\\Controllers\\Base" "PublicNodeStatusController"
    mkctrl "$CTRL/Base/PublicStatusPageController.php" "Pterodactyl\\Http\\Controllers\\Base" "PublicStatusPageController"
    mkctrl "$CTRL/Base/PublicStatsController.php" "Pterodactyl\\Http\\Controllers\\Base" "PublicStatsController"
    mkctrl "$CTRL/Base/HealthController.php" "Pterodactyl\\Http\\Controllers\\Base" "HealthController"
    mkctrl "$CTRL/Base/DocumentationController.php" "Pterodactyl\\Http\\Controllers\\Base" "DocumentationController"
    mkctrl "$CTRL/Api/PublicEggController.php" "Pterodactyl\\Http\\Controllers\\Api" "PublicEggController"
    mkctrl "$CTRL/Auth/ReferralController.php" "Pterodactyl\\Http\\Controllers\\Auth" "ReferralController"

    # LanguageController (CRITICAL - without this routes fail)
    cat > "$CTRL/Base/LanguageController.php" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Base;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;
class LanguageController extends Controller {
    public function update(Request $request) {
        $request->session()->put('app_locale', $request->input('locale', 'en'));
        return response()->noContent();
    }
    public function available() {
        return response()->json(['locales' => ['en' => 'English', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German', 'pt' => 'Portuguese', 'nl' => 'Dutch', 'ru' => 'Russian', 'zh' => 'Chinese', 'ja' => 'Japanese', 'ko' => 'Korean', 'tr' => 'Turkish', 'pl' => 'Polish', 'it' => 'Italian', 'ar' => 'Arabic', 'vi' => 'Vietnamese', 'th' => 'Thai', 'id' => 'Indonesian', 'sv' => 'Swedish', 'da' => 'Danish', 'fi' => 'Finnish', 'no' => 'Norwegian', 'cs' => 'Czech', 'el' => 'Greek', 'he' => 'Hebrew', 'hu' => 'Hungarian', 'ro' => 'Romanian', 'uk' => 'Ukrainian', 'ms' => 'Malay', 'hi' => 'Hindi', 'bn' => 'Bengali']]);
    }
    public function set(Request $request) {
        $request->session()->put('app_locale', $request->input('locale', 'en'));
        return response()->noContent();
    }
}
EOF

    # License controller
    cat > "$CTRL/Api/Application/LicenseController.php" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Application;
class LicenseController {
    public function check() { return response()->json(["valid" => true, "type" => "enterprise"]); }
    public function update() { return response()->json(["valid" => true]); }
}
EOF

    # RegisterController - uses DB::table insert (bypasses model uuid validation)
    cat > "$CTRL/Auth/RegisterController.php" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\View;
class RegisterController extends Controller {
    public function __construct() {}
    public function index(): View { return view('templates/auth.core'); }
    public function register(Request $request): JsonResponse {
        $request->validate([
            'username' => ['required', 'string', 'max:191'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);
        $username = $request->input('username');
        $email = $request->input('email');
        $exists = DB::table('users')->where('username', $username)->orWhere('email', $email)->first();
        if ($exists) {
            return response()->json(['errors' => [['detail' => 'A user with that username or email already exists.']]], 422);
        }
        DB::table('users')->insert([
            'uuid' => (string) Str::uuid(),
            'username' => $username,
            'email' => $email,
            'password' => Hash::make($request->input('password')),
            'name_first' => $request->input('name_first', ''),
            'name_last' => $request->input('name_last', ''),
            'language' => 'en',
            'root_admin' => false,
            'use_totp' => false,
            'gravatar' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $user = DB::table('users')->where('email', $email)->first();
        auth()->loginUsingId($user->id);
        return new JsonResponse(['data' => ['complete' => true, 'intended' => '/']]);
    }
}
EOF
}

create_services_middleware() {
    echo "Creating services and middleware..."
    mkdir -p "$PANEL_PATH/app/Services" "$PANEL_PATH/app/Http/Middleware" "$PANEL_PATH/app/Traits"

    # VerifyReCaptcha - must handle null domain gracefully
    cat > "$PANEL_PATH/app/Http/Middleware/VerifyReCaptcha.php" <<'RECEOF'
<?php
namespace Pterodactyl\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
class VerifyReCaptcha
{
    public function handle(Request $request, Closure $next)
    {
        $enabled = config('recaptcha.enabled', false);
        $secretKey = config('recaptcha.secret_key');
        $domain = config('recaptcha.domain');
        if (!$enabled || empty($secretKey) || empty($domain)) {
            return $next($request);
        }
        $recaptchaResponse = $request->input('g-recaptcha-response');
        if (empty($recaptchaResponse)) {
            return response()->json(['errors' => [['detail' => 'Please complete the CAPTCHA verification.']]], 422);
        }
        try {
            $client = new \GuzzleHttp\Client();
            $response = $client->post($domain, [
                'form_params' => [
                    'secret' => $secretKey,
                    'response' => $recaptchaResponse,
                    'remoteip' => $request->ip(),
                ],
            ]);
            $body = json_decode($response->getBody(), true);
            if (!isset($body['success']) || !$body['success']) {
                return response()->json(['errors' => [['detail' => 'CAPTCHA verification failed.']]], 422);
            }
        } catch (\Throwable $e) {
            return $next($request);
        }
        return $next($request);
    }
}
RECEOF

    for mw in HyperV2LicenseGate EnforceHyperV2PanelAccess HyperV2SecurityMonitor EnsureDiscordMembership; do
        cat > "$PANEL_PATH/app/Http/Middleware/${mw}.php" <<EOF
<?php
namespace Pterodactyl\Http\Middleware;
use Closure; use Illuminate\Http\Request;
class $mw { public function handle(Request \$r, Closure \$n) { return \$n(\$r); } }
EOF
    done

    cat > "$PANEL_PATH/app/Traits/ValidatesSecureLicense.php" <<'EOF'
<?php
namespace Pterodactyl\Traits;
trait ValidatesSecureLicense { public function isLicenseValid():bool{return true;} protected function validateLicense():bool{return true;} }
EOF

    cat > "$PANEL_PATH/app/Services/HyperV2LicenseService.php" <<'EOF'
<?php
namespace Pterodactyl\Services;
class HyperV2LicenseService {
    public function getLicenseStatus():array{return ['valid'=>true,'type'=>'enterprise','tier'=>'enterprise'];}
    public function validateLicense(?string $k=null):bool{return true;}
    public function isLicenseValid():bool{return true;}
    public function getLicenseKey():?string{return 'avtix-free';}
    public function isTrialMode():bool{return false;}
}
EOF

    cat > "$PANEL_PATH/app/Services/LicenseValidationService.php" <<'EOF'
<?php
namespace Pterodactyl\Services;
class LicenseValidationService {
    public function validate(?string $k=null):bool{return true;}
    public function isValid():bool{return true;}
    public function getDetails():array{return ['status'=>'valid','type'=>'enterprise'];}
}
EOF

    cat > "$PANEL_PATH/app/Services/HyperV2LegacySettingsMigrator.php" <<'EOF'
<?php
namespace Pterodactyl\Services;
class HyperV2LegacySettingsMigrator { public function migrate(){return true;} }
EOF
}

fix_code() {
    echo "Fixing code issues..."

    # Fix LoginController - add checkUser, logout, stopImpersonating methods
    cat > "$PANEL_PATH/app/Http/Controllers/Auth/LoginController.php" <<'LOGINEOF'
<?php
namespace Pterodactyl\Http\Controllers\Auth;
use Carbon\CarbonImmutable;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Facades\Activity;
use Illuminate\Contracts\View\View;
use Illuminate\Database\Eloquent\ModelNotFoundException;
class LoginController extends AbstractLoginController
{
    public function index(): View { return view('templates/auth.core'); }
    public function login(Request $request): JsonResponse
    {
        if ($this->hasTooManyLoginAttempts($request)) {
            $this->fireLockoutEvent($request);
            $this->sendLockoutResponse($request);
        }
        try {
            $username = $request->input('user');
            $user = User::query()->where($this->getField($username), $username)->firstOrFail();
        } catch (ModelNotFoundException) {
            $this->sendFailedLoginResponse($request);
        }
        if (!password_verify($request->input('password'), $user->password)) {
            $this->sendFailedLoginResponse($request, $user);
        }
        if (!$user->use_totp) {
            return $this->sendLoginResponse($user, $request);
        }
        Activity::event('auth:checkpoint')->withRequestMetadata()->subject($user)->log();
        $request->session()->put('auth_confirmation_token', [
            'user_id' => $user->id,
            'token_value' => $token = Str::random(64),
            'expires_at' => CarbonImmutable::now()->addMinutes(5),
        ]);
        return new JsonResponse(['data' => ['complete' => false, 'confirmation_token' => $token]]);
    }
    public function checkUser(Request $request): JsonResponse { return $this->login($request); }
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user) {
            $this->auth->guard()->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }
        return response()->json(['status' => 'logged_out']);
    }
    public function stopImpersonating(Request $request): JsonResponse
    {
        $request->session()->forget('admin_impersonate');
        return response()->json(['status' => 'stopped']);
    }
}
LOGINEOF

    # Disable recaptcha in config (no real keys)
    if [[ -f "$PANEL_PATH/config/recaptcha.php" ]]; then
        sed -i "s/'enabled' => env('RECAPTCHA_ENABLED', true)/'enabled' => env('RECAPTCHA_ENABLED', false)/" "$PANEL_PATH/config/recaptcha.php"
        sed -i "s|'website_key' => env('RECAPTCHA_WEBSITE_KEY', '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn')|'website_key' => env('RECAPTCHA_WEBSITE_KEY', '')|" "$PANEL_PATH/config/recaptcha.php"
        sed -i "s|'secret_key' => env('RECAPTCHA_SECRET_KEY', '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5')|'secret_key' => env('RECAPTCHA_SECRET_KEY', '')|" "$PANEL_PATH/config/recaptcha.php"
        echo "  Recaptcha disabled and keys cleared in config"
    fi

    # Replace Pterodactyl with Avtix in blade views (display text only, NOT PHP namespaces)
    echo "  Replacing brand references..."
    find "$PANEL_PATH/resources/views" -name '*.blade.php' -exec sed -i 's/Pterodactyl Panel/Avtix Game Panel/g; s/Pterodactyl Wings/Avtix Wings/g; s/>Pterodactyl</>Avtix</g; s/Pterodactyl$/Avtix/g' {} \; 2>/dev/null || true
    # Replace in DGEN lang files (display text only)
    find "$PANEL_PATH/public/DGEN" -name '*.json' -exec sed -i 's/Pterodactyl/Avtix/g' {} \; 2>/dev/null || true
    echo "  Brand replaced in blade views and lang files"

    # Fix User model - add permissionRole
    if [[ -f "$PANEL_PATH/app/Models/User.php" ]] && ! grep -q "function permissionRole" "$PANEL_PATH/app/Models/User.php" 2>/dev/null; then
        python3 -c "
with open('$PANEL_PATH/app/Models/User.php','r') as f: c=f.read()
m='''
    public function permissionRole(){return \$this->hasOne(\Pterodactyl\Models\Setting::class,'id')->limit(0);}
    public function hasAdminPermission(string \$p):bool{return (bool)\$this->root_admin;}
'''
i=c.rfind('}')
if i>0: c=c[:i]+m+c[i:]
with open('$PANEL_PATH/app/Models/User.php','w') as f: f.write(c)
"
        echo "  User model patched"
    fi

    # Fix allowedFilters syntax (Spatie QueryBuilder)
    python3 << 'PYEOF'
import re, glob, os
fixed = 0
for f in glob.glob("/var/www/pterodactyl/app/**/*.php", recursive=True):
    try:
        with open(f,"r") as fh: c=fh.read()
        orig=c
        c=re.sub(r"->allowedFilters\(\[(.*?)\]\)", r"->allowedFilters(\1)", c)
        if c!=orig:
            with open(f,"w") as fh: fh.write(c)
            fixed+=1
    except: pass
if fixed: print(f"  Fixed {fixed} allowedFilters")
PYEOF

    # Fix AppServiceProvider
    cat > "$PANEL_PATH/app/Providers/AppServiceProvider.php" <<'EOF'
<?php
namespace Pterodactyl\Providers;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\ServiceProvider;
use Illuminate\Database\Eloquent\Relations\Relation;
class AppServiceProvider extends ServiceProvider {
    public function boot():void {
        Relation::morphMap([
            \Pterodactyl\Models\Server::class => \Pterodactyl\Models\Server::class,
            \Pterodactyl\Models\User::class => \Pterodactyl\Models\User::class,
        ]);
        Paginator::useBootstrap();
    }
}
EOF
    echo "  AppServiceProvider rewritten"

    # Create ThemeServiceProvider (binds extensions.themes)
    mkdir -p "$PANEL_PATH/app/Extensions"
    cat > "$PANEL_PATH/app/Providers/ThemeServiceProvider.php" <<'TSVEOF'
<?php
namespace Pterodactyl\Providers;
use Illuminate\Support\ServiceProvider;
class ThemeServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind('extensions.themes', function () {
            return config('themes.active', 'hyperv2');
        });
    }
    public function boot(): void {}
}
TSVEOF
    mkdir -p "$PANEL_PATH/app/Extensions/Facades"
    cat > "$PANEL_PATH/app/Extensions/Facades/Theme.php" <<'TFEOF'
<?php
namespace Pterodactyl\Extensions\Facades;
use Illuminate\Support\Facades\Facade;
class Theme extends Facade
{
    protected static function getFacadeAccessor() { return 'extensions.themes'; }
}
TFEOF
    echo "  ThemeServiceProvider created"

    # Fix admin index.blade.php - cache busting
    if [[ -f "$PANEL_PATH/resources/views/admin/index.blade.php" ]]; then
        if ! grep -q "no-cache" "$PANEL_PATH/resources/views/admin/index.blade.php" 2>/dev/null; then
            sed -i 's|<head>|<head>\n    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n    <meta http-equiv="Pragma" content="no-cache">\n    <meta http-equiv="Expires" content="0">|' "$PANEL_PATH/resources/views/admin/index.blade.php"
            echo "  Admin view cache-busted"
        fi
    fi

    # Create nav partial
    mkdir -p "$PANEL_PATH/resources/views/partials/admin/settings"
    if [[ ! -f "$PANEL_PATH/resources/views/partials/admin/settings/nav.blade.php" ]]; then
        cat > "$PANEL_PATH/resources/views/partials/admin/settings/nav.blade.php" <<'NAVEOF'
<nav class="flex flex-col sm:flex-row gap-2 mb-6">
    <a href="/admin/settings" class="px-4 py-2 rounded-lg {{ request()->is('admin/settings') ? 'bg-red-500 text-white' : 'bg-gray-800 text-gray-300 hover:text-white hover:bg-gray-700' }}">General</a>
    <a href="/admin/settings/mail" class="px-4 py-2 rounded-lg {{ request()->is('admin/settings/mail') ? 'bg-red-500 text-white' : 'bg-gray-800 text-gray-300 hover:text-white hover:bg-gray-700' }}">Mail</a>
    <a href="/admin/settings/api" class="px-4 py-2 rounded-lg {{ request()->is('admin/settings/api') ? 'bg-red-500 text-white' : 'bg-gray-800 text-gray-300 hover:text-white hover:bg-gray-700' }}">API</a>
    <a href="/admin/settings/servers" class="px-4 py-2 rounded-lg {{ request()->is('admin/settings/servers') ? 'bg-red-500 text-white' : 'bg-gray-800 text-gray-300 hover:text-white hover:bg-gray-700' }}">Servers</a>
</nav>
NAVEOF
        echo "  Nav partial created"
    fi

    # Fix AssetHashService
    if [[ -f "$PANEL_PATH/app/Services/Helpers/AssetHashService.php" ]] && ! grep -q "function preloads" "$PANEL_PATH/app/Services/Helpers/AssetHashService.php" 2>/dev/null; then
        python3 -c "
with open('$PANEL_PATH/app/Services/Helpers/AssetHashService.php','r') as f: c=f.read()
m='''
    public function preloads():array{return [];}
    public function authPreloads():array{return [];}
'''
i=c.rfind('}')
if i>0: c=c[:i]+m+c[i:]
with open('$PANEL_PATH/app/Services/Helpers/AssetHashService.php','w') as f: f.write(c)
"
        echo "  AssetHashService patched"
    fi
}

add_routes() {
    echo "Adding license API routes..."
    if ! grep -q "clear-all-cache" "$PANEL_PATH/routes/base.php" 2>/dev/null; then
        cat >> "$PANEL_PATH/routes/base.php" <<'ROUTEOF'

Route::get('/api/public/license/verify', function () {
    return response()->json([
        'tier' => 'ultimate', 'status' => 'active', 'valid' => true, 'validity' => 'Valid',
        'community' => false, 'sso_connected' => true,
        'features' => ['sso', 'billing', 'store', 'subdomains', 'recyclebin', 'serversplitter', 'fivem', 'minecraft', 'arma'],
        'panel_type' => 'Avtix Game Panel', 'panel_version' => 'v1.0',
        'license_key' => 'avtix-enterprise', 'verified_at' => now()->toIso8601String(),
    ]);
});
Route::get('/api/public/license/status', function () {
    return response()->json(['tier' => 'ultimate', 'status' => 'active', 'valid' => true, 'validity' => 'Valid', 'community' => false, 'sso_connected' => true]);
});
Route::post('/api/public/license/clear-all-cache', function () {
    return response()->json(['success' => true]);
});
Route::get('/api/public/auth-addon-settings', function () {
    $addons = [
        'UserRegister' => ['enabled' => true, 'name' => 'User Registration', 'description' => 'Enhanced user registration system', 'category' => 'User Management'],
        'theme-settings' => ['enabled' => true, 'name' => 'Theme Settings', 'description' => 'User theme customization', 'category' => 'Appearance'],
        'SiteAlerts' => ['enabled' => true, 'name' => 'Site Alerts', 'description' => 'Configure site-wide alert banners', 'category' => 'User Experience', 'alerts' => []],
        'Notifications' => ['enabled' => true, 'name' => 'System Notifications', 'description' => 'Configure system notifications and alerts', 'category' => 'User Experience', 'notifications' => ['serverEnabled' => false, 'soundsEnabled' => false]],
    ];
    return response()->json(['addons' => $addons, 'updated_at' => now()->toIso8601String(), 'app_url' => config('app.url', '')]);
})->withoutMiddleware(['auth']);
ROUTEOF
        echo "  Routes added"
    fi

    # Enable registration in settings
    mysql -u root panel -e "INSERT IGNORE INTO settings (\`key\`, \`value\`) VALUES ('settings::auth:registration', '1'); INSERT IGNORE INTO settings (\`key\`, \`value\`) VALUES ('settings::auth:2fa_required', '0');" 2>/dev/null || true
    echo "  Registration enabled"

    # Add DGEN admin panel API routes (SPA calls /api/DGEN/* but routes are at /admin/api/DGEN/*)
    if ! grep -q "DGEN/roles" "$PANEL_PATH/routes/base.php" 2>/dev/null; then
        cat >> "$PANEL_PATH/routes/base.php" <<'DGENEOF'

// DGEN Admin Panel API Routes (called from SPA theme-admin page)
Route::get('/api/DGEN/roles', function () {
    return response()->json(['data' => [
        ['id' => 1, 'name' => 'Admin', 'color' => '#ff0000', 'permissions' => []],
        ['id' => 2, 'name' => 'Moderator', 'color' => '#00ff00', 'permissions' => []],
        ['id' => 3, 'name' => 'User', 'color' => '#0000ff', 'permissions' => []],
    ]]);
});
Route::get('/api/DGEN/members', function () { return response()->json(['data' => []]); });
Route::get('/api/DGEN/permissions', function () { return response()->json(['data' => []]); });
Route::get('/api/DGEN/billing/categories', function () { return response()->json(['data' => []]); });
Route::get('/api/DGEN/billing/subcategories', function () { return response()->json(['data' => []]); });
Route::get('/api/DGEN/billing/games', function () { return response()->json(['data' => []]); });
Route::get('/api/DGEN/billing/promocodes', function () { return response()->json(['data' => []]); });
DGENEOF
        echo "  DGEN routes added"
    fi

    # Fix server-type-changer/all-nests-eggs path (SPA calls without admin/ prefix)
    if ! grep -q "addons/server-type-changer/all-nests-eggs" "$PANEL_PATH/routes/api-client.php" 2>/dev/null; then
        sed -i "s|Route::get('admin/addons/server-type-changer/all-nests-eggs'|Route::get('addons/server-type-changer/all-nests-eggs'|" "$PANEL_PATH/routes/api-client.php" 2>/dev/null
        echo "  server-type-changer path fixed"
    fi

    # Add public API routes (node-status, stats, pwa/manifest, eggs)
    if ! grep -q "node-status" "$PANEL_PATH/routes/base.php" 2>/dev/null; then
        cat >> "$PANEL_PATH/routes/base.php" <<'PUBEOF'

// Public API Routes
Route::get('/api/public/node-status', function () {
    try { $nodes = \Pterodactyl\Models\Node::all(['id', 'name', 'fqdn', 'public', 'location_id']); } catch (\Throwable $e) { $nodes = collect(); }
    return response()->json(['data' => $nodes]);
})->withoutMiddleware(['auth']);
Route::get('/api/public/stats', function () {
    try { $users = \DB::table('users')->count(); $servers = \DB::table('servers')->count(); $nodes = \Pterodactyl\Models\Node::count(); } catch (\Throwable $e) { $users = 0; $servers = 0; $nodes = 0; }
    return response()->json(['users' => $users, 'servers' => $servers, 'nodes' => $nodes]);
})->withoutMiddleware(['auth']);
Route::get('/api/public/pwa/manifest', function () {
    $name = config('app.name', 'Avtix Game Panel');
    return response()->json([
        'name' => $name, 'short_name' => $name, 'start_url' => '/',
        'display' => 'standalone', 'background_color' => '#0c0a09', 'theme_color' => '#df3050',
        'icons' => [['src' => '/favicons/android-chrome-192x192.png', 'sizes' => '192x192', 'type' => 'image/png'],
                     ['src' => '/favicons/android-chrome-512x512.png', 'sizes' => '512x512', 'type' => 'image/png']],
    ]);
})->withoutMiddleware(['auth']);
Route::get('/api/public/eggs', function () {
    try { $eggs = \DB::table('eggs')->select('id', 'name', 'description', 'nest_id', 'author')->get(); } catch (\Throwable $e) { $eggs = collect(); }
    return response()->json(['data' => $eggs]);
})->withoutMiddleware(['auth']);
PUBEOF
        echo "  Public API routes added"
    fi
}

fix_nginx_cache() {
    NGINX_CONF="/etc/nginx/sites-enabled/pterodactyl.conf"
    if [[ -f "$NGINX_CONF" ]]; then
        # Write optimized nginx config with gzip, sendfile, and static caching
        cat > "$NGINX_CONF" <<'NGINXEOF'
server {
    server_name client.zapnodes.in;
    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;
    gzip_comp_level 6;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.html$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    client_max_body_size 100m;
    client_body_timeout 120s;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    listen [::]:443 ssl ipv6only=on;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/client.zapnodes.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/client.zapnodes.in/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
server {
    if ($host = client.zapnodes.in) {
        return 301 https://$host$request_uri;
    }
    listen 80;
    listen [::]:80;
    server_name client.zapnodes.in;
    return 301 https://$host$request_uri;
}
NGINXEOF
        # Update server_name to match actual domain
        DOMAIN=$(grep APP_URL "$PANEL_PATH/.env" 2>/dev/null | cut -d= -f2 | sed 's|https://||;s|http://||')
        [[ -n "$DOMAIN" ]] && sed -i "s/client.zapnodes.in/$DOMAIN/g" "$NGINX_CONF"
        echo "  Nginx config rewritten (gzip, sendfile, caching)"
    fi
}

configure_env() {
    echo "Configuring .env..."
    cd "$PANEL_PATH"
    [[ ! -f .env ]] && cp .env.example .env
    php8.4 artisan key:generate --force 2>/dev/null || true
    sed -i "s|^APP_NAME=.*|APP_NAME=\"Avtix Game Panel\"|" .env
    sed -i "s|^APP_ENV=.*|APP_ENV=production|" .env
    sed -i "s|^APP_DEBUG=.*|APP_DEBUG=false|" .env
    sed -i "s|^APP_URL=.*|APP_URL=https://your-domain.com|" .env
    sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env
    sed -i "s|^DB_PORT=.*|DB_PORT=3306|" .env
    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=panel|" .env
    sed -i "s|^DB_USERNAME=.*|DB_USERNAME=panel|" .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=AvtixPanel2026|" .env
    # Add SANCTUM_STATEFUL_DOMAINS if not present
    if ! grep -q "SANCTUM_STATEFUL_DOMAINS" .env 2>/dev/null; then
        echo "SANCTUM_STATEFUL_DOMAINS=\${APP_URL}" >> .env
    fi
}

install_deps() {
    echo "Installing Composer dependencies..."
    cd "$PANEL_PATH"
    composer install --no-dev --optimize-autoloader --no-interaction
    composer show laragear/webauthn >/dev/null 2>&1 || composer require laragear/webauthn --no-interaction 2>/dev/null || true
}

run_migrate() {
    echo "Running migrations..."
    cd "$PANEL_PATH"
    rm -f database/schema/mysql-schema.sql 2>/dev/null || true
    # Skip problematic migration
    php8.4 artisan tinker --execute="
\$mig = new \Illuminate\Database\Migrations\Migrator(new \Illuminate\Database\Migrations\DatabaseMigrationRepository(\Illuminate\Support\Facades\DB::connection(), 'migrations'), \Illuminate\Support\Facades\DB::connection(), new \Illuminate\Filesystem\Filesystem());
" 2>/dev/null || true
    php8.4 artisan migrate --force 2>/dev/null || true

    # Handle any stuck migrations
    php8.4 artisan tinker --execute="
try {
    \Illuminate\Support\Facades\DB::table('migrations')
        ->where('migration', 'like', '%store_node_tokens%')
        ->whereNull('batch')
        ->update(['batch' => 99]);
} catch (Exception \$e) {}
" 2>/dev/null || true

    # Try again
    php8.4 artisan migrate --force 2>/dev/null || true
}

create_admin() {
    echo "Creating admin user..."
    cd "$PANEL_PATH"
    # Use raw SQL to avoid model validation issues
    mysql -u root panel -e "INSERT IGNORE INTO users (uuid, email, username, name_first, name_last, password, root_admin, external_id, language, use_totp, created_at, updated_at) VALUES ('$(cat /proc/sys/kernel/random/uuid)', 'admin@admin.com', 'admin', 'Admin', 'User', '\$2y\$10\$utJHsNQ.GP6ya34OMeM9A.rrJp1Y.ExBVWnnyxQTFkpHvSzfqG0My', 1, 'admin-ext-001', 'en', 0, NOW(), NOW());" 2>/dev/null || true
    echo "  Admin: admin@admin.com / admin"
}

fix_nginx() {
    find /etc/nginx/sites-available/ /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ -type f -exec grep -l "/var/www/pterodactyl" {} + 2>/dev/null | while read -r conf; do
        sed -i -E "s|unix:(/var)?/run/php/php[0-9]+\.[0-9]+-fpm\.sock|unix:/run/php/php8.4-fpm.sock|g" "$conf"
    done
}

create_custom_auth() {
    echo "Creating custom auth pages (bypasses SPA)..."

    # Create views directory
    mkdir -p "$PANEL_PATH/resources/views/auth"

    # Login blade
    cat > "$PANEL_PATH/resources/views/auth/login.blade.php" <<'LOGBLADE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Login - Avtix Game Panel</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0c0a09;color:#d4d4d8;min-height:100vh;display:flex;align-items:center;justify-content:center}
        .login-container{width:100%;max-width:420px;padding:2rem}
        .login-box{background:#1c1917;border:1px solid rgba(255,255,255,.05);border-radius:12px;padding:2.5rem}
        .logo{text-align:center;margin-bottom:2rem}
        .logo h1{font-size:1.5rem;font-weight:700;color:#fff;letter-spacing:-.025em}
        .logo .subtitle{color:#71717a;font-size:.875rem;margin-top:.25rem}
        .form-group{margin-bottom:1rem}
        .form-group label{display:block;font-size:.875rem;font-weight:500;color:#a1a1aa;margin-bottom:.375rem}
        .form-group input{width:100%;padding:.625rem .875rem;background:#27272a;border:1px solid #3f3f46;border-radius:8px;color:#fff;font-size:.875rem;outline:none;transition:border-color .15s}
        .form-group input:focus{border-color:#df3050}
        .form-group input::placeholder{color:#52525b}
        .error-text{color:#ef4444;font-size:.75rem;margin-top:.25rem}
        .error-box{background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.3);border-radius:8px;padding:.75rem 1rem;margin-bottom:1rem;color:#fca5a5;font-size:.8125rem}
        .btn{width:100%;padding:.75rem;background:#df3050;color:#fff;border:none;border-radius:8px;font-size:.875rem;font-weight:600;cursor:pointer;transition:background .15s;margin-top:.5rem}
        .btn:hover{background:#c12640}
        .btn:disabled{opacity:.6;cursor:not-allowed}
        .links{text-align:center;margin-top:1.25rem;font-size:.8125rem;color:#71717a}
        .links a{color:#df3050;text-decoration:none;font-weight:500}
        .links a:hover{text-decoration:underline}
        .remember-row{display:flex;align-items:center;gap:.5rem;margin-bottom:.5rem}
        .remember-row input[type="checkbox"]{accent-color:#df3050}
        .remember-row label{font-size:.8125rem;color:#a1a1aa;cursor:pointer}
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-box">
            <div class="logo"><h1>Avtix Game Panel</h1><p class="subtitle">Sign in to your account</p></div>
            @if ($errors->any())<div class="error-box">{{ $errors->first('user') }}</div>@endif
            <form method="POST" action="{{ route('auth.custom.login.post') }}">
                @csrf
                <div class="form-group"><label for="user">Username or Email</label><input type="text" id="user" name="user" value="{{ old('user') }}" placeholder="Enter your username or email" required autofocus></div>
                <div class="form-group"><label for="password">Password</label><input type="password" id="password" name="password" placeholder="Enter your password" required></div>
                <div class="remember-row"><input type="checkbox" id="remember" name="remember" value="1"><label for="remember">Remember me</label></div>
                <button type="submit" class="btn">Sign In</button>
            </form>
            <div class="links"><p>Don't have an account? <a href="{{ route('auth.custom.register') }}">Create one</a></p></div>
        </div>
    </div>
</body>
</html>
LOGBLADE

    # Register blade
    cat > "$PANEL_PATH/resources/views/auth/register.blade.php" <<'REGBLADE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Register - Avtix Game Panel</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0c0a09;color:#d4d4d8;min-height:100vh;display:flex;align-items:center;justify-content:center}
        .register-container{width:100%;max-width:420px;padding:2rem}
        .register-box{background:#1c1917;border:1px solid rgba(255,255,255,.05);border-radius:12px;padding:2.5rem}
        .logo{text-align:center;margin-bottom:2rem}
        .logo h1{font-size:1.5rem;font-weight:700;color:#fff;letter-spacing:-.025em}
        .logo .subtitle{color:#71717a;font-size:.875rem;margin-top:.25rem}
        .form-group{margin-bottom:1rem}
        .form-group label{display:block;font-size:.875rem;font-weight:500;color:#a1a1aa;margin-bottom:.375rem}
        .form-group input{width:100%;padding:.625rem .875rem;background:#27272a;border:1px solid #3f3f46;border-radius:8px;color:#fff;font-size:.875rem;outline:none;transition:border-color .15s}
        .form-group input:focus{border-color:#df3050}
        .form-group input::placeholder{color:#52525b}
        .form-row{display:flex;gap:.75rem}
        .form-row .form-group{flex:1}
        .error-box{background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.3);border-radius:8px;padding:.75rem 1rem;margin-bottom:1rem;color:#fca5a5;font-size:.8125rem}
        .btn{width:100%;padding:.75rem;background:#df3050;color:#fff;border:none;border-radius:8px;font-size:.875rem;font-weight:600;cursor:pointer;transition:background .15s;margin-top:.5rem}
        .btn:hover{background:#c12640}
        .btn:disabled{opacity:.6;cursor:not-allowed}
        .links{text-align:center;margin-top:1.25rem;font-size:.8125rem;color:#71717a}
        .links a{color:#df3050;text-decoration:none;font-weight:500}
        .links a:hover{text-decoration:underline}
    </style>
</head>
<body>
    <div class="register-container">
        <div class="register-box">
            <div class="logo"><h1>Avtix Game Panel</h1><p class="subtitle">Create a new account</p></div>
            @if ($errors->any())<div class="error-box"><ul style="list-style:none;padding:0;margin:0;">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
            <form method="POST" action="{{ route('auth.custom.register.post') }}">
                @csrf
                <div class="form-row"><div class="form-group"><label for="name_first">First Name</label><input type="text" id="name_first" name="name_first" value="{{ old('name_first') }}" placeholder="First name"></div><div class="form-group"><label for="name_last">Last Name</label><input type="text" id="name_last" name="name_last" value="{{ old('name_last') }}" placeholder="Last name"></div></div>
                <div class="form-group"><label for="username">Username</label><input type="text" id="username" name="username" value="{{ old('username') }}" placeholder="Choose a username" required autofocus></div>
                <div class="form-group"><label for="email">Email</label><input type="email" id="email" name="email" value="{{ old('email') }}" placeholder="you@example.com" required></div>
                <div class="form-group"><label for="password">Password</label><input type="password" id="password" name="password" placeholder="At least 8 characters" required></div>
                <div class="form-group"><label for="password_confirmation">Confirm Password</label><input type="password" id="password_confirmation" name="password_confirmation" placeholder="Repeat your password" required></div>
                <button type="submit" class="btn">Create Account</button>
            </form>
            <div class="links"><p>Already have an account? <a href="{{ route('auth.custom.login') }}">Sign in</a></p></div>
        </div>
    </div>
</body>
</html>
REGBLADE

    # CustomAuthController
    cat > "$PANEL_PATH/app/Http/Controllers/Auth/CustomAuthController.php" <<'CTRLAUTH'
<?php
namespace Pterodactyl\Http\Controllers\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Http\RedirectResponse;
use Pterodactyl\Models\User;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Pterodactyl\Facades\Activity;
class CustomAuthController extends AbstractLoginController
{
    public function showLogin() { if (Auth::check()) return redirect('/dashboard'); return view('auth.login'); }
    public function doLogin(Request $request): RedirectResponse {
        $request->validate(['user' => ['required', 'string'], 'password' => ['required', 'string']]);
        if ($this->hasTooManyLoginAttempts($request)) { $this->fireLockoutEvent($request); return back()->withErrors(['user' => 'Too many login attempts.']); }
        $username = $request->input('user'); $password = $request->input('password');
        try { $field = $this->getField($username); $user = User::query()->where($field, $username)->firstOrFail(); }
        catch (ModelNotFoundException) { $this->incrementLoginAttempts($request); return back()->withErrors(['user' => 'Invalid credentials.'])->withInput(['user' => $username]); }
        if ($user->is_banned) return back()->withErrors(['user' => 'Your account has been banned.']);
        if (!password_verify($password, $user->password)) { $this->incrementLoginAttempts($request); return back()->withErrors(['user' => 'Invalid credentials.'])->withInput(['user' => $username]); }
        if ($user->use_totp) { $request->session()->put('auth_confirmation_token', ['user_id' => $user->id, 'token_value' => $token = Str::random(64), 'expires_at' => \Carbon\CarbonImmutable::now()->addMinutes(5)]); return redirect('/auth/login/checkpoint')->with('token', $token); }
        $this->clearLoginAttempts($request); Auth::login($user, $request->boolean('remember'));
        Activity::event('auth:login')->withRequestMetadata()->subject($user)->log();
        return redirect($request->session()->pull('url.intended', '/dashboard'));
    }
    public function showRegister() { if (Auth::check()) return redirect('/dashboard'); return view('auth.register'); }
    public function doRegister(Request $request): RedirectResponse {
        $request->validate(['username' => ['required', 'string', 'max:191', 'unique:users,username'], 'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'], 'password' => ['required', 'string', 'min:8', 'confirmed']]);
        $userId = DB::table('users')->insertGetId(['uuid' => (string) Str::uuid(), 'username' => $request->input('username'), 'email' => $request->input('email'), 'password' => Hash::make($request->input('password')), 'name_first' => $request->input('name_first', ''), 'name_last' => $request->input('name_last', ''), 'language' => 'en', 'root_admin' => false, 'use_totp' => false, 'gravatar' => true, 'credit' => '0.00', 'referral_balance' => '0.00', 'external_id' => '', 'created_at' => now(), 'updated_at' => now()]);
        $user = User::find($userId); Auth::login($user);
        Activity::event('auth:register')->withRequestMetadata()->subject($user)->log();
        return redirect('/dashboard');
    }
    public function doLogout(Request $request): RedirectResponse {
        $user = $request->user();
        if ($user) { Activity::event('auth:logout')->withRequestMetadata()->subject($user)->log(); Auth::guard()->logout(); $request->session()->invalidate(); $request->session()->regenerateToken(); }
        return redirect('/auth/login');
    }
    protected function getField(?string $input = null): string { return filter_var($input, FILTER_VALIDATE_EMAIL) ? 'email' : 'username'; }
}
CTRLAUTH

    # Write complete auth.php routes with custom routes
    cat > "$PANEL_PATH/routes/auth.php" <<'AUTHEOF'
<?php
use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Controllers\Auth;

Route::get('/login', [Auth\LoginController::class, 'index'])->name('auth.login');
Route::get('/register', [Auth\RegisterController::class, 'index'])->name('auth.register');
Route::get('/password', [Auth\LoginController::class, 'index'])->name('auth.forgot-password');
Route::get('/password/reset/{token}', [Auth\LoginController::class, 'index'])->name('auth.reset');

Route::get('/login/custom', [Auth\CustomAuthController::class, 'showLogin'])->name('auth.custom.login');
Route::post('/login/custom', [Auth\CustomAuthController::class, 'doLogin'])->name('auth.custom.login.post');
Route::get('/register/custom', [Auth\CustomAuthController::class, 'showRegister'])->name('auth.custom.register');
Route::post('/register/custom', [Auth\CustomAuthController::class, 'doRegister'])->name('auth.custom.register.post');
Route::get('/logout/custom', [Auth\CustomAuthController::class, 'doLogout'])->name('auth.custom.logout');

Route::middleware(['throttle:authentication'])->group(function () {
    Route::post('/login', [Auth\LoginController::class, 'login'])->middleware('recaptcha');
    Route::post('/login/check-user', [Auth\LoginController::class, 'checkUser'])->name('auth.login.check-user');
    Route::post('/login/checkpoint', Auth\LoginCheckpointController::class)->name('auth.login-checkpoint');

    Route::post('/register', [Auth\RegisterController::class, 'register'])->middleware('recaptcha');

    Route::post('/password', [Auth\ForgotPasswordController::class, 'sendResetLinkEmail'])
        ->name('auth.post.forgot-password')
        ->middleware('recaptcha');
});

Route::post('/password/reset', Auth\ResetPasswordController::class)->name('auth.reset-password');

Route::get('/login/sso/{provider}', [Auth\SSOLoginController::class, 'redirect'])
    ->withoutMiddleware('guest')
    ->name('auth.sso.redirect');
Route::get('/login/sso/{provider}/callback', [Auth\SSOLoginController::class, 'callback'])
    ->withoutMiddleware('guest')
    ->name('auth.sso.callback');
Route::post('/login/sso/confirm-link', [Auth\SSOLoginController::class, 'confirmSsoLink'])
    ->withoutMiddleware('guest')
    ->name('auth.sso.confirm-link');
Route::delete('/account/sso/{provider}', [Auth\SSOLoginController::class, 'unlink'])
    ->withoutMiddleware('guest')
    ->name('auth.sso.unlink');
Route::get('/account/sso/dgen/start', [Auth\SSOLoginController::class, 'startDgenAccountLink'])
    ->withoutMiddleware('guest')
    ->middleware('auth')
    ->name('auth.sso.dgen-account.start');
Route::get('/account/sso/dgen/callback', [Auth\SSOLoginController::class, 'callbackDgenAccountLink'])
    ->withoutMiddleware('guest')
    ->name('auth.sso.dgen-account.callback');
Route::post('/account/sso/dgen/exchange', [Auth\SSOLoginController::class, 'exchangeDgenAccountLink'])
    ->withoutMiddleware('guest')
    ->middleware('auth')
    ->name('auth.sso.dgen-account.exchange');

Route::get('/account/sso', [Auth\SSOLoginController::class, 'index'])
    ->withoutMiddleware('guest')
    ->middleware('auth')
    ->name('auth.sso.index');

Route::get('/sso-wemx', [Auth\WemxSsoController::class, 'webhook'])
    ->withoutMiddleware('guest')
    ->name('sso-wemx.webhook');
Route::get('/sso-wemx/{token}', [Auth\WemxSsoController::class, 'handle'])
    ->withoutMiddleware('guest')
    ->name('sso-wemx.login');

Route::post('/logout', [Auth\LoginController::class, 'logout'])
    ->withoutMiddleware('guest')
    ->middleware('auth')
    ->name('auth.logout');

Route::get('/stop-impersonating', [Auth\LoginController::class, 'stopImpersonating'])
    ->withoutMiddleware('guest')
    ->middleware('auth')
    ->name('auth.stop-impersonating');

Route::withoutMiddleware('guest')->middleware('auth')->group(function () {
    Route::get('/passkey', [Auth\PasskeyController::class, 'index'])->name('auth.passkey.index');
    Route::post('/passkey/register/options', [Auth\PasskeyController::class, 'registerOptions'])->name('auth.passkey.register.options');
    Route::post('/passkey/register', [Auth\PasskeyController::class, 'register'])->name('auth.passkey.register');
    Route::delete('/passkey/{id}', [Auth\PasskeyController::class, 'delete'])->name('auth.passkey.delete');
});

Route::middleware(['throttle:authentication'])->group(function () {
    Route::post('/passkey/login/options', [Auth\PasskeyController::class, 'authenticateOptions'])->name('auth.passkey.login.options');
    Route::post('/passkey/login', [Auth\PasskeyController::class, 'authenticate'])->name('auth.passkey.login');
});

Route::fallback([Auth\LoginController::class, 'index']);
AUTHEOF

    # Update LoginController to redirect to custom pages
    cat > "$PANEL_PATH/app/Http/Controllers/Auth/LoginController.php" <<'LOGCTRL'
<?php
namespace Pterodactyl\Http\Controllers\Auth;
use Carbon\CarbonImmutable;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Pterodactyl\Facades\Activity;
use Illuminate\Database\Eloquent\ModelNotFoundException;
class LoginController extends AbstractLoginController
{
    public function index() { return redirect('/auth/login/custom'); }
    public function login(Request $request): JsonResponse
    {
        if ($this->hasTooManyLoginAttempts($request)) { $this->fireLockoutEvent($request); $this->sendLockoutResponse($request); }
        try { $username = $request->input('user'); $user = User::query()->where($this->getField($username), $username)->firstOrFail(); }
        catch (ModelNotFoundException) { $this->sendFailedLoginResponse($request); }
        if (!password_verify($request->input('password'), $user->password)) { $this->sendFailedLoginResponse($request, $user); }
        if (!$user->use_totp) { return $this->sendLoginResponse($user, $request); }
        Activity::event('auth:checkpoint')->withRequestMetadata()->subject($user)->log();
        $request->session()->put('auth_confirmation_token', ['user_id' => $user->id, 'token_value' => $token = Str::random(64), 'expires_at' => CarbonImmutable::now()->addMinutes(5)]);
        return new JsonResponse(['data' => ['complete' => false, 'confirmation_token' => $token]]);
    }
    public function checkUser(Request $request): JsonResponse { return $this->login($request); }
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user) { $this->auth->guard()->logout(); $request->session()->invalidate(); $request->session()->regenerateToken(); }
        return response()->json(['status' => 'logged_out']);
    }
    public function stopImpersonating(Request $request): JsonResponse { $request->session()->forget('admin_impersonate'); return response()->json(['status' => 'stopped']); }
    protected function getField(?string $input = null): string { return filter_var($input, FILTER_VALIDATE_EMAIL) ? 'email' : 'username'; }
}
LOGCTRL

    # Update RegisterController to redirect
    cat > "$PANEL_PATH/app/Http/Controllers/Auth/RegisterController.php" <<'REGCTRL'
<?php
namespace Pterodactyl\Http\Controllers\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Http\Controllers\Controller;
class RegisterController extends Controller
{
    public function __construct() {}
    public function index() { return redirect('/auth/register/custom'); }
    public function register(Request $request): JsonResponse
    {
        $request->validate(['username' => ['required', 'string', 'max:191'], 'email' => ['required', 'string', 'email', 'max:255'], 'password' => ['required', 'string', 'min:8', 'confirmed']]);
        $username = $request->input('username'); $email = $request->input('email');
        $exists = DB::table('users')->where('username', $username)->orWhere('email', $email)->first();
        if ($exists) return response()->json(['errors' => [['detail' => 'A user with that username or email already exists.']]], 422);
        DB::table('users')->insert(['uuid' => (string) Str::uuid(), 'username' => $username, 'email' => $email, 'password' => Hash::make($request->input('password')), 'name_first' => $request->input('name_first', ''), 'name_last' => $request->input('name_last', ''), 'language' => 'en', 'root_admin' => false, 'use_totp' => false, 'gravatar' => true, 'credit' => '0.00', 'referral_balance' => '0.00', 'external_id' => '', 'created_at' => now(), 'updated_at' => now()]);
        $user = DB::table('users')->where('email', $email)->first(); auth()->loginUsingId($user->id);
        return new JsonResponse(['data' => ['complete' => true, 'intended' => '/']]);
    }
}
REGCTRL

    # Fix root URL to redirect to custom login when not authenticated
    echo "  Fixing root URL redirect..."
    python3 << 'ROOTFIXEOF'
import re
with open("/var/www/pterodactyl/routes/base.php", "r") as f:
    c = f.read()
c = c.replace(
    "Route::get('/', [Base\\IndexController::class, 'index'])->name('index')->fallback();",
    "Route::get('/', function () { if (auth()->check()) { return view('templates/base.core'); } return redirect('/auth/login/custom'); })->name('index')->fallback();"
)
c = c.replace(
    "Route::get('/{react}', [Base\\IndexController::class, 'index'])",
    "Route::get('/{react}', function () { if (auth()->check()) { return view('templates/base.core'); } return redirect('/auth/login/custom'); })"
)
with open("/var/www/pterodactyl/routes/base.php", "w") as f:
    f.write(c)
ROOTFIXEOF
    echo "  Root URL redirect configured"

    echo "  Custom auth pages created"
}

finalize() {
    echo "Finalizing..."
    chown -R www-data:www-data "$PANEL_PATH"
    chmod -R 755 "$PANEL_PATH/storage" "$PANEL_PATH/bootstrap/cache" 2>/dev/null || true
    cd "$PANEL_PATH"
    php8.4 artisan config:clear && php8.4 artisan cache:clear && php8.4 artisan route:clear && php8.4 artisan view:clear
    php8.4 artisan config:cache && php8.4 artisan event:cache && php8.4 artisan view:cache
    php8.4 artisan route:cache 2>/dev/null || php8.4 artisan route:clear
    php8.4 artisan queue:restart

    mkdir -p /var/log/pterodactyl
    chown www-data:www-data /var/log/pterodactyl
    cat > /etc/supervisor/conf.d/pterodactyl-scheduler.conf <<'EOF'
[program:pterodactyl-scheduler]
command=php8.4 /var/www/pterodactyl/artisan schedule:work
directory=/var/www/pterodactyl
user=www-data
autostart=true
autorestart=true
startretries=3
stopasgroup=true
killasgroup=true
stderr_logfile=/var/log/pterodactyl/scheduler.err.log
stdout_logfile=/dev/null
EOF
    cat > /etc/supervisor/conf.d/pterodactyl-worker.conf <<'EOF'
[program:pterodactyl-worker]
command=php8.4 /var/www/pterodactyl/artisan queue:work --queue=high,standard,default,low --sleep=3 --tries=3 --timeout=90
directory=/var/www/pterodactyl
user=www-data
autostart=true
autorestart=true
startretries=3
stopwaitsecs=360
stopasgroup=true
killasgroup=true
stderr_logfile=/var/log/pterodactyl/worker.err.log
stdout_logfile=/var/log/pterodactyl/worker.out.log
EOF
    supervisorctl reread 2>/dev/null || true
    supervisorctl update 2>/dev/null || true
    supervisorctl restart pterodactyl-scheduler 2>/dev/null || supervisorctl start pterodactyl-scheduler 2>/dev/null || true
    supervisorctl restart pterodactyl-worker 2>/dev/null || supervisorctl start pterodactyl-worker 2>/dev/null || true
    systemctl restart php8.4-fpm 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
}

# ════════════════════════════════════════════
#  FRESH INSTALL
# ════════════════════════════════════════════
do_install() {
    echo ""
    echo "================================="
    echo "  Avtix Game Panel - Install"
    echo "================================="
    echo ""

    send_approval_request

    echo ""
    echo "Starting installation..."
    echo ""

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl wget git unzip nginx mariadb-server redis-server supervisor software-properties-common

    echo "[1/9] Installing PHP 8.4..."
    if ! command -v php8.4 >/dev/null 2>&1; then
        rm -f /etc/apt/trusted.gpg.d/php.gpg /usr/share/keyrings/deb.sury.org-php.gpg 2>/dev/null || true
        curl -sSLo /tmp/php.gpg https://packages.sury.org/php/apt.gpg 2>/dev/null
        install -o root -g root -m 644 /tmp/php.gpg /etc/apt/trusted.gpg.d/php.gpg
        install -o root -g root -m 644 /tmp/php.gpg /usr/share/keyrings/deb.sury.org-php.gpg
        rm -f /tmp/php.gpg
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/php.list
        apt-get update -y
    fi
    apt-get install -y php8.4 php8.4-cli php8.4-fpm php8.4-bcmath php8.4-curl php8.4-gd php8.4-mbstring php8.4-mysql php8.4-opcache php8.4-xml php8.4-zip php8.4-intl
    update-alternatives --set php /usr/bin/php8.4 2>/dev/null || true
    ln -sf /usr/bin/php8.4 /usr/bin/php
    ln -sf /usr/bin/php8.4 /usr/local/bin/php

    echo "[2/9] Installing Composer..."
    if ! command -v composer >/dev/null 2>&1; then
        curl -sS https://getcomposer.org/installer | php8.4 -- --install-dir=/usr/local/bin --filename=composer
    fi
    export COMPOSER_ALLOW_SUPERUSER=1

    echo "[3/9] Starting services..."
    systemctl enable nginx mariadb redis-server supervisor 2>/dev/null || true
    systemctl start nginx mariadb redis-server supervisor 2>/dev/null || true
    systemctl restart php8.4-fpm 2>/dev/null || true

    echo "[4/9] Setting up database..."
    mysql -u root -e "DROP DATABASE IF EXISTS panel; CREATE DATABASE panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    mysql -u root -e "CREATE USER IF NOT EXISTS 'panel'@'127.0.0.1' IDENTIFIED BY 'AvtixPanel2026'; GRANT ALL ON panel.* TO 'panel'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null || true
    mysql -u root -e "CREATE USER IF NOT EXISTS 'panel'@'localhost' IDENTIFIED BY 'AvtixPanel2026'; GRANT ALL ON panel.* TO 'panel'@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null || true

    echo "[5/9] Cloning Pterodactyl Panel..."
    if [[ -d "$PANEL_PATH" ]]; then
        mv "$PANEL_PATH" "/var/www/pterodactyl_old_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    git clone https://github.com/pterodactyl/panel.git "$PANEL_PATH" --depth 1

    echo "[6/9] Downloading and applying theme..."
    download_theme
    apply_theme

    echo "[7/9] Patching and fixing..."
    replace_ioncube_files
    patch_js_files
    create_controllers
    create_services_middleware
    fix_code
    create_custom_auth
    add_routes
    fix_nginx_cache
    cleanup_duplicates
    rm -rf "$TMP"

    echo "[8/9] Configuring..."
    configure_env
    install_deps
    run_migrate
    create_admin
    fix_nginx

    # Configure OPcache for performance
    echo "Configuring OPcache..."
    cat > /etc/php/8.4/mods-available/opcache.ini <<'OPCACHEOF'
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.fast_shutdown=1
OPCACHEOF
    php8.4enmod opcache 2>/dev/null || true
    echo "  OPcache configured"

    finalize

    echo ""
    echo "================================="
    echo "  Install Complete!"
    echo "================================="
    echo "  Panel URL: https://your-domain.com"
    echo "  Admin:     admin@admin.com / admin"
    echo "  DB:        panel / AvtixPanel2026"
    echo "================================="
}

# ════════════════════════════════════════════
#  REPAIR
# ════════════════════════════════════════════
do_repair() {
    echo ""
    echo "================================="
    echo "  Avtix Game Panel - Repair"
    echo "================================="
    echo ""

    if [[ ! -d "$PANEL_PATH" ]]; then
        echo "Error: Panel not found. Run fresh install instead."
        exit 1
    fi

    read -p "Continue with repair? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then echo "Aborted."; exit 0; fi

    download_theme

    echo "Re-applying theme..."
    rm -rf "$PANEL_PATH/public/assets" "$PANEL_PATH/public/DGEN" 2>/dev/null || true
    cp -rf "$INNER/public/"* "$PANEL_PATH/public/" 2>/dev/null || true
    rm -rf "$PANEL_PATH/resources/views" 2>/dev/null || true
    cp -rf "$INNER/resources/views" "$PANEL_PATH/resources/" 2>/dev/null || true
    cp -rf "$INNER/resources/lang" "$PANEL_PATH/resources/" 2>/dev/null || true
    cp -f "$INNER/routes/"*.php "$PANEL_PATH/routes/" 2>/dev/null || true

    replace_ioncube_files
    patch_js_files
    create_controllers
    create_services_middleware
    fix_code
    create_custom_auth
    add_routes
    fix_nginx_cache
    cleanup_duplicates
    rm -rf "$TMP"

    cd "$PANEL_PATH"
    php8.4 artisan config:clear && php8.4 artisan cache:clear && php8.4 artisan route:clear && php8.4 artisan view:clear
    php8.4 artisan config:cache && php8.4 artisan route:cache && php8.4 artisan view:cache
    chown -R www-data:www-data "$PANEL_PATH"
    systemctl restart php8.4-fpm 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true

    echo ""
    echo "================================="
    echo "  Repair Complete!"
    echo "================================="
}

# ════════════════════════════════════════════
#  UNINSTALL
# ════════════════════════════════════════════
do_uninstall() {
    echo ""
    echo "================================="
    echo "  Avtix Game Panel - Uninstall"
    echo "================================="
    echo ""

    if [[ ! -d "$PANEL_PATH" ]]; then echo "Error: Panel not found."; exit 1; fi
    read -p "Type 'UNINSTALL' to confirm: " CONFIRM
    [[ "$CONFIRM" != "UNINSTALL" ]] && echo "Aborted." && exit 0

    TMP=$(mktemp -d)
    git clone https://github.com/pterodactyl/panel.git "$TMP/vanilla" --depth 1
    rm -rf "$PANEL_PATH/public/assets" && cp -rf "$TMP/vanilla/public/assets" "$PANEL_PATH/public/"
    rm -rf "$PANEL_PATH/resources/views" && cp -rf "$TMP/vanilla/resources/views" "$PANEL_PATH/resources/"
    rm -f "$PANEL_PATH/routes/"*.php && cp -f "$TMP/vanilla/routes/"*.php "$PANEL_PATH/routes/"
    for f in "$TMP/vanilla/config/"*.php; do
        fname=$(basename "$f")
        case "$fname" in database.php|app.php|cache.php|sessions.php|queue.php|logging.php|mail.php) continue ;; esac
        cp -f "$f" "$PANEL_PATH/config/" 2>/dev/null || true
    done
    rm -rf "$PANEL_PATH/app/Http/Controllers/Api/Client/DGEN" "$PANEL_PATH/app/Http/Controllers/Api/Client/Servers/DGEN" "$PANEL_PATH/app/Http/Controllers/Api/Client/Admin/DGEN" "$PANEL_PATH/app/Http/Controllers/Api/Client/Theme" "$TMP"

    cd "$PANEL_PATH"
    php8.4 artisan config:clear && php8.4 artisan cache:clear && php8.4 artisan route:clear && php8.4 artisan view:clear
    chown -R www-data:www-data "$PANEL_PATH"
    systemctl restart php8.4-fpm 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    echo "Uninstall complete!"
}

# ════════════════════════════════════════════
#  MENU
# ════════════════════════════════════════════
echo ""
echo "================================="
echo "  Avtix Game Panel"
echo "================================="
echo ""
echo "  1) Install   - Fresh install on new VPS"
echo "  2) Repair    - Re-apply theme (keeps data)"
echo "  3) Uninstall - Remove theme, restore vanilla"
echo ""
echo "================================="
echo ""
read -p "  Select option [1-3]: " CHOICE
case "$CHOICE" in
    1) do_install ;;
    2) do_repair ;;
    3) do_uninstall ;;
    *) echo "Invalid option."; exit 1 ;;
esac
