DIR ?= testdir
MALICIOUS_DIR ?= malicious_dir
INTERVAL ?= 5

.PHONY: setup run restore

setup:
	mkdir -p $(MALICIOUS_DIR)

run: setup
	./antivirusd.sh $(DIR) $(MALICIOUS_DIR) $(INTERVAL)

restore: setup
	./restore.sh $(DIR) $(MALICIOUS_DIR)
