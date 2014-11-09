TARGET := iphone:clang::5.0
ARCHS := armv7 arm64

ADDITIONAL_CFLAGS += -fobjc-arc -g -fvisibility=hidden
ADDITIONAL_LDFLAGS += -Wl,-map,$@.map -g -x c /dev/null -x none

TWEAK_NAME = WeeLoader
WeeLoader_FILES = Tweak.x
WeeLoader_FRAMEWORKS = UIKit
WeeLoader_PRIVATE_FRAMEWORKS = BulletinBoard
WeeLoader_LDFLAGS = -weak_framework SpringBoardUIServices

after-stage::
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -d \( -iname '*.dSYM' -or -iname '*.map' \) -execdir rm -rf {} \;$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/System/Library/WeeAppPlugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/System/Library/BulletinBoardPlugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/Plugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/BulletinBoardPlugins$(ECHO_END)

after-install::
	install.exec "(killall backboardd || killall SpringBoard) 2>/dev/null"

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
