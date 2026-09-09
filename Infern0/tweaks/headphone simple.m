//
// headphone_simple.m
// Infern0 - Minimal Headphone Color Changer
//

#import "headphone_simple.h"
#import "../LogTextView.h"

UIButton *create_headphone_button(CGRect frame, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    [button setTitle:@"🎵 Headphone Color" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

void show_headphone_color_menu(UIViewController *controller) {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Headphone Level Color" 
        message:@"Change the headphone indicator color from yellow to:" 
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Color options
    NSArray *colorOptions = @[
        @{@"name": @"🔴 Red", @"hex": @"#FF0000"},
        @{@"name": @"🟢 Green", @"hex": @"#00FF00"},
        @{@"name": @"🔵 Blue", @"hex": @"#0000FF"},
        @{@"name": @"🟡 Yellow", @"hex": @"#FFFF00"},
        @{@"name": @"🟣 Purple", @"hex": @"#FF00FF"},
        @{@"name": @"🔵 Cyan", @"hex": @"#00FFFF"},
        @{@"name": @"⚪ White", @"hex": @"#FFFFFF"},
        @{@"name": @"⚫ Black", @"hex": @"#000000"},
        @{@"name": @"🟠 Orange", @"hex": @"#FF8800"},
        @{@"name": @"🩷 Pink", @"hex": @"#FF1493"},
        @{@"name": @"💛 Gold", @"hex": @"#FFD700"},
    ];
    
    for (NSDictionary *colorDict in colorOptions) {
        UIAlertAction *action = [UIAlertAction 
            actionWithTitle:colorDict[@"name"] 
            style:UIAlertActionStyleDefault 
            handler:^(UIAlertAction *_Nonnull action) {
                const char *hexColor = [colorDict[@"hex"] UTF8String];
                headphone_configure_color(hexColor);
                
                if (headphone_apply_in_session()) {
                    log_user("[HEADPHONE] Color changed to %s\n", hexColor);
                    
                    // Show success alert
                    UIAlertController *success = [UIAlertController 
                        alertControllerWithTitle:@"✓ Applied" 
                        message:[NSString stringWithFormat:@"Headphone color changed to %@", colorDict[@"name"]] 
                        preferredStyle:UIAlertControllerStyleAlert];
                    [success addAction:[UIAlertAction 
                        actionWithTitle:@"OK" 
                        style:UIAlertActionStyleDefault 
                        handler:nil]];
                    [controller presentViewController:success animated:YES completion:nil];
                } else {
                    // Show error alert
                    UIAlertController *error = [UIAlertController 
                        alertControllerWithTitle:@"⚠️ Error" 
                        message:@"Could not apply color. Headphone UI not found.\n\nTry pressing volume buttons to trigger the volume HUD." 
                        preferredStyle:UIAlertControllerStyleAlert];
                    [error addAction:[UIAlertAction 
                        actionWithTitle:@"OK" 
                        style:UIAlertActionStyleDefault 
                        handler:nil]];
                    [controller presentViewController:error animated:YES completion:nil];
                }
            }];
        [alert addAction:action];
    }
    
    // Revert option
    UIAlertAction *revertAction = [UIAlertAction 
        actionWithTitle:@"⏮️ Revert to Original" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction *_Nonnull action) {
            if (headphone_stop_in_session()) {
                log_user("[HEADPHONE] Colors reverted to original\n");
                
                UIAlertController *success = [UIAlertController 
                    alertControllerWithTitle:@"✓ Restored" 
                    message:@"Headphone colors restored to original." 
                    preferredStyle:UIAlertControllerStyleAlert];
                [success addAction:[UIAlertAction 
                    actionWithTitle:@"OK" 
                    style:UIAlertActionStyleDefault 
                    handler:nil]];
                [controller presentViewController:success animated:YES completion:nil];
            }
        }];
    [alert addAction:revertAction];
    
    // Cancel
    UIAlertAction *cancelAction = [UIAlertAction 
        actionWithTitle:@"Cancel" 
        style:UIAlertActionStyleCancel 
        handler:nil];
    [alert addAction:cancelAction];
    
    [controller presentViewController:alert animated:YES completion:nil];
}
