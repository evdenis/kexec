getprop = $(shell grep "^$(1)=" module.prop | head -n1 | cut -d'=' -f2)

MODNAME ?= $(call getprop,id)
MODVER ?= $(call getprop,version)
ZIP = $(MODNAME)-$(MODVER).zip

all: $(ZIP)

zip: $(ZIP)

%.zip: clean
	zip -r9 $(ZIP) . -x $(MODNAME)-*.zip LICENSE CLAUDE.md README.md \
	    CHANGELOG.md CHECKLIST.md cliff.toml .gitignore .gitattributes \
	    .dockerignore Makefile Dockerfile \
	    /hooks/* /scripts/* /tests/* /out/* /.git* /.claude*

install: $(ZIP)
	adb push $(ZIP) /sdcard/
	echo '/data/adb/magisk/busybox unzip -p "/sdcard/$(ZIP)" META-INF/com/google/android/update-binary | /data/adb/magisk/busybox sh /proc/self/fd/0 x x "/sdcard/$(ZIP)"' | adb shell su -c sh -
	adb shell rm -f "/sdcard/$(ZIP)"

clean:
	rm -f *.zip
	rm -rf out out-*

lint:
	@STATUS=0; \
	for f in *.sh scripts/*.sh tests/*.sh; do \
	    [ -f "$$f" ] || continue; \
	    shellcheck "$$f" || STATUS=1; \
	done; \
	exit $$STATUS

setup:
	ln -sf ../../hooks/pre-commit .git/hooks/pre-commit

build-kexec:
	DOCKER_BUILDKIT=1 docker build \
	    --build-arg KEXEC_ARCH=arm64 \
	    --target=binary --output=type=local,dest=system/bin/ .

test-kexec:
	./tests/test-kexec-binary.sh system/bin/kexec arm64

update:
	curl -fS -o META-INF/com/google/android/update-binary.tmp \
	    https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh && \
	mv META-INF/com/google/android/update-binary.tmp META-INF/com/google/android/update-binary

.PHONY: all zip install clean lint setup build-kexec test-kexec update
