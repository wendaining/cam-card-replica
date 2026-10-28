SHELL := /bin/bash
.SHELLFLAGS := -eo pipefail -c
SCHEME := CamCardReplica
PROJECT := CamCardReplica.xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro
IPAD_DESTINATION ?= platform=iOS Simulator,name=iPad Pro 11-inch (M5)
DERIVED_DATA_PATH ?= build
PYTHON ?= python3
SIMULATOR ?= iPhone 18 Pro
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA_PATH)

.PHONY: help bootstrap build test test-ui test-ipad bench audit lint format verify run relaunch reset photos testdata test-tooling clean hooks

help: ## 显示可用命令
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## 由 project.yml 生成 Xcode 工程
	xcodegen generate --spec project.yml

build: ## 编译 Debug
	$(XCODEBUILD) build

test: ## 单元 + 集成测试
	$(XCODEBUILD) test -only-testing:CamCardReplicaTests

test-ui: ## 端到端 T01–T20
	$(XCODEBUILD) test -enableCodeCoverage NO -only-testing:CamCardReplicaUITests

bench: ## 跑 Ground Truth 准确率评测（解析器 + Vision 全链路）
	mkdir -p TestResults
	$(XCODEBUILD) test -only-testing:CamCardReplicaTests/ParserBenchmarkTests -only-testing:CamCardReplicaTests/VisionOCRTests -only-testing:CamCardReplicaTests/ImageCorpusTests 2>&1 | tee TestResults/bench.log

audit: ## 检查文档与代码是否一致（悬空路径 / 不存在的 make 子命令 / 过期数字）
	python3 Scripts/audit_docs.py

lint: ## 静态检查（swiftlint 阻塞；swiftformat 只报告，因为规则会随版本变化）
	swiftlint --quiet
	-swiftformat --lint .

format: ## 自动格式化
	swiftformat .

verify: lint build test ## 提交前必跑

APP_PATH := $(DERIVED_DATA_PATH)/Build/Products/Debug-iphonesimulator/CamCardReplica.app
DEVICE_HUB_APP := $(shell xcode-select -p)/../Applications/DeviceHub.app
BUNDLE_ID := com.wendaining.CamCardReplica

run: ## 编译、装到模拟器并直接打开（第一次用这条）
	$(XCODEBUILD) build
	-xcrun simctl boot "$(SIMULATOR)"
	open -a "$(DEVICE_HUB_APP)"
	xcrun simctl bootstatus "$(SIMULATOR)" -b
	xcrun simctl install "$(SIMULATOR)" "$(APP_PATH)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

relaunch: ## 杀掉 App 再打开（验证数据持久化，T18）
	-xcrun simctl terminate "$(SIMULATOR)" $(BUNDLE_ID)
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

reset: ## 清空模拟器里的 App 数据（回到"首次启动"空态）
	-xcrun simctl terminate "$(SIMULATOR)" $(BUNDLE_ID)
	xcrun simctl uninstall "$(SIMULATOR)" $(BUNDLE_ID)
	xcrun simctl install "$(SIMULATOR)" "$(APP_PATH)"

photos: ## 把 50 张测试名片塞进模拟器相册（用来试"从相册导入"）
	@count=0; for f in TestData/cards/*.png TestData/cards/*.jpg; do \
		xcrun simctl addmedia "$(SIMULATOR)" "$$f" && count=$$((count+1)); done; \
	echo "已导入 $$count 张到模拟器相册"

test-ipad: ## 在 iPad 模拟器上跑 UI 测试（验证布局适配）
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(IPAD_DESTINATION)' test -enableCodeCoverage NO -only-testing:CamCardReplicaUITests

testdata: ## 重新生成语料（会改变 ground truth）
	$(PYTHON) Scripts/generate_test_cards.py --clean

test-tooling: ## 验证构建路径与语料字体
	$(PYTHON) Scripts/test_tooling.py

hooks: ## 安装 git hooks（conventional commit 校验）
	git config core.hooksPath .githooks
	chmod +x .githooks/*

clean:
	rm -rf build TestResults *.xcodeproj
