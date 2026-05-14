.PHONY: help test build install run deploy icon clean

APP_NAME := EdgeLauncher
INSTALL_DIR := $(HOME)/Applications
INSTALL_PATH := $(INSTALL_DIR)/$(APP_NAME).app
BUILD_DIR := build
PRODUCT_PATH := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
VERSION := $(shell cat VERSION 2>/dev/null || echo 0.0.0)

help:
	@echo "EdgeLauncher v$(VERSION)"
	@echo ""
	@echo "Targets:"
	@echo "  make test     - 단위 테스트 실행"
	@echo "  make build    - Release 빌드"
	@echo "  make install  - 빌드 + ~/Applications 에 설치"
	@echo "  make run      - 설치된 앱 실행"
	@echo "  make deploy   - 빌드 + 재설치 + 실행 (deploy.sh)"
	@echo "  make icon     - AppIcon PNG 재생성"
	@echo "  make clean    - build/ 디렉토리 삭제"

test:
	@bash scripts/test.sh

build:
	@xcodebuild -project $(APP_NAME).xcodeproj \
	  -scheme $(APP_NAME) \
	  -configuration Release \
	  -derivedDataPath $(BUILD_DIR) \
	  -quiet \
	  CODE_SIGNING_ALLOWED=NO \
	  CODE_SIGNING_REQUIRED=NO \
	  CODE_SIGN_IDENTITY="" \
	  build

install: build
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_PATH)
	@cp -R $(PRODUCT_PATH) $(INSTALL_PATH)
	@xattr -dr com.apple.quarantine $(INSTALL_PATH) 2>/dev/null || true
	@echo "installed: $(INSTALL_PATH)"

run:
	@open $(INSTALL_PATH)

deploy:
	@bash scripts/deploy.sh

icon:
	@python3 scripts/make-icon.py

clean:
	@rm -rf $(BUILD_DIR)
	@echo "cleaned: $(BUILD_DIR)"
