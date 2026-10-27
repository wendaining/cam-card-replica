SHELL := /bin/bash
SCHEME := CamCardReplica
PROJECT := CamCardReplica.xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone Duo
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)'

.PHONY: help bootstrap build test test-ui bench lint format verify run testdata clean hooks

help: ## 显示可用命令
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## 由 project.yml 生成 Xcode 工程
	xcodegen generate --spec project.yml

build: ## 编译 Debug
	$(XCODEBUILD) build

test: ## 单元 + 集成测试
	$(XCODEBUILD) test -only-testing:CamCardReplicaTests

test-ui: ## 端到端 T01–T20
	$(XCODEBUILD) test -only-testing:CamCardReplicaUITests

bench: ## 跑 Ground Truth 准确率评测（解析器 + Vision 全链路）
	mkdir -p TestResults
	$(XCODEBUILD) test -only-testing:CamCardReplicaTests/ParserBenchmarkTests -only-testing:CamCardReplicaTests/VisionOCRTests 2>&1 | tee TestResults/bench.log

lint: ## 静态检查
	swiftformat --lint Sources Tests UITests
	swiftlint --quiet

format: ## 自动格式化
	swiftformat Sources Tests UITests

verify: lint build test ## 提交前必跑

run: ## 直接装到模拟器并启动
	$(XCODEBUILD) build
	xcrun simctl boot "iPhone Duo" || true
	open -a Simulator

testdata: ## 重新生成语料（会改变 ground truth）
	python3 Scripts/generate_test_cards.py --clean

hooks: ## 安装 git hooks（conventional commit 校验）
	git config core.hooksPath .githooks
	chmod +x .githooks/*

clean:
	rm -rf build TestResults *.xcodeproj
