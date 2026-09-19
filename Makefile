.PHONY: verify

# Documentation hygiene only; this does not validate research results.
verify:
	git diff --check
