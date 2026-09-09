//
// headphone_simple.h
// Infern0 - Minimal Headphone Color Changer
// 
// Simplified version with just button actions, no complex UI
//

#ifndef headphone_simple_h
#define headphone_simple_h

#import <UIKit/UIKit.h>
#import "tweaks/headphone_color.h"

// Create a simple button that opens the headphone color menu
UIButton *create_headphone_button(CGRect frame, id target, SEL action);

// Utility function to create a color picker alert
void show_headphone_color_menu(UIViewController *controller);

#endif /* headphone_simple_h */
