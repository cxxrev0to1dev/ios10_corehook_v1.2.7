include /opt/theos/makefiles/common.mk
TARGET = ipone:clang:8.0
ARCHS = armv7 arm64
export THEOS=/opt/theos/
export TARGET_CODESIGN = /opt/theos/bin/ldid
export TARGET_CODESIGN_FLAGS = "-Sent.xml"

SOURCE_FILES=$(wildcard src/*.m src/*.mm src/*.x src/*.xm)
TOOL_NAME = com.zbk.none.auto.click.disp
com.zbk.none.auto.click.disp_FILES = $(SOURCE_FILES)
com.zbk.none.auto.click.disp_LIBRARIES = MobileGestalt substrate
com.zbk.none.auto.click.disp_FRAMEWORKS = UIKit MobileCoreServices CoreFoundation
com.zbk.none.auto.click.disp_PRIVATE_FRAMEWORKS = IOKit SpringBoardServices Preferences
com.zbk.none.auto.click.disp_LDFLAGS = -lsqlite3

include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/tweak.mk
