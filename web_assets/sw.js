// Possession service worker — COOP/COEP injection only.
//
// The Godot 4 web build needs SharedArrayBuffer, which requires the
// Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy response
// headers. GitHub Pages can't set them, so this SW patches them onto every
// response. Same dual-mode pattern as the upstream coi-serviceworker
// (the file is loaded both as a regular <script> on the main thread for
// registration, and as the SW itself once registered).
//
// NOTE: offline asset caching was attempted in an earlier revision but
// broke the COOP/COEP path on certain browsers (page reloaded into a
// state without SharedArrayBuffer). Reinstating the simpler upstream
// behaviour while we figure out a safe caching layer to add on top.

/*! Based on coi-serviceworker v0.1.7 — Guido Zuidhof and contributors, MIT licensed */
let coepCredentialless = false;

if (typeof window === 'undefined') {
    self.addEventListener('install', () => self.skipWaiting());
    self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

    self.addEventListener('message', (ev) => {
        if (!ev.data) return;
        if (ev.data.type === 'deregister') {
            self.registration.unregister()
                .then(() => self.clients.matchAll())
                .then((clients) => clients.forEach((c) => c.navigate(c.url)));
        } else if (ev.data.type === 'coepCredentialless') {
            coepCredentialless = ev.data.value;
        }
    });

    self.addEventListener('fetch', (event) => {
        const r = event.request;
        if (r.cache === 'only-if-cached' && r.mode !== 'same-origin') return;

        const request = (coepCredentialless && r.mode === 'no-cors')
            ? new Request(r, { credentials: 'omit' })
            : r;

        event.respondWith(
            fetch(request).then((response) => {
                if (response.status === 0) return response;
                const newHeaders = new Headers(response.headers);
                newHeaders.set('Cross-Origin-Embedder-Policy',
                    coepCredentialless ? 'credentialless' : 'require-corp');
                if (!coepCredentialless) {
                    newHeaders.set('Cross-Origin-Resource-Policy', 'cross-origin');
                }
                newHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
                return new Response(response.body, {
                    status: response.status,
                    statusText: response.statusText,
                    headers: newHeaders,
                });
            }).catch((e) => console.error(e))
        );
    });

} else {
    (() => {
        const reloadedBySelf = window.sessionStorage.getItem('coiReloadedBySelf');
        window.sessionStorage.removeItem('coiReloadedBySelf');
        const coepDegrading = (reloadedBySelf === 'coepdegrade');

        const coi = {
            shouldRegister: () => !reloadedBySelf,
            shouldDeregister: () => false,
            coepCredentialless: () => true,
            coepDegrade: () => true,
            doReload: () => window.location.reload(),
            quiet: false,
            ...window.coi,
        };

        const n = navigator;
        const controlling = n.serviceWorker && n.serviceWorker.controller;

        if (controlling && !window.crossOriginIsolated) {
            window.sessionStorage.setItem('coiCoepHasFailed', 'true');
        }
        const coepHasFailed = window.sessionStorage.getItem('coiCoepHasFailed');

        if (controlling) {
            const reloadToDegrade = coi.coepDegrade() && !(coepDegrading || window.crossOriginIsolated);
            n.serviceWorker.controller.postMessage({
                type: 'coepCredentialless',
                value: (reloadToDegrade || (coepHasFailed && coi.coepDegrade()))
                    ? false : coi.coepCredentialless(),
            });
            if (reloadToDegrade) {
                !coi.quiet && console.log('Reloading page to degrade COEP.');
                window.sessionStorage.setItem('coiReloadedBySelf', 'coepdegrade');
                coi.doReload('coepdegrade');
            }
            if (coi.shouldDeregister()) {
                n.serviceWorker.controller.postMessage({ type: 'deregister' });
            }
        }

        if (window.crossOriginIsolated !== false || !coi.shouldRegister()) return;
        if (!window.isSecureContext) {
            !coi.quiet && console.log('SW not registered (insecure context).');
            return;
        }
        if (!n.serviceWorker) {
            !coi.quiet && console.error('SW not registered (private mode?).');
            return;
        }

        n.serviceWorker.register(window.document.currentScript.src).then(
            (registration) => {
                !coi.quiet && console.log('Possession SW registered:', registration.scope);
                registration.addEventListener('updatefound', () => {
                    !coi.quiet && console.log('Reloading page to make use of updated SW.');
                    window.sessionStorage.setItem('coiReloadedBySelf', 'updatefound');
                    coi.doReload();
                });
                if (registration.active && !n.serviceWorker.controller) {
                    !coi.quiet && console.log('Reloading page to make use of SW.');
                    window.sessionStorage.setItem('coiReloadedBySelf', 'notcontrolling');
                    coi.doReload();
                }
            },
            (err) => console.error('Possession SW failed to register:', err)
        );
    })();
}
