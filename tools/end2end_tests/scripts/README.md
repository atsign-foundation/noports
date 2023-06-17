

run_sshnpd.sh usage:

```
run_sshnpd.sh
    -t|--type <type> (required)
    -h|--help (optional)
    ONE OF THE FOLLOWING (required)
    -b|--branch <branch/commitid>
    -r|--release <release>
    -l|--local
```

Example usages:

```sh
run_sshnpd.sh -t sshnp -b gkc-refactor-sshnp
```

```sh
run_sshnpd.sh -t sshnpd -r 3.3.0
```

```sh
run_sshnpd.sh -t sshnpd -l
```