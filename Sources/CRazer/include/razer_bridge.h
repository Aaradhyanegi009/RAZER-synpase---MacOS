#ifndef RAZER_BRIDGE_H
#define RAZER_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Check if Razer DeathAdder Essential is connected
bool razer_is_connected(void);

// Read current hardware settings from mouse
int razer_get_dpi(void);
int razer_get_polling_rate(void);
int razer_get_led_brightness(void);

// Set DPI (100 - 6400)
bool razer_set_dpi(uint16_t dpi);

// Set Polling Rate (125, 500, 1000)
bool razer_set_polling_rate(uint16_t rate);

// Set LED (effect: 0=off, 1=static, 2=breathing, 3=reactive; brightness: 0-255; r,g,b: 0-255)
bool razer_set_led(uint8_t effect, uint8_t brightness, uint8_t r, uint8_t g, uint8_t b);

#ifdef __cplusplus
}
#endif

#endif // RAZER_BRIDGE_H
