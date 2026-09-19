# Precision Parts — Web Fixes & Hostinger Deployment Guide

---

## What's Fixed

| Issue | Fix |
|-------|-----|
| Bottom nav on web/desktop | `WebShell` widget → sticky top nav bar on screen ≥700 px |
| Product card overflow (35px) | `ClipRect` + `mainAxisSize` fix in product card (see below) |
| Admin dashboard 390px cap | Responsive 2-column layout on desktop with sidebar |
| Hostinger 404 on page refresh | `.htaccess` SPA rewrite rule |
| Slow initial load | Gzip + 1-year asset caching in `.htaccess` |

---

## Files Delivered

```
web_shell.dart              → lib/core/widgets/
admin_dashboard_screen.dart → lib/features/admin/   (replace original)
web/index.html              → web/   (replace original)
web/.htaccess               → upload to Hostinger public_html root
```

---

## 1. WebShell — Add to Every Customer Screen

```dart
// BEFORE (home_screen.dart, search_screen.dart, etc.)
return Scaffold(
  bottomNavigationBar: NavigationBar(...),
  body: ...,
);

// AFTER — just wrap with WebShell, remove your NavigationBar
import 'package:precision_parts_production/core/widgets/web_shell.dart';

return WebShell(
  selectedIndex: 0,   // 0=Home 1=Search 2=Orders 3=Profile
  child: YourBodyWidget(),
);
```

`WebShell` auto-detects width:
- **< 700 px** → original `NavigationBar` at bottom (mobile/tablet)
- **≥ 700 px** → sticky top nav bar with logo + nav links (desktop/Hostinger)

---

## 2. Product Card Overflow Fix

In your `ProductCard` widget (wherever you have the product tile), find the
`Stack` or `Column` that holds the price/badge section and add `clipBehavior`:

```dart
// In product_card.dart — find the card Column / Container
// Add overflow clipping so bottom badges don't overflow

Card(
  clipBehavior: Clip.hardEdge,   // ← add this line
  child: Column(
    children: [
      // image
      Expanded(
        child: Image.network(imageUrl, fit: BoxFit.cover),
      ),
      // info section — make sure this has a fixed height or uses mainAxisSize.min
      Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,   // ← add this
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            // ...price, rating
          ],
        ),
      ),
    ],
  ),
)
```

For the home screen grid, increase card aspect ratio slightly:
```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.72,   // was 0.75 → give cards more height
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  ),
  ...
)
```

---

## 3. My Orders Screen — Remove env var leak

The env vars visible in Screenshot 2 are from your IDE (VS Code), not the app.
They're in your `.env` or `--dart-define` args. 

Make sure you never hard-code Supabase keys in source — use `--dart-define`:
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJh...
```

And in code:
```dart
const supabaseUrl  = String.fromEnvironment('SUPABASE_URL');
const supabaseKey  = String.fromEnvironment('SUPABASE_ANON_KEY');
```

---

## 4. Build for Web

```bash
cd precision_parts_production

# Build release web bundle
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Output is in:  build/web/
```

---

## 5. Deploy to Hostinger (Step-by-Step)

### Option A — File Manager (easiest)

1. Open **Hostinger hPanel → File Manager**
2. Navigate to `public_html` (or create a sub-folder like `parts/`)
3. Upload ALL contents of `build/web/` (not the folder itself — the *contents*)
4. Upload `.htaccess` to the same folder (tick "show hidden files" if needed)
5. Visit your domain — done ✅

### Option B — FTP

```bash
# Install lftp or use FileZilla
lftp -u YOUR_FTP_USER,YOUR_FTP_PASS ftp.yourdomain.com << EOF
mirror -R build/web/ public_html/
put web/.htaccess -o public_html/.htaccess
bye
EOF
```

### Option C — GitHub + Hostinger Git Deploy

1. Push `build/web/` to a GitHub repo (or use Hostinger's built-in Git)
2. In hPanel → **Git** → connect repo → set deploy path to `public_html`
3. Add a deploy hook to run `flutter build web` before deploy
   (or pre-build locally and push the `build/web` output)

---

## 6. Supabase CORS — Required for Web

In **Supabase dashboard → Settings → API**:

Add your Hostinger domain to the allowed origins:
```
https://yourdomain.com
https://www.yourdomain.com
```

In **Authentication → URL Configuration**:
- Site URL: `https://yourdomain.com`
- Redirect URLs: `https://yourdomain.com/**`

---

## 7. Custom Domain SSL (Hostinger)

1. hPanel → **Domains** → point your domain nameservers to Hostinger  
   OR add an A record pointing to your Hostinger server IP
2. hPanel → **SSL** → enable **Free SSL (Let's Encrypt)** — one click
3. The `.htaccess` already forces HTTPS redirect once SSL is active

---

## Quick Checklist Before Going Live

- [ ] `flutter build web --release` completes without errors
- [ ] All files from `build/web/` uploaded to `public_html`
- [ ] `.htaccess` uploaded (check hidden files are visible in File Manager)
- [ ] Supabase CORS origin added for your domain
- [ ] Supabase Auth redirect URLs updated
- [ ] SSL enabled in Hostinger hPanel
- [ ] Test: visit `https://yourdomain.com/home` directly (not just root) — should load, not 404
