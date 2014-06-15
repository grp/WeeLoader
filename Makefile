ADDITIONAL_CFLAGS += -fobjc-arc -fvisibility=hidden
ADDITIONAL_LDFLAGS += -fobjc-arc

TWEAK_NAME = WeeLoader
WeeLoader_FILES = Tweak.x
WeeLoader_PRIVATE_FRAMEWORKS = BulletinBoard SpringBoardUIServices

after-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/System/Library/WeeAppPlugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/System/Library/BulletinBoardPlugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/Plugins$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/BulletinBoardPlugins$(ECHO_END)

after-install::
	install.exec "(killall backboardd || killall SpringBoard) 2>/dev/null"

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
