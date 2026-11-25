// Downloads the engine gzipped (39 MB to 10 MB) on a host that doesn't compress .wasm:
// Azure Static Web Apps. tools/deploy_swa.sh puts this and index.wasm.gz beside the game
// and loads it before Godot's index.js, whose loader fetches index.wasm. Anything missing
// (an old browser, the .gz) falls back to the plain index.wasm.
(function () {
	const plainFetch = window.fetch.bind(window);
	window.fetch = function (input, init) {
		if (input !== 'index.wasm' || typeof DecompressionStream === 'undefined') {
			return plainFetch(input, init);
		}
		return plainFetch('index.wasm.gz', init).then(function (response) {
			if (!response.ok || !response.body) {
				return plainFetch(input, init);
			}
			// A host that says Content-Encoding: gzip has had the browser unpack it already.
			const body = response.headers.get('Content-Encoding') === 'gzip'
				? response.body
				: response.body.pipeThrough(new DecompressionStream('gzip'));
			return new Response(body, { headers: { 'Content-Type': 'application/wasm' } });
		}, function () {
			return plainFetch(input, init);
		});
	};
}());
