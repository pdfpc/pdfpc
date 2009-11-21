VALAC = /usr/bin/valac


VALA_SRC = src/pdf_presenter_console.vala \
	       src/classes/pdf_image.vala \
		   src/classes/presentation_window.vala \
		   src/classes/presentation_controller.vala \
		   src/classes/presenter_window.vala \
		   src/classes/cache_status.vala

VALA_PKG = --pkg gio-2.0 \
           --pkg poppler-glib \
 		   --pkg gtk+-2.0 \
		   --pkg posix

PKG_CONFIG_CFLAGS = `pkg-config --cflags gobject-2.0` \
				    `pkg-config --cflags gio-2.0` \
				    `pkg-config --cflags poppler-glib` \
				    `pkg-config --cflags gtk+-2.0` \
				    `pkg-config --cflags gthread-2.0` 

PKG_CONFIG_LIBS = `pkg-config --libs gobject-2.0` \
 			      `pkg-config --libs gio-2.0` \
			      `pkg-config --libs poppler-glib` \
			      `pkg-config --libs gtk+-2.0` \
				  `pkg-config --libs gthread-2.0` 

BUILD_DIR = build

$(BUILD_DIR)/pdf_presenter_console: $(VALA_SRC:%.vala=$(BUILD_DIR)/%.o)
	$(CC) $(PKG_CONFIG_LIBS) $^ -o $@

$(VALA_SRC:%.vala=$(BUILD_DIR)/%.o): %.o: %.c
	$(CC) -c $(PKG_CONFIG_CFLAGS) $< -o $@

$(VALA_SRC:%.vala=$(BUILD_DIR)/%.c): $(VALA_SRC)
	$(VALAC) --thread -C $(VALA_PKG) -d $(BUILD_DIR) $^

clean:
	-rm $(VALA_SRC:%.vala=$(BUILD_DIR)/%.*)
	-rm $(BUILD_DIR)/pdf_presenter_console

.PHONY: clean
