
VERSION=1.0
BUILD=./build

PACKAGE=$(BUILD)/fpm-repository_$(VERSION)_all.deb

OUT = $(PACKAGE) $(BUILD)/repository.key
default: $(PACKAGE)

$(BUILD):
	[ ! -d $@ ] && mkdir $@

$(BUILD)/repository.key:
	curl -s https://jordansissel.github.io/actions-experiments/packages/repository.asc | gpg --dearmor > $@

$(BUILD)/fpm-repository_$(VERSION)_all.deb: $(BUILD)
$(BUILD)/fpm-repository_$(VERSION)_all.deb: $(BUILD)/repository.key
$(BUILD)/fpm-repository_$(VERSION)_all.deb: fpm.sources fpm.pref repoconfig.sh
$(BUILD)/fpm-repository_$(VERSION)_all.deb:
	fpm -s dir -t deb -n fpm-repository -v $(VERSION) \
		-p "$(BUILD)/" \
		-a all \
		-f \
		--after-install repoconfig.sh \
		--depends ca-certificates \
		$(BUILD)/repository.key=/usr/share/keyrings/fpm-archive-keyring.pgp \
		fpm.sources=/etc/apt/sources.list.d/fpm.sources \
		fpm.pref=/etc/apt/preferences.d/fpm.pref

clean:
	rm -f $(OUT)