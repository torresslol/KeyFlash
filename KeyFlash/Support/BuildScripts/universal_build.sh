#!/bin/bash

# 脚本用于验证应用是否构建为Universal Binary

APP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
APP_BINARY="${APP_PATH}/Contents/MacOS/${PRODUCT_NAME}"

if [ -f "$APP_BINARY" ]; then
    # 使用file命令检查二进制文件类型
    FILE_OUTPUT=$(file "$APP_BINARY")
    echo "Binary file info: $FILE_OUTPUT"
    
    # 使用lipo命令检查支持的架构
    ARCHS=$(lipo -info "$APP_BINARY" | awk -F': ' '{print $2}')
    echo "Supported architectures: $ARCHS"
    
    # 检查是否同时支持x86_64和arm64
    if [[ $ARCHS == *"x86_64"* ]] && [[ $ARCHS == *"arm64"* ]]; then
        echo "SUCCESS: Application is a Universal Binary supporting both Intel and Apple Silicon."
    else
        echo "WARNING: Application is NOT a Universal Binary!"
        echo "Make sure ARCHS is set to \$(ARCHS_STANDARD) and ONLY_ACTIVE_ARCH is set to NO for Release builds."
    fi
else
    echo "ERROR: Binary file not found at $APP_BINARY"
    exit 1
fi

exit 0 