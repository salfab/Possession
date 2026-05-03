// Possession service worker — offline cache for the Web/HTML5 export.
//
// Background : an earlier revision of this SW only injected the
// Cross-Origin-Opener-Policy / Cross-Origin-Embedder-Policy headers
// needed by the threaded WASM build (SharedArrayBuffer requirement).
// Since the upgrade to Godot 4.3's nothreads variant
// (export_presets.cfg: variant/thread_support=false) the build no
// longer uses SAB, so the COI dance isn't needed anymore. That
// frees us to install a pure caching SW — which is what this file
// now is — so the game keeps working on iPad with airplane mode on,
// patchy cellular, etc.
//
// Strategy : cache-first with stale-while-revalidate. On install we
// precache the small set of bootstrap files (html/js/wasm/pck/manifest)
// so a freshly-installed PWA can run offline straight after first
// launch. On every fetch we serve the cached copy if any (and refresh
// it in the background), otherwise we go to the network and cache the
// response.
//
// Versioning : the CACHE_VERSION token below is replaced at build
// time by the CI workflow with the short commit SHA. Each deploy
// therefore opens a fresh cache, and the activate handler garbage-
// collects the previous one. Users can also force a clean slate via
// the "Reset SW" button rendered in the version banner — that posts
// {type:'deregister'} which we wire to caches.delete + unregister.
//
// Dual-mode pattern : this same file is loaded both as a regular
// <script src="sw.js"> on the main thread (for registration) and as
// the actual worker once registered. The branch on `typeof window`
// is the standard discriminator.

// __SHA__ is rewritten by the CI workflow with the short commit SHA, so
// the literal cache name appears in the deployed file (which lets the
// CI grep for "possession-<sha>" as a sanity check).
const CACHE_NAME = 'possession-__SHA__';

// Bootstrap set — enough to cold-boot the game offline. Other assets
// (audio worklets, optional icons) are picked up opportunistically by
// the fetch handler the first time they're requested.
const PRECACHE = [
	'./',
	'index.html',
	'index.js',
	'index.wasm',
	'index.pck',
	'manifest.json',
];

if (typeof window === 'undefined') {
	// ============================================================
	// Service-worker context
	// ============================================================

	self.addEventListener('install', (event) => {
		// Activate as soon as install completes, even if other tabs
		// are still controlled by an older worker — combined with
		// clients.claim() in `activate`, this means the very next
		// fetch hits the new SW and the new cache.
		self.skipWaiting();
		event.waitUntil((async () => {
			const cache = await caches.open(CACHE_NAME);
			// Precache file-by-file so a single 404 (e.g. an icon
			// renamed between Godot versions) doesn't abort the
			// whole install — log + skip + continue.
			for (const url of PRECACHE) {
				try {
					await cache.add(url);
				} catch (e) {
					console.warn('SW precache skipped:', url, e);
				}
			}
		})());
	});

	self.addEventListener('activate', (event) => {
		event.waitUntil((async () => {
			const keys = await caches.keys();
			await Promise.all(
				keys
					.filter((k) => k !== CACHE_NAME)
					.map((k) => caches.delete(k))
			);
			await self.clients.claim();
		})());
	});

	self.addEventListener('message', (ev) => {
		if (!ev || !ev.data) return;
		if (ev.data.type === 'deregister') {
			// Triggered by the version banner's "Reset SW" button —
			// nuke every cache and unregister, then reload all pages
			// in scope so the next request goes straight to network.
			ev.waitUntil((async () => {
				const keys = await caches.keys();
				await Promise.all(keys.map((k) => caches.delete(k)));
				await self.registration.unregister();
				const clients = await self.clients.matchAll();
				clients.forEach((c) => c.navigate(c.url));
			})());
		}
	});

	self.addEventListener('fetch', (event) => {
		const r = event.request;
		// Skip non-GET (POST, etc.) and cross-origin requests — only
		// the same-origin Godot bundle is cached.
		if (r.method !== 'GET') return;
		const url = new URL(r.url);
		if (url.origin !== self.location.origin) return;

		event.respondWith((async () => {
			const cache = await caches.open(CACHE_NAME);
			const cached = await cache.match(r);
			if (cached) {
				// Stale-while-revalidate : serve cached copy now,
				// fire a background refresh so subsequent loads pick
				// up server-side updates that landed without an SW
				// activate (e.g. a partial deploy or hot patch).
				const refresh = fetch(r).then((response) => {
					if (response && response.ok && response.type === 'basic') {
						cache.put(r, response.clone()).catch(() => {});
					}
					return response;
				}).catch(() => {});
				// Don't await — return cached immediately.
				event.waitUntil(refresh);
				return cached;
			}
			// Cache miss — fetch + cache opportunistically. Network
			// failures bubble up as a regular failed Response, which
			// the page can handle (the loader shows a retry banner).
			try {
				const response = await fetch(r);
				if (response && response.ok && response.type === 'basic') {
					cache.put(r, response.clone()).catch(() => {});
				}
				return response;
			} catch (e) {
				// Offline + cache miss + no network — return a 504
				// rather than throwing, so the caller sees a normal
				// (if useless) Response and doesn't have to handle a
				// raw network error too.
				return new Response('Offline and no cached copy available.', {
					status: 504,
					statusText: 'Gateway Timeout',
					headers: { 'Content-Type': 'text/plain' },
				});
			}
		})());
	});

} else {
	// ============================================================
	// Main-thread context — registration only
	// ============================================================
	if ('serviceWorker' in navigator && window.isSecureContext) {
		const url = window.document.currentScript.src;
		navigator.serviceWorker.register(url).then((reg) => {
			// Pick up updates as soon as a new SW finishes installing.
			// Reload the page so the freshly-activated worker controls
			// it (without this, the new SW would only kick in on the
			// next manual reload).
			reg.addEventListener('updatefound', () => {
				const installing = reg.installing;
				if (!installing) return;
				installing.addEventListener('statechange', () => {
					if (installing.state === 'activated' &&
						navigator.serviceWorker.controller) {
						// Don't auto-reload on the very first install
						// (no previous controller) — the page is
						// already running the latest assets.
						console.log('Possession SW updated — reloading.');
						window.location.reload();
					}
				});
			});
		}).catch((err) => {
			console.error('Possession SW failed to register:', err);
		});
	}
}
