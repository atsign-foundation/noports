# srv multi performance test tooling

## Setup the environment

Serve this directory, for example with uv + python:

```
uv venv
source .venv/bin/activate
python -m http.server
```

Start up sshnpd:

```
sshnpd -a @daemon -m @client -d multi -sv --po localhost:8000
```

Start up npt:

```
npt -f @client -t @daemon -r @rv_am -d multi -l 8001 -p 8000 -K -T0
```

## Debugging

First, try with wget. This will load `index.html`, but no images:

```
wget localhost:8001
```

Then, try opening [localhost:8001](http://localhost:8001) in the browser,
observe that many images don't load.

To gather more network info:

- Stop the page from loading, if it still is.
- Open network tab in dev tools.
- Kill npt, and restart.
- Reload page in the browser.

## Notes about this tool

- I have duplicated and committed 20 copies of the same image to prevent false
  positives that might be caused by image caching.
