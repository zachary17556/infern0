//
// headphone_color.h
// Infern0 - Headphone Level Color Modifier
//

#ifndef headphone_color_h
#define headphone_color_h

#import <stdbool.h>

// Configure the target color to change headphone level UI to
// hexColor: Color in hex format, e.g., "#FF0000" for red
void headphone_configure_color(const char *hexColor);

// Apply the color change to all discovered headphone/volume UI elements
// Returns true on success, false if no elements found or color creation failed
bool headphone_apply_in_session(void);

// Restore all headphone UI colors to their original values
// Returns true on complete restoration, false if some objects were already released
bool headphone_stop_in_session(void);

// Forget all captured state (used internally)
void headphone_forget_state(void);

#endif /* headphone_color_h */
